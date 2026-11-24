extends Control

signal entered

enum State {
	CHECKING,
	PATCH_AVAILABLE,
	DOWNLOADING,
	RESTART_REQUIRED,
	READY,
}

const RELEASE_API := "https://api.github.com/repos/DONNHER/zombie_game/releases/latest"
const DOWNLOAD_ROOT := "https://github.com/DONNHER/zombie_game/releases/download/"
const PATCH_NAME := "zombie_game_patch.pck"

@onready var hero_preview: Control = $CenterBox/Card/VBox/HeroPreview
@onready var boot_bar: ProgressBar = $CenterBox/Card/VBox/BootBar
@onready var enter_btn: Button = $CenterBox/Card/VBox/EnterButton
@onready var later_btn: Button = $CenterBox/Card/VBox/LaterButton
@onready var status_label: Label = $CenterBox/Card/VBox/StatusLabel
@onready var card: PanelContainer = $CenterBox/Card

var _state := State.CHECKING
var _patch: Dictionary = {}
var _download: HTTPRequest
var _enter_style: StyleBoxFlat
var _update_style: StyleBoxFlat


func _ready() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#131A24")
	panel.border_color = Color("#F59E0B")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(14)
	panel.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", panel)
	_enter_style = StyleBoxFlat.new()
	_enter_style.bg_color = Color("#D97706")
	_enter_style.set_corner_radius_all(10)
	_update_style = _enter_style.duplicate()
	_update_style.bg_color = Color("#047857")
	_update_style.border_color = Color("#34D399")
	_update_style.set_border_width_all(2)
	enter_btn.add_theme_stylebox_override("normal", _enter_style)

	var save := SaveManager.save_data
	hero_preview.configure(str(save.get("hero_class", "ranger")), str(save.get("gender", "male")))
	enter_btn.pressed.connect(_on_button_pressed)
	later_btn.pressed.connect(func() -> void: entered.emit())
	boot_bar.value = 0.0
	enter_btn.disabled = true
	enter_btn.text = "CHECKING FOR UPDATES"
	status_label.text = "Installed version v%s" % OtaPatch.installed_version
	later_btn.show()
	_check_release()


func _process(delta: float) -> void:
	if _state == State.CHECKING:
		boot_bar.value = minf(90.0, boot_bar.value + delta * 28.0)
	elif _state == State.DOWNLOADING and is_instance_valid(_download):
		var downloaded := _download.get_downloaded_bytes()
		boot_bar.value = minf(float(downloaded) * 100.0 / float(_patch["size"]), 99.0)
		status_label.text = "Downloading v%s… %d%%" % [_patch["version"], int(boot_bar.value)]


func _check_release() -> void:
	var req := HTTPRequest.new()
	req.use_threads = true
	req.timeout = 8.0
	req.body_size_limit = 1024 * 1024
	add_child(req)
	var headers := PackedStringArray(["Accept: application/vnd.github+json", "User-Agent: ZombieOutbreak-GodotClient"])
	var checked := false
	if req.request(RELEASE_API, headers) == OK:
		var result: Array = await req.request_completed
		if int(result[0]) == HTTPRequest.RESULT_SUCCESS and int(result[1]) == 200:
			var response = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			if response is Dictionary:
				checked = true
				_patch = _select_release(response)
	req.queue_free()
	_show_available_action()
	if not checked:
		status_label.text = "Update check unavailable · Installed v%s" % OtaPatch.installed_version


func _select_release(release: Dictionary) -> Dictionary:
	var tag := str(release.get("tag_name", ""))
	var version := OtaPatch.normalize_version(tag)
	if bool(release.get("draft", false)) or bool(release.get("prerelease", false)) or not OtaPatch.is_newer(version, OtaPatch.installed_version):
		return {}
	var expected_url := DOWNLOAD_ROOT + tag + "/" + PATCH_NAME
	var assets = release.get("assets", [])
	if not assets is Array:
		return {}
	for asset in assets:
		if not asset is Dictionary:
			continue
		if str(asset.get("name", "")) != PATCH_NAME or str(asset.get("browser_download_url", "")) != expected_url:
			continue
		var digest := str(asset.get("digest", ""))
		var size := int(asset.get("size", 0))
		if digest.begins_with("sha256:") and digest.length() == 71 and size >= 4 and size <= OtaPatch.MAX_PATCH_BYTES:
			return {"version": version, "url": expected_url, "sha256": digest.trim_prefix("sha256:"), "size": size}
	return {}


func _show_available_action() -> void:
	boot_bar.value = 100.0
	enter_btn.disabled = false
	if _patch.is_empty():
		_state = State.READY
		enter_btn.add_theme_stylebox_override("normal", _enter_style)
		enter_btn.text = "ENTER COMMAND HUB"
		status_label.text = "Bunker save ready (v%s)" % OtaPatch.installed_version
		later_btn.hide()
	else:
		_state = State.PATCH_AVAILABLE
		enter_btn.add_theme_stylebox_override("normal", _update_style)
		enter_btn.text = "UPDATE NOW (v%s)" % _patch["version"]
		status_label.text = "Installed v%s · Update v%s available" % [OtaPatch.installed_version, _patch["version"]]
		later_btn.show()


func _download_patch() -> void:
	_remove_partial_download()
	_state = State.DOWNLOADING
	enter_btn.disabled = true
	enter_btn.text = "DOWNLOADING UPDATE"
	later_btn.hide()
	boot_bar.value = 0.0
	status_label.text = "Connecting to GitHub…"

	var req := HTTPRequest.new()
	req.use_threads = true
	req.timeout = 120.0
	req.body_size_limit = int(_patch["size"])
	req.download_file = OtaPatch.DOWNLOAD_PATH
	add_child(req)
	_download = req
	var headers := PackedStringArray(["User-Agent: ZombieOutbreak-GodotClient"])
	if req.request(str(_patch["url"]), headers) != OK:
		_download = null
		req.queue_free()
		_download_failed("Could not start download.")
		return
	var result: Array = await req.request_completed
	_download = null
	req.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		_download_failed("The download could not finish.")
		return
	if OtaPatch.stage_update(str(_patch["version"]), str(_patch["sha256"]), int(_patch["size"])) != OK:
		_download_failed("The update could not be verified or saved.")
		return

	_state = State.RESTART_REQUIRED
	boot_bar.value = 100.0
	AudioManager.play_pickup()
	status_label.text = "v%s downloaded. Close and reopen the game to apply it." % _patch["version"]
	enter_btn.text = "CLOSE GAME TO APPLY UPDATE"
	enter_btn.disabled = false
	later_btn.show()


func _remove_partial_download() -> void:
	if FileAccess.file_exists(OtaPatch.DOWNLOAD_PATH):
		DirAccess.remove_absolute(OtaPatch.DOWNLOAD_PATH)


func _download_failed(reason: String) -> void:
	_remove_partial_download()
	_show_available_action()
	status_label.text = reason + " Try again or play on your current version."


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_on_button_pressed()


func _on_button_pressed() -> void:
	match _state:
		State.PATCH_AVAILABLE:
			_download_patch()
		State.RESTART_REQUIRED:
			get_tree().quit()
		State.READY:
			AudioManager.play_pickup()
			entered.emit()
