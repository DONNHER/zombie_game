extends Control

signal entered

enum State {
	BOOTING,
	PATCH_CHECKING,
	PATCH_AVAILABLE,
	UPDATING,
	READY
}

@onready var hero_preview: Control = $CenterBox/Card/VBox/HeroPreview
@onready var boot_bar: ProgressBar = $CenterBox/Card/VBox/BootBar
@onready var enter_btn: Button = $CenterBox/Card/VBox/EnterButton
@onready var status_label: Label = $CenterBox/Card/VBox/StatusLabel
@onready var card: PanelContainer = $CenterBox/Card

var _state: State = State.BOOTING
var _progress: float = 0.0
var _update_progress: float = 0.0
var _patch_version: String = ""
var _btn_normal_style: StyleBoxFlat
var _btn_patch_style: StyleBoxFlat


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#131A24")
	sb.border_color = Color("#F59E0B")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", sb)

	_btn_normal_style = StyleBoxFlat.new()
	_btn_normal_style.bg_color = Color("#D97706")
	_btn_normal_style.set_corner_radius_all(10)

	_btn_patch_style = StyleBoxFlat.new()
	_btn_patch_style.bg_color = Color("#10B981")
	_btn_patch_style.border_color = Color("#34D399")
	_btn_patch_style.set_border_width_all(2)
	_btn_patch_style.set_corner_radius_all(10)

	enter_btn.add_theme_stylebox_override("normal", _btn_normal_style)

	var save := SaveManager.save_data
	hero_preview.configure(str(save.get("hero_class", "ranger")), str(save.get("gender", "male")))

	enter_btn.pressed.connect(_on_button_pressed)
	boot_bar.value = 0.0
	enter_btn.disabled = true
	enter_btn.text = "INITIALIZING..."

	_check_server_patch()


func _process(delta: float) -> void:
	match _state:
		State.BOOTING:
			if _progress < 100.0:
				_progress = minf(100.0, _progress + delta * 185.0)
				boot_bar.value = _progress
				if _progress >= 100.0:
					_state = State.PATCH_CHECKING
					_evaluate_ready_state()

		State.UPDATING:
			if _update_progress < 100.0:
				_update_progress = minf(100.0, _update_progress + delta * 32.0)
				boot_bar.value = _update_progress
				_update_download_status(_update_progress)
				if _update_progress >= 100.0:
					_on_patch_download_complete()


func _check_server_patch() -> void:
	var patch_info := await NetworkManager.check_patch_status()
	if bool(patch_info.get("has_patch", false)):
		_patch_version = str(patch_info.get("server_version", "vNext"))
	else:
		_patch_version = ""
	if _state == State.PATCH_CHECKING:
		_evaluate_ready_state()


func _evaluate_ready_state() -> void:
	if _patch_version != "":
		_state = State.PATCH_AVAILABLE
		enter_btn.add_theme_stylebox_override("normal", _btn_patch_style)
		enter_btn.text = "UPDATE NOW (" + _patch_version + ")"
		enter_btn.disabled = false
		status_label.text = "New Patch Available: %s · Tap UPDATE NOW to patch" % _patch_version
	else:
		_state = State.READY
		enter_btn.add_theme_stylebox_override("normal", _btn_normal_style)
		var ver := NetworkManager.get_client_version()
		enter_btn.text = "ENTER COMMAND HUB"
		enter_btn.disabled = false
		status_label.text = "Bunker save ready (v%s) · Tap or press Enter" % ver


func _update_download_status(p: float) -> void:
	if p < 25.0:
		status_label.text = "Connecting to GitHub Releases · Fetching patch manifest... %d%%" % int(p)
	elif p < 60.0:
		status_label.text = "Downloading patch delta (%s)... %d%%" % [_patch_version, int(p)]
	elif p < 85.0:
		status_label.text = "Verifying package signature · Unpacking assets... %d%%" % int(p)
	else:
		status_label.text = "Applying update to game engine... %d%%" % int(p)


func _on_patch_download_complete() -> void:
	_state = State.READY
	NetworkManager.set_client_version(_patch_version)
	AudioManager.play_level_up()
	status_label.text = "Patch %s successfully applied! · Tap to enter" % _patch_version
	enter_btn.add_theme_stylebox_override("normal", _btn_normal_style)
	enter_btn.text = "ENTER COMMAND HUB (" + _patch_version + ")"
	enter_btn.disabled = false
	_patch_version = ""


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed:
		var kev := event as InputEventKey
		if kev.keycode == KEY_ENTER or kev.keycode == KEY_KP_ENTER or kev.keycode == KEY_SPACE:
			_on_button_pressed()


func _on_button_pressed() -> void:
	match _state:
		State.PATCH_AVAILABLE:
			_state = State.UPDATING
			_update_progress = 0.0
			boot_bar.value = 0.0
			enter_btn.disabled = true
			enter_btn.text = "UPDATING..."
			AudioManager.play_pickup()

		State.READY:
			AudioManager.play_pickup()
			entered.emit()
