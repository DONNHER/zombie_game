extends Control

signal entered

enum State {
	BOOTING,
	PATCH_CHECKING,
	PATCH_AVAILABLE,
	UPDATING,
	READY
}

const GITHUB_LATEST_RELEASE_API := "https://api.github.com/repos/DONNHER/zombie_game/releases/latest"
const PATCH_SAVE_PATH := "user://patch.pck"
const PATCH_TEMP_PATH := "user://patch_tmp.pck"

@onready var hero_preview: Control = $CenterBox/Card/VBox/HeroPreview
@onready var boot_bar: ProgressBar = $CenterBox/Card/VBox/BootBar
@onready var enter_btn: Button = $CenterBox/Card/VBox/EnterButton
@onready var status_label: Label = $CenterBox/Card/VBox/StatusLabel
@onready var card: PanelContainer = $CenterBox/Card

var _state: State = State.BOOTING
var _progress: float = 0.0
var _patch_version: String = ""
var _patch_download_url: String = ""
var _active_download_req: HTTPRequest = null
var _btn_normal_style: StyleBoxFlat
var _btn_patch_style: StyleBoxFlat


func _ready() -> void:
	# 1. Mount any previously downloaded PCK patch immediately on app launch
	if FileAccess.file_exists(PATCH_SAVE_PATH):
		var mounted := ProjectSettings.load_resource_pack(PATCH_SAVE_PATH, true)
		print("Startup PCK mount (", PATCH_SAVE_PATH, "): ", mounted)

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
			if _active_download_req != null:
				var downloaded := _active_download_req.get_downloaded_bytes()
				var total := _active_download_req.get_body_size()
				if total > 0:
					var pct := clampf((float(downloaded) / float(total)) * 100.0, 0.0, 99.0)
					boot_bar.value = pct
					status_label.text = "Downloading PCK patch (v%s)... %d%% (%.1f / %.1f MB)" % [
						_patch_version,
						int(pct),
						downloaded / 1048576.0,
						total / 1048576.0
					]
				else:
					boot_bar.value = fmod(boot_bar.value + delta * 35.0, 95.0)
					status_label.text = "Downloading PCK patch (v%s)... %.1f MB" % [
						_patch_version,
						downloaded / 1048576.0
					]


func _check_server_patch() -> void:
	# Notify Nakama check_update RPC if online, then resolve the exact .pck asset from GitHub Releases
	var _nakama_info := await NetworkManager.check_patch_status()
	var gh_release := await _fetch_latest_github_pck()

	var cur_ver := NetworkManager.get_client_version().trim_prefix("v")
	var latest_ver := str(gh_release.get("version", "")).trim_prefix("v")
	var pck_url := str(gh_release.get("pck_url", ""))

	if latest_ver != "" and latest_ver != cur_ver and pck_url.ends_with(".pck"):
		_patch_version = latest_ver
		_patch_download_url = pck_url
		print("OTA target verified (PCK): ", _patch_download_url)
	else:
		_patch_version = ""
		_patch_download_url = ""

	if _state == State.PATCH_CHECKING:
		_evaluate_ready_state()


func _fetch_latest_github_pck() -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)

	# GitHub API requires a User-Agent header
	var headers := PackedStringArray([
		"Accept: application/vnd.github+json",
		"User-Agent: ZombieOutbreak-GodotClient"
	])

	var err := req.request(GITHUB_LATEST_RELEASE_API, headers, HTTPClient.METHOD_GET)
	if err != OK:
		req.queue_free()
		return {}

	var result: Array = await req.request_completed
	req.queue_free()

	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		return {}

	var body_str := (result[3] as PackedByteArray).get_string_from_utf8()
	var parsed = JSON.parse_string(body_str)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	var release: Dictionary = parsed
	var tag := str(release.get("tag_name", ""))
	var assets: Array = release.get("assets", [])

	# Filter strictly for .pck files — ignore any .apk or source archives
	for asset in assets:
		var asset_name := str(asset.get("name", ""))
		if asset_name.ends_with(".pck"):
			return {
				"version": tag,
				"pck_url": str(asset.get("browser_download_url", ""))
			}

	return {}


func _evaluate_ready_state() -> void:
	if _patch_version != "" and _patch_download_url != "":
		_state = State.PATCH_AVAILABLE
		enter_btn.add_theme_stylebox_override("normal", _btn_patch_style)
		enter_btn.text = "UPDATE NOW (v" + _patch_version + ")"
		enter_btn.disabled = false
		status_label.text = "New PCK Patch Available: v%s · Tap UPDATE NOW to patch" % _patch_version
	else:
		_state = State.READY
		enter_btn.add_theme_stylebox_override("normal", _btn_normal_style)
		var ver := NetworkManager.get_client_version().trim_prefix("v")
		enter_btn.text = "ENTER COMMAND HUB"
		enter_btn.disabled = false
		status_label.text = "Bunker save ready (v%s) · Tap or press Enter" % ver


func _download_and_apply_pck() -> void:
	if FileAccess.file_exists(PATCH_TEMP_PATH):
		DirAccess.remove_absolute(PATCH_TEMP_PATH)

	var req := HTTPRequest.new()
	req.use_threads = true
	req.download_file = PATCH_TEMP_PATH
	add_child(req)
	_active_download_req = req

	var headers := PackedStringArray(["User-Agent: ZombieOutbreak-GodotClient"])
	var err := req.request(_patch_download_url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_active_download_req = null
		req.queue_free()
		_on_patch_download_failed("Could not start PCK download.")
		return

	var result: Array = await req.request_completed
	_active_download_req = null
	req.queue_free()

	var req_result := int(result[0])
	var resp_code := int(result[1])
	if req_result != HTTPRequest.RESULT_SUCCESS or resp_code != 200:
		_on_patch_download_failed("Download failed (HTTP %d)." % resp_code)
		return

	status_label.text = "Mounting PCK patch into game engine... 100%"
	boot_bar.value = 100.0

	if FileAccess.file_exists(PATCH_SAVE_PATH):
		DirAccess.remove_absolute(PATCH_SAVE_PATH)
	var rename_err := DirAccess.rename_absolute(PATCH_TEMP_PATH, PATCH_SAVE_PATH)
	if rename_err != OK:
		_on_patch_download_failed("Failed to save PCK file on device.")
		return

	# Mount the downloaded .pck so updated scenes/scripts override the base APK
	var mounted := ProjectSettings.load_resource_pack(PATCH_SAVE_PATH, true)
	if not mounted:
		_on_patch_download_failed("Invalid PCK patch package.")
		return

	_on_patch_download_complete()


func _on_patch_download_failed(reason: String) -> void:
	_state = State.READY
	enter_btn.add_theme_stylebox_override("normal", _btn_normal_style)
	enter_btn.text = "ENTER COMMAND HUB"
	enter_btn.disabled = false
	status_label.text = "%s · Tap to continue on base version" % reason


func _on_patch_download_complete() -> void:
	_state = State.READY
	NetworkManager.set_client_version(_patch_version)
	AudioManager.play_level_up()
	status_label.text = "PCK Patch v%s applied! · Tap to enter" % _patch_version
	enter_btn.add_theme_stylebox_override("normal", _btn_normal_style)
	enter_btn.text = "ENTER COMMAND HUB (v" + _patch_version + ")"
	enter_btn.disabled = false
	_patch_version = ""
	_patch_download_url = ""


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed:
		var kev := event as InputEventKey
		if kev.keycode == KEY_ENTER or kev.keycode == KEY_KP_ENTER or kev.keycode == KEY_SPACE:
			_on_button_pressed()


func _on_button_pressed() -> void:
	match _state:
		State.PATCH_AVAILABLE:
			_state = State.UPDATING
			boot_bar.value = 0.0
			enter_btn.disabled = true
			enter_btn.text = "DOWNLOADING PCK..."
			status_label.text = "Connecting to GitHub Releases..."
			AudioManager.play_pickup()
			_download_and_apply_pck()

		State.READY:
			AudioManager.play_pickup()
			entered.emit()
