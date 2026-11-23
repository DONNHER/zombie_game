extends Control

signal closed

@onready var close_btn: Button = $Center/Panel/Margin/VBox/Header/CloseBtn
@onready var mission_label: Label = $Center/Panel/Margin/VBox/MissionLabel
@onready var error_label: Label = $Center/Panel/Margin/VBox/ErrorLabel
@onready var browse_view: VBoxContainer = $Center/Panel/Margin/VBox/BrowseView
@onready var quick_btn: Button = $Center/Panel/Margin/VBox/BrowseView/TopActions/QuickBtn
@onready var create_pub_btn: Button = $Center/Panel/Margin/VBox/BrowseView/TopActions/CreatePubBtn
@onready var create_priv_btn: Button = $Center/Panel/Margin/VBox/BrowseView/TopActions/CreatePrivBtn
@onready var code_input: LineEdit = $Center/Panel/Margin/VBox/BrowseView/CodeRow/CodeInput
@onready var join_code_btn: Button = $Center/Panel/Margin/VBox/BrowseView/CodeRow/JoinCodeBtn
@onready var refresh_rooms_btn: Button = $Center/Panel/Margin/VBox/BrowseView/CodeRow/RefreshRoomsBtn
@onready var rooms_list: VBoxContainer = $Center/Panel/Margin/VBox/BrowseView/RoomsScroll/RoomsList

@onready var waiting_view: VBoxContainer = $Center/Panel/Margin/VBox/WaitingView
@onready var room_code_banner: Label = $Center/Panel/Margin/VBox/WaitingView/RoomCodeBanner
@onready var players_list: VBoxContainer = $Center/Panel/Margin/VBox/WaitingView/PlayersScroll/PlayersList
@onready var leave_btn: Button = $Center/Panel/Margin/VBox/WaitingView/WaitBtns/LeaveBtn
@onready var ready_btn: Button = $Center/Panel/Margin/VBox/WaitingView/WaitBtns/ReadyBtn
@onready var start_btn: Button = $Center/Panel/Margin/VBox/WaitingView/WaitBtns/StartBtn

var _mode: String = "story"
var _stage_id: int = 1


func _ready() -> void:
	close_btn.pressed.connect(func() -> void:
		hide()
		closed.emit()
	)
	quick_btn.pressed.connect(_on_quick_match)
	create_pub_btn.pressed.connect(func() -> void: _on_create_room(false))
	create_priv_btn.pressed.connect(func() -> void: _on_create_room(true))
	join_code_btn.pressed.connect(_on_join_by_code)
	refresh_rooms_btn.pressed.connect(func() -> void: NetworkManager.list_public_rooms())
	leave_btn.pressed.connect(func() -> void: NetworkManager.leave_room())
	ready_btn.pressed.connect(func() -> void: NetworkManager.toggle_ready())
	start_btn.pressed.connect(func() -> void: NetworkManager.start_online_match())

	NetworkManager.room_updated.connect(func(_r: Dictionary) -> void:
		if visible:
			_sync_view()
	)
	NetworkManager.public_rooms_updated.connect(func(rooms: Array) -> void:
		if visible:
			_render_public_rooms(rooms)
	)
	NetworkManager.server_error.connect(func(msg: String) -> void:
		if visible:
			error_label.text = msg
			error_label.show()
	)


func open_modal(mode: String, stage_id: int) -> void:
	_mode = mode
	_stage_id = stage_id
	if mode == "endless":
		mission_label.text = "Mission: Endless Portal Invasion (10-Wave Realms)"
	else:
		var st := GameData.get_stage_by_id(stage_id)
		mission_label.text = "Mission: Stage %d — %s" % [stage_id, str(st.get("name", ""))]
	error_label.hide()
	_sync_view()
	show()
	if NetworkManager.is_online and NetworkManager.current_room.is_empty():
		NetworkManager.list_public_rooms()


func _sync_view() -> void:
	var room := NetworkManager.current_room
	if room.is_empty():
		browse_view.show()
		waiting_view.hide()
		_render_public_rooms(NetworkManager.public_rooms)
	else:
		browse_view.hide()
		waiting_view.show()
		room_code_banner.text = "ROOM CODE: %s (%s)" % [
			str(room.get("code", "----")),
			"Private" if bool(room.get("is_private", false)) else "Public"
		]
		var players: Array = room.get("players", [])
		for c in players_list.get_children():
			c.queue_free()
		for p in players:
			var lbl := Label.new()
			var host_tag := " [HOST]" if bool(p.get("isHost", false)) else ""
			var rdy_tag := "READY" if bool(p.get("ready", false)) else "WAITING"
			lbl.text = "• %s%s — %s" % [str(p.get("username", "Ranger")), host_tag, rdy_tag]
			lbl.add_theme_color_override("font_color", Color("#22C55E") if bool(p.get("ready", false)) else Color("#CBD5E1"))
			players_list.add_child(lbl)
		start_btn.visible = NetworkManager.is_room_host()
		start_btn.disabled = players.size() < 1


func _render_public_rooms(rooms: Array) -> void:
	for c in rooms_list.get_children():
		c.queue_free()
	if rooms.is_empty():
		var empty := Label.new()
		empty.text = "No open public squads right now — create one or hit Quick Match!"
		empty.add_theme_color_override("font_color", Color("#64748B"))
		rooms_list.add_child(empty)
		return
	for rm in rooms:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mode_txt := "Endless" if str(rm.get("mode", "story")) == "endless" else "Stage %d" % int(rm.get("stageId", 1))
		lbl.text = "[%s] Host: %s · %s · %d/%d Players" % [
			str(rm.get("code", "")),
			str(rm.get("hostUsername", "Host")),
			mode_txt,
			int(rm.get("playerCount", 1)),
			int(rm.get("maxPlayers", 4)),
		]
		row.add_child(lbl)
		var j_btn := Button.new()
		j_btn.text = "Join"
		j_btn.custom_minimum_size = Vector2(96, 38)
		var mid := str(rm.get("matchId", ""))
		j_btn.pressed.connect(func() -> void:
			var res := await NetworkManager.join_match_by_id(mid, rm)
			if not bool(res.get("ok", false)):
				error_label.text = str(res.get("error", "Could not join room."))
				error_label.show()
		)
		row.add_child(j_btn)
		rooms_list.add_child(row)


func _on_create_room(is_private: bool) -> void:
	error_label.hide()
	var res := await NetworkManager.create_room(_mode, _stage_id, is_private)
	if not bool(res.get("ok", false)):
		error_label.text = str(res.get("error", "Could not create room."))
		error_label.show()


func _on_quick_match() -> void:
	error_label.hide()
	var rooms := await NetworkManager.list_public_rooms()
	if not rooms.is_empty():
		var first: Dictionary = rooms[0]
		var res := await NetworkManager.join_match_by_id(str(first.get("matchId", "")), first)
		if not bool(res.get("ok", false)):
			error_label.text = str(res.get("error", "Could not join room."))
			error_label.show()
		return
	await _on_create_room(false)


func _on_join_by_code() -> void:
	error_label.hide()
	var res := await NetworkManager.join_room_by_code(code_input.text)
	if not bool(res.get("ok", false)):
		error_label.text = str(res.get("error", "Room code not found."))
		error_label.show()
