extends Control

signal closed
signal authenticated_online
signal continued_offline

@onready var close_btn: Button = $Center/Panel/Margin/VBox/HeaderRow/CloseBtn
@onready var login_tab_btn: Button = $Center/Panel/Margin/VBox/ModeTabs/LoginTabBtn
@onready var register_tab_btn: Button = $Center/Panel/Margin/VBox/ModeTabs/RegisterTabBtn
@onready var server_input: LineEdit = $Center/Panel/Margin/VBox/ServerInput
@onready var user_input: LineEdit = $Center/Panel/Margin/VBox/UserInput
@onready var pass_input: LineEdit = $Center/Panel/Margin/VBox/PassInput
@onready var error_box: PanelContainer = $Center/Panel/Margin/VBox/ErrorBox
@onready var error_label: Label = $Center/Panel/Margin/VBox/ErrorBox/ErrorVBox/ErrorLabel
@onready var fallback_offline_btn: Button = $Center/Panel/Margin/VBox/ErrorBox/ErrorVBox/FallbackOfflineBtn
@onready var submit_btn: Button = $Center/Panel/Margin/VBox/SubmitBtn
@onready var guest_btn: Button = $Center/Panel/Margin/VBox/ActionRow/GuestBtn
@onready var offline_btn: Button = $Center/Panel/Margin/VBox/ActionRow/OfflineBtn

var _is_register: bool = false
var _busy: bool = false


func _ready() -> void:
	server_input.text = NetworkManager.server_url
	user_input.text = str(SaveManager.save_data.get("username", "Ranger"))

	var err_sb := StyleBoxFlat.new()
	err_sb.bg_color = Color("#3B1219")
	err_sb.border_color = Color("#EF4444")
	err_sb.set_border_width_all(1)
	err_sb.set_corner_radius_all(8)
	err_sb.set_content_margin_all(10)
	error_box.add_theme_stylebox_override("panel", err_sb)

	close_btn.pressed.connect(func() -> void:
		hide()
		closed.emit()
	)
	login_tab_btn.pressed.connect(func() -> void: _set_mode(false))
	register_tab_btn.pressed.connect(func() -> void: _set_mode(true))
	submit_btn.pressed.connect(_on_submit)
	guest_btn.pressed.connect(_on_guest)
	offline_btn.pressed.connect(_on_offline)
	fallback_offline_btn.pressed.connect(_on_offline)
	_set_mode(false)


func open_modal(initial_error: String = "") -> void:
	server_input.text = NetworkManager.server_url
	if initial_error != "":
		_show_error(initial_error)
	else:
		error_box.hide()
	show()


func _set_mode(reg: bool) -> void:
	_is_register = reg
	submit_btn.text = "Create Online Account" if reg else "Connect & Sign In"
	login_tab_btn.modulate = Color("#FFFFFF") if not reg else Color("#94A3B8")
	register_tab_btn.modulate = Color("#FFFFFF") if reg else Color("#94A3B8")


func _show_error(msg: String) -> void:
	error_label.text = msg
	error_box.show()


func _set_busy(busy: bool) -> void:
	_busy = busy
	submit_btn.disabled = busy
	guest_btn.disabled = busy


func _on_submit() -> void:
	if _busy:
		return
	var uname := user_input.text.strip_edges()
	var pwd := pass_input.text.strip_edges()
	if uname.length() < 3:
		_show_error("Callsign must be at least 3 characters.")
		return
	if pwd.length() < 4:
		_show_error("Passcode must be at least 4 characters.")
		return

	NetworkManager.set_server_url(server_input.text)
	error_box.hide()
	_set_busy(true)
	var custom_id := "%s:%s" % [uname.to_lower(), pwd.sha256_text().substr(0, 16)]
	var res := await NetworkManager.authenticate_custom(custom_id, uname, _is_register)
	_set_busy(false)
	if not bool(res.get("ok", false)):
		_show_error(str(res.get("error", "Multiplayer server unreachable. Check Wi-Fi or switch to Offline Mode.")))
		return
	AudioManager.play_pickup()
	hide()
	authenticated_online.emit()


func _on_guest() -> void:
	if _busy:
		return
	NetworkManager.set_server_url(server_input.text)
	error_box.hide()
	_set_busy(true)
	var res := await NetworkManager.authenticate_guest(user_input.text.strip_edges())
	_set_busy(false)
	if not bool(res.get("ok", false)):
		_show_error(str(res.get("error", "Multiplayer server unreachable. Check Wi-Fi or switch to Offline Mode.")))
		return
	AudioManager.play_pickup()
	hide()
	authenticated_online.emit()


func _on_offline() -> void:
	NetworkManager.logout()
	error_box.hide()
	hide()
	continued_offline.emit()
