extends Control

signal closed

@onready var close_btn: Button = $Center/Panel/Margin/VBox/Header/CloseBtn
@onready var offline_notice: Label = $Center/Panel/Margin/VBox/OfflineNotice
@onready var add_input: LineEdit = $Center/Panel/Margin/VBox/Body/FriendsCol/AddRow/AddInput
@onready var add_btn: Button = $Center/Panel/Margin/VBox/Body/FriendsCol/AddRow/AddBtn
@onready var friends_list: VBoxContainer = $Center/Panel/Margin/VBox/Body/FriendsCol/FriendsScroll/FriendsList
@onready var chat_list: VBoxContainer = $Center/Panel/Margin/VBox/Body/ChatCol/ChatScroll/ChatList
@onready var chat_input: LineEdit = $Center/Panel/Margin/VBox/Body/ChatCol/SendRow/ChatInput
@onready var send_btn: Button = $Center/Panel/Margin/VBox/Body/ChatCol/SendRow/SendBtn


func _ready() -> void:
	close_btn.pressed.connect(func() -> void:
		hide()
		closed.emit()
	)
	add_btn.pressed.connect(_on_add_friend)
	send_btn.pressed.connect(_on_send_chat)
	chat_input.text_submitted.connect(func(_t: String) -> void: _on_send_chat())
	NetworkManager.friends_updated.connect(func(_f: Array) -> void:
		if visible:
			_render_friends()
	)
	NetworkManager.chat_updated.connect(func(_m: Array) -> void:
		if visible:
			_render_chat()
	)


func open_modal() -> void:
	offline_notice.visible = not NetworkManager.is_online
	_render_friends()
	_render_chat()
	show()
	if NetworkManager.is_online:
		NetworkManager.fetch_friends()


func _render_friends() -> void:
	for c in friends_list.get_children():
		c.queue_free()
	if NetworkManager.friends_list.is_empty():
		var empty := Label.new()
		empty.text = "No squad friends yet." if NetworkManager.is_online else "Offline mode — friends synced when Online."
		empty.add_theme_color_override("font_color", Color("#64748B"))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		friends_list.add_child(empty)
		return
	for f in NetworkManager.friends_list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st_txt := "Online" if bool(f.get("online", false)) else "Offline"
		if int(f.get("state", 0)) == 2:
			st_txt = "Pending Invite"
		lbl.text = "%s (%s)" % [str(f.get("username", "Ranger")), st_txt]
		row.add_child(lbl)
		if int(f.get("state", 0)) == 2:
			var acc := Button.new()
			acc.text = "Accept"
			acc.custom_minimum_size = Vector2(76, 36)
			var uid := str(f.get("id", ""))
			acc.pressed.connect(func() -> void: NetworkManager.accept_friend(uid))
			row.add_child(acc)
		friends_list.add_child(row)


func _render_chat() -> void:
	for c in chat_list.get_children():
		c.queue_free()
	if NetworkManager.global_chat.is_empty():
		var empty := Label.new()
		empty.text = "Command radio quiet. Send a tactical greeting."
		empty.add_theme_color_override("font_color", Color("#64748B"))
		chat_list.add_child(empty)
		return
	for m in NetworkManager.global_chat:
		var lbl := Label.new()
		lbl.text = "[%s]: %s" % [str(m.get("username", "Ranger")), str(m.get("message", ""))]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chat_list.add_child(lbl)


func _on_add_friend() -> void:
	var txt := add_input.text.strip_edges()
	if txt == "":
		return
	add_input.text = ""
	var res := await NetworkManager.add_friend_by_username(txt)
	if not bool(res.get("ok", false)):
		offline_notice.text = str(res.get("error", "Could not add friend."))
		offline_notice.show()


func _on_send_chat() -> void:
	var txt := chat_input.text.strip_edges()
	if txt == "":
		return
	chat_input.text = ""
	NetworkManager.send_global_chat(txt)
