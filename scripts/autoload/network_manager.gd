extends Node

signal connection_changed(is_online: bool, error_msg: String)
signal auth_changed(user: Dictionary)
signal room_updated(room: Dictionary)
signal match_started(payload: Dictionary)
signal match_deploy_state(payload: Dictionary)
signal match_data_received(op_code: int, sender_id: String, payload: Dictionary)
signal chat_updated(messages: Array)
signal friends_updated(friends: Array)
signal leaderboard_updated(tab: String, entries: Array)
signal public_rooms_updated(rooms: Array)
signal server_error(message: String)
signal realtime_disconnected(reason: String)

const DEFAULT_SERVER_KEY := "defaultkey"
const COLLECTION_SAVES := "player_saves"
const KEY_PROFILE := "profile_v1"

var server_key: String = DEFAULT_SERVER_KEY
var server_url: String = "http://127.0.0.1:7350"
var session_token: String = ""
var auth_user: Dictionary = {} # {user_id, username, is_guest}
var is_online: bool = false
var last_error: String = ""

var current_room: Dictionary = {}
var global_chat: Array = []
var friends_list: Array = []
var leaderboard_all: Array = []
var leaderboard_weekly: Array = []
var public_rooms: Array = []

var _ws: WebSocketPeer = WebSocketPeer.new()
var _ws_connected: bool = false
var _ws_connecting: bool = false
var _cid_counter: int = 1
var _pending_ws_callbacks: Dictionary = {}
var _global_channel_id: String = ""


func _ready() -> void:
	var env_key := OS.get_environment("NAKAMA_SERVER_KEY").strip_edges()
	server_key = env_key if env_key != "" else DEFAULT_SERVER_KEY
	var env_url := OS.get_environment("NAKAMA_SERVER_URL").strip_edges().rstrip("/")
	var saved_url := str(SaveManager.settings.get("server_url", "http://127.0.0.1:7350")).rstrip("/")
	server_url = env_url if env_url != "" else saved_url
	SaveManager.settings_changed.connect(func(s: Dictionary) -> void:
		server_url = str(s.get("server_url", "http://127.0.0.1:7350")).rstrip("/")
	)


func _process(_delta: float) -> void:
	if not _ws_connecting and not _ws_connected:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if _ws_connecting:
			_ws_connecting = false
			_ws_connected = true
			_on_ws_opened()
		while _ws.get_available_packet_count() > 0:
			var pkt := _ws.get_packet().get_string_from_utf8()
			_handle_ws_packet(pkt)
	elif st == WebSocketPeer.STATE_CLOSED:
		if _ws_connecting or _ws_connected:
			var had_room := not current_room.is_empty()
			_ws_connecting = false
			_ws_connected = false
			if is_online:
				_set_error("Connection to Nakama server lost. Check the server and try again.")
			if had_room:
				current_room = {}
				room_updated.emit({})
				realtime_disconnected.emit("Connection to Nakama was lost. The squad match ended.")


func set_server_url(url: String) -> void:
	var cleaned := url.strip_edges().rstrip("/")
	if cleaned == "":
		cleaned = "http://127.0.0.1:7350"
	server_url = cleaned
	SaveManager.write_settings({"server_url": cleaned})


func _set_error(msg: String) -> void:
	last_error = msg
	is_online = false
	connection_changed.emit(false, msg)
	server_error.emit(msg)


func clear_error() -> void:
	last_error = ""
	connection_changed.emit(is_online, "")


func _http_json(method: int, path: String, body: Variant = null, use_bearer: bool = true) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 5.0
	add_child(req)

	var headers := PackedStringArray(["Content-Type: application/json"])
	if use_bearer and session_token != "":
		headers.append("Authorization: Bearer " + session_token)
	else:
		var basic := Marshalls.utf8_to_base64(server_key + ":")
		headers.append("Authorization: Basic " + basic)

	var payload_str := ""
	if body != null:
		payload_str = JSON.stringify(body) if typeof(body) != TYPE_STRING else str(body)

	var err := req.request(server_url + path, headers, method, payload_str)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "error": "Network unreachable. Check Wi-Fi or server URL."}

	var result: Array = await req.request_completed
	req.queue_free()

	var req_result := int(result[0])
	var resp_code := int(result[1])
	var resp_body := (result[3] as PackedByteArray).get_string_from_utf8()

	if req_result != HTTPRequest.RESULT_SUCCESS or resp_code == 0:
		return {"ok": false, "code": 0, "error": "Multiplayer server unreachable (%s). Check Wi-Fi or switch to Offline Mode." % server_url}

	var parsed = JSON.parse_string(resp_body) if resp_body != "" else {}
	if resp_code >= 200 and resp_code < 300:
		return {"ok": true, "code": resp_code, "data": parsed if typeof(parsed) == TYPE_DICTIONARY else {}}

	var msg := "Server error (%d)" % resp_code
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("message"):
		msg = str(parsed["message"])
	return {"ok": false, "code": resp_code, "error": msg}


func check_server_health() -> bool:
	var res := await _http_json(HTTPClient.METHOD_GET, "/healthcheck", null, false)
	if not bool(res["ok"]):
		_set_error(str(res.get("error", "Nakama server unreachable.")))
		return false
	last_error = ""
	return true


func authenticate_custom(custom_id: String, username: String, create: bool) -> Dictionary:
	var clean_user := username.strip_edges()
	var clean_id := custom_id.strip_edges().to_lower()
	if clean_id.length() < 3:
		return {"ok": false, "error": "Username must be at least 3 characters"}
	var q := "/v2/account/authenticate/custom?create=%s&username=%s" % [
		"true" if create else "false",
		clean_user.uri_encode()
	]
	var res := await _http_json(HTTPClient.METHOD_POST, q, {"id": clean_id}, false)
	if not bool(res["ok"]):
		_set_error(str(res["error"]))
		return res
	return await _finish_auth(res["data"], clean_user, false)


func authenticate_guest(username: String = "") -> Dictionary:
	var guest_name := username.strip_edges()
	if guest_name == "":
		guest_name = "Guest_" + str(randi() % 9000 + 1000)
	var device_id := OS.get_unique_id()
	if device_id == "":
		device_id = "godot_guest_" + str(absi(guest_name.hash()))
	var q := "/v2/account/authenticate/device?create=true&username=%s" % guest_name.uri_encode()
	var res := await _http_json(HTTPClient.METHOD_POST, q, {"id": device_id}, false)
	if not bool(res["ok"]):
		_set_error(str(res["error"]))
		return res
	return await _finish_auth(res["data"], guest_name, true)


func _finish_auth(data: Dictionary, fallback_name: String, is_guest: bool) -> Dictionary:
	session_token = str(data.get("token", ""))
	if session_token == "":
		_set_error("Invalid session token from Nakama")
		return {"ok": false, "error": "Invalid session token"}

	var acct := await _http_json(HTTPClient.METHOD_GET, "/v2/account", null, true)
	var uid := "nakama_user"
	var uname := fallback_name
	if bool(acct["ok"]):
		var udict: Dictionary = acct["data"].get("user", {})
		uid = str(udict.get("id", uid))
		uname = str(udict.get("username", uname))

	auth_user = {"user_id": uid, "username": uname, "is_guest": is_guest}
	is_online = true
	last_error = ""
	auth_changed.emit(auth_user)
	connection_changed.emit(true, "")
	_connect_websocket()
	await fetch_cloud_save()
	return {"ok": true, "user": auth_user}


func logout() -> void:
	disconnect_ws()
	session_token = ""
	auth_user = {}
	current_room = {}
	is_online = false
	last_error = ""
	auth_changed.emit({})
	connection_changed.emit(false, "")
	room_updated.emit({})


func _connect_websocket() -> void:
	disconnect_ws()
	if session_token == "":
		return
	var ws_base := server_url.replace("https://", "wss://").replace("http://", "ws://")
	var ws_url := "%s/ws?lang=en&status=true&token=%s" % [ws_base, session_token.uri_encode()]
	var err := _ws.connect_to_url(ws_url)
	if err != OK:
		_set_error("Could not open realtime socket to Nakama.")
		return
	_ws_connecting = true


func disconnect_ws() -> void:
	if _ws_connected or _ws_connecting:
		_ws.close()
	_ws_connected = false
	_ws_connecting = false
	_global_channel_id = ""
	_pending_ws_callbacks.clear()


func _on_ws_opened() -> void:
	# Join Global chat room ("GlobalCommand")
	_send_ws_envelope({
		"channel_join": {
			"target": "GlobalCommand",
			"type": 1,
			"persistence": true,
			"hidden": false,
		}
	}, func(reply: Dictionary) -> void:
		if reply.has("channel"):
			_global_channel_id = str(reply["channel"].get("id", ""))
	)


func _next_cid() -> String:
	var c := str(_cid_counter)
	_cid_counter += 1
	return c


func _send_ws_envelope(payload: Dictionary, cb: Variant = null) -> String:
	if not _ws_connected:
		return ""
	var cid := _next_cid()
	payload["cid"] = cid
	if cb != null:
		_pending_ws_callbacks[cid] = cb
	_ws.send_text(JSON.stringify(payload))
	return cid


func _handle_ws_packet(raw: String) -> void:
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var msg: Dictionary = parsed
	var cid := str(msg.get("cid", ""))
	if cid != "" and _pending_ws_callbacks.has(cid):
		var cb: Callable = _pending_ws_callbacks[cid]
		_pending_ws_callbacks.erase(cid)
		if cb.is_valid():
			cb.call(msg)

	if msg.has("error"):
		var err_info: Dictionary = msg["error"]
		server_error.emit(str(err_info.get("message", "Realtime error")))
		return

	if msg.has("channel_message"):
		var cm: Dictionary = msg["channel_message"]
		var content_raw := str(cm.get("content", "{}"))
		var content = JSON.parse_string(content_raw)
		var text := str(content.get("message", content_raw)) if typeof(content) == TYPE_DICTIONARY else content_raw
		global_chat.append({
			"id": str(cm.get("message_id", str(Time.get_ticks_msec()))),
			"username": str(cm.get("username", "Ranger")),
			"message": text,
			"created_at": str(cm.get("create_time", "")),
		})
		if global_chat.size() > 60:
			global_chat = global_chat.slice(global_chat.size() - 60)
		chat_updated.emit(global_chat)

	if msg.has("match_data"):
		var md: Dictionary = msg["match_data"]
		if str(md.get("match_id", "")) != str(current_room.get("match_id", "")) or current_room.is_empty():
			return
		var op := int(md.get("op_code", 0))
		var sender_dict: Dictionary = md.get("presence", {})
		var sender_id := str(sender_dict.get("user_id", ""))
		var raw_b64 := str(md.get("data", ""))
		var decoded_str := raw_b64
		if raw_b64 != "":
			var b := Marshalls.base64_to_raw(raw_b64)
			if b.size() > 0:
				decoded_str = b.get_string_from_utf8()
		var payload_obj = JSON.parse_string(decoded_str)
		var payload: Dictionary = payload_obj if typeof(payload_obj) == TYPE_DICTIONARY else {}

		if op == 1 and not payload.is_empty():
			_merge_lobby_state(payload)
		elif op == 2:
			current_room["status"] = "deploying"
			room_updated.emit(current_room)
			match_started.emit(payload)
		elif op == 4:
			if bool(payload.get("allReady", false)):
				current_room["status"] = "in_progress"
				room_updated.emit(current_room)
			match_deploy_state.emit(payload)
		else:
			match_data_received.emit(op, sender_id, payload)


func _merge_lobby_state(lobby: Dictionary) -> void:
	var match_id := str(current_room.get("match_id", ""))
	current_room = {
		"match_id": match_id,
		"code": str(lobby.get("code", current_room.get("code", ""))),
		"mode": str(lobby.get("mode", "story")),
		"stage_id": int(lobby.get("stageId", 1)),
		"is_private": bool(lobby.get("isPrivate", false)),
		"host_user_id": str(lobby.get("hostUserId", "")),
		"host_username": str(lobby.get("hostUsername", "Host")),
		"status": str(lobby.get("status", "waiting")),
		"players": lobby.get("players", []),
	}
	room_updated.emit(current_room)


func _call_rpc(rpc_id: String, body_dict: Dictionary = {}) -> Dictionary:
	if not is_online:
		return {"ok": false, "error": "Offline mode active"}
	var payload_str := JSON.stringify(body_dict)
	# Nakama's wrapped HTTP RPC endpoint expects a JSON string as the request body.
	var res := await _http_json(HTTPClient.METHOD_POST, "/v2/rpc/" + rpc_id, JSON.stringify(payload_str), true)
	if not bool(res["ok"]):
		return res
	var data: Dictionary = res["data"]
	var inner_raw := str(data.get("payload", "{}"))
	var inner = JSON.parse_string(inner_raw)
	if typeof(inner) == TYPE_DICTIONARY:
		return inner
	return {"ok": true, "raw": inner_raw}


func fetch_cloud_save() -> Dictionary:
	if not is_online or auth_user.is_empty():
		return SaveManager.save_data
	var res := await _http_json(HTTPClient.METHOD_POST, "/v2/storage", {
		"object_ids": [{
			"collection": COLLECTION_SAVES,
			"key": KEY_PROFILE,
			"user_id": str(auth_user["user_id"]),
		}]
	}, true)
	if not bool(res["ok"]):
		return SaveManager.save_data
	var objs: Array = res["data"].get("objects", [])
	if objs.is_empty():
		await sync_save_to_cloud(SaveManager.save_data)
		return SaveManager.save_data
	var val_str := str(objs[0].get("value", "{}"))
	var parsed = JSON.parse_string(val_str)
	if typeof(parsed) == TYPE_DICTIONARY:
		var cloud_save := GameRules.migrate_save_data(parsed)
		cloud_save["user_id"] = str(auth_user["user_id"])
		cloud_save["username"] = str(auth_user["username"])
		var local_ts := int(SaveManager.save_data.get("updated_at", 0))
		var cloud_ts := int(cloud_save.get("updated_at", 0))
		if cloud_ts >= local_ts:
			SaveManager.write_save(cloud_save)
		else:
			await sync_save_to_cloud(SaveManager.save_data)
	return SaveManager.save_data


func sync_save_to_cloud(save: Dictionary) -> void:
	if not is_online or auth_user.is_empty():
		return
	var to_write := save.duplicate(true)
	to_write["user_id"] = str(auth_user["user_id"])
	to_write["username"] = str(auth_user["username"])
	await _http_json(HTTPClient.METHOD_PUT, "/v2/storage", {
		"objects": [{
			"collection": COLLECTION_SAVES,
			"key": KEY_PROFILE,
			"value": JSON.stringify(to_write),
			"permission_read": 2,
			"permission_write": 1,
		}]
	}, true)


func commit_online_match_result(summary: Dictionary) -> Dictionary:
	var updated := SaveManager.commit_offline_match_result(summary)
	if is_online:
		await _call_rpc("commit_match_result", {
			"pointsEarned": int(summary.get("points_earned", 0)),
			"waveReached": int(summary.get("wave_reached", 1)),
			"kills": int(summary.get("kills", 0)),
			"bossDefeats": int(summary.get("boss_defeats", 0)),
			"level": int(updated.get("level", 1)),
			"username": str(updated.get("username", "Ranger")),
		})
		await sync_save_to_cloud(updated)
	return updated


func fetch_leaderboard(tab: String = "total_points") -> Array:
	if not is_online:
		return []
	var res := await _http_json(HTTPClient.METHOD_GET, "/v2/leaderboard/%s?limit=25" % tab, null, true)
	if not bool(res["ok"]):
		return []
	var records: Array = res["data"].get("records", [])
	var formatted: Array = []
	for i in range(records.size()):
		var r: Dictionary = records[i]
		var meta = JSON.parse_string(str(r.get("metadata", "{}")))
		var meta_d: Dictionary = meta if typeof(meta) == TYPE_DICTIONARY else {}
		formatted.append({
			"rank": int(r.get("rank", i + 1)),
			"username": str(r.get("username", meta_d.get("username", "Ranger"))),
			"score": int(r.get("score", 0)),
			"level": int(meta_d.get("level", 1)),
			"highest_wave": int(meta_d.get("highestWave", 1)),
			"boss_defeats": int(meta_d.get("bossDefeats", 0)),
		})
	if tab == "weekly_points":
		leaderboard_weekly = formatted
	else:
		leaderboard_all = formatted
	leaderboard_updated.emit(tab, formatted)
	return formatted


func fetch_friends() -> Array:
	if not is_online:
		return []
	var res := await _http_json(HTTPClient.METHOD_GET, "/v2/friend?limit=50", null, true)
	if not bool(res["ok"]):
		return []
	var out: Array = []
	for f in res["data"].get("friends", []):
		var u: Dictionary = f.get("user", {})
		out.append({
			"id": str(u.get("id", "")),
			"username": str(u.get("username", "Ranger")),
			"online": bool(u.get("online", false)),
			"state": int(f.get("state", 0)), # 0=friend, 1=invite_sent, 2=invite_received
		})
	friends_list = out
	friends_updated.emit(out)
	return out


func add_friend_by_username(target_username: String) -> Dictionary:
	if not is_online:
		return {"ok": false, "error": "Online connection required"}
	var clean := target_username.strip_edges()
	if clean == "":
		return {"ok": false, "error": "Enter a username"}
	var res := await _http_json(HTTPClient.METHOD_POST, "/v2/friend?usernames=" + clean.uri_encode(), null, true)
	if bool(res["ok"]):
		await fetch_friends()
	return res


func accept_friend(user_id: String) -> void:
	if not is_online:
		return
	await _http_json(HTTPClient.METHOD_POST, "/v2/friend?ids=" + user_id.uri_encode(), null, true)
	await fetch_friends()


func send_global_chat(message: String) -> void:
	var txt := message.strip_edges()
	if txt == "":
		return
	if not is_online or not _ws_connected or _global_channel_id == "":
		global_chat.append({
			"id": str(Time.get_ticks_msec()),
			"username": str(SaveManager.save_data.get("username", "Ranger")) + " (Offline)",
			"message": txt,
		})
		chat_updated.emit(global_chat)
		return
	_send_ws_envelope({
		"channel_message_send": {
			"channelId": _global_channel_id,
			"content": JSON.stringify({"message": txt}),
		}
	})


func list_public_rooms() -> Array:
	if not is_online:
		return []
	var res := await _call_rpc("list_public_rooms", {})
	var rooms: Array = res.get("rooms", [])
	public_rooms = rooms
	public_rooms_updated.emit(rooms)
	return rooms


func create_room(mode: String, stage_id: int, is_private: bool) -> Dictionary:
	if not is_online:
		return {"ok": false, "error": "Connect to Nakama server first."}
	if not await _ensure_ws_connected():
		return {"ok": false, "error": "Realtime connection to Nakama failed. Check the server URL and try again."}
	var res := await _call_rpc("create_coop_room", {
		"mode": mode,
		"stageId": 99 if mode == "endless" else stage_id,
		"isPrivate": is_private,
	})
	if not bool(res.get("ok", false)):
		return res
	var match_id := str(res.get("matchId", ""))
	current_room = {
		"match_id": match_id,
		"code": str(res.get("code", "")),
		"mode": mode,
		"stage_id": 99 if mode == "endless" else stage_id,
		"is_private": is_private,
		"host_user_id": str(auth_user.get("user_id", "")),
		"host_username": str(auth_user.get("username", "Host")),
		"status": "waiting",
		"players": [{"userId": str(auth_user.get("user_id", "")), "username": str(auth_user.get("username", "Host")), "ready": true, "isHost": true}],
	}
	var joined := await _join_ws_match(match_id)
	if not bool(joined.get("ok", false)):
		current_room = {}
		room_updated.emit({})
		return joined
	room_updated.emit(current_room)
	return {"ok": true, "room": current_room}


func join_room_by_code(code: String) -> Dictionary:
	if not is_online:
		return {"ok": false, "error": "Connect to Nakama server first."}
	var res := await _call_rpc("find_room_by_code", {"code": code.strip_edges().to_upper()})
	if not bool(res.get("ok", false)):
		return res
	var match_id := str(res.get("matchId", ""))
	return await join_match_by_id(match_id, res.get("meta", {}))


func join_match_by_id(match_id: String, meta: Dictionary = {}) -> Dictionary:
	if not await _ensure_ws_connected():
		return {"ok": false, "error": "Realtime connection to Nakama failed. Check the server URL and try again."}
	current_room = {
		"match_id": match_id,
		"code": str(meta.get("code", "")),
		"mode": str(meta.get("mode", "story")),
		"stage_id": int(meta.get("stageId", 1)),
		"is_private": bool(meta.get("isPrivate", false)),
		"host_user_id": "",
		"host_username": str(meta.get("hostUsername", "Host")),
		"status": "waiting",
		"players": [],
	}
	var joined := await _join_ws_match(match_id)
	if not bool(joined.get("ok", false)):
		current_room = {}
		room_updated.emit({})
		return joined
	room_updated.emit(current_room)
	return {"ok": true, "room": current_room}


func _ensure_ws_connected() -> bool:
	if _ws_connected:
		return true
	if not _ws_connecting:
		_connect_websocket()
	var deadline := Time.get_ticks_msec() + 5000
	while _ws_connecting and not _ws_connected and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
	if not _ws_connected and _ws_connecting:
		disconnect_ws()
	return _ws_connected


func _join_ws_match(match_id: String) -> Dictionary:
	var outcome: Dictionary = {"done": false, "ok": false, "error": "Could not join room."}
	var cid := _send_ws_envelope({"match_join": {"matchId": match_id}}, func(reply: Dictionary) -> void:
		outcome["done"] = true
		outcome["ok"] = reply.has("match")
		if reply.has("error"):
			outcome["error"] = str(reply["error"].get("message", "Could not join room."))
	)
	if cid == "":
		return {"ok": false, "error": "Realtime connection is unavailable."}
	var deadline := Time.get_ticks_msec() + 5000
	while not bool(outcome["done"]) and _ws_connected and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
	if not bool(outcome["done"]):
		_pending_ws_callbacks.erase(cid)
		if _ws_connected:
			_send_ws_envelope({"match_leave": {"matchId": match_id}})
		return {"ok": false, "error": "Timed out joining the room. Try again."}
	return {"ok": bool(outcome["ok"]), "error": str(outcome["error"])}


func leave_room() -> void:
	var match_id := str(current_room.get("match_id", ""))
	if match_id != "" and _ws_connected:
		_send_ws_envelope({"match_leave": {"matchId": match_id}})
	current_room = {}
	room_updated.emit({})


func toggle_ready() -> void:
	send_match_op(1, {})


func start_online_match() -> void:
	send_match_op(2, {})


func send_deploy_ready() -> void:
	send_match_op(4, {})


func send_match_op(op_code: int, payload: Dictionary) -> void:
	var match_id := str(current_room.get("match_id", ""))
	if match_id == "" or not _ws_connected:
		return
	var json_bytes := JSON.stringify(payload).to_utf8_buffer()
	_ws.send_text(JSON.stringify({
		"match_data_send": {
			"matchId": match_id,
			"opCode": op_code,
			"data": Marshalls.raw_to_base64(json_bytes),
		}
	}))


func is_room_host() -> bool:
	if current_room.is_empty() or auth_user.is_empty():
		return true
	return str(current_room.get("host_user_id", "")) == str(auth_user.get("user_id", ""))
