extends Node

const BASE_VERSION := "1.0.2"
const MAX_PATCH_BYTES := 64 * 1024 * 1024
const DOWNLOAD_PATH := "user://update_download.pck"
const RECEIPT_PATH := "user://update.cfg"

var installed_version := BASE_VERSION
var _startup_resources: Array[Resource] = []


func _init() -> void:
	var receipt := ConfigFile.new()
	if receipt.load(RECEIPT_PATH) != OK:
		return
	var version := normalize_version(str(receipt.get_value("patch", "version", "")))
	if not is_newer(version, BASE_VERSION):
		return
	var path := _pack_path(version)
	if not valid_pack(path, str(receipt.get_value("patch", "sha256", "")), int(receipt.get_value("patch", "size", 0))):
		return
	# Keep the APK's updater and connection settings available even with older packs.
	for resource_path in ["res://scenes/ui/splash_screen.tscn", "res://scripts/autoload/network_manager.gd", "res://scripts/autoload/save_manager.gd"]:
		_startup_resources.append(ResourceLoader.load(resource_path))
	if ProjectSettings.load_resource_pack(path, true):
		installed_version = version
		print("OTA loaded v", version)
	else:
		push_warning("OTA pack could not be loaded. Starting the APK version.")


func normalize_version(tag: String) -> String:
	var version := tag.strip_edges().trim_prefix("v")
	var parts := version.split(".")
	if parts.size() != 3:
		return ""
	for part in parts:
		if not part.is_valid_int() or str(int(part)) != part or int(part) < 0 or part.length() > 9:
			return ""
	return version


func is_newer(candidate: String, installed: String) -> bool:
	if normalize_version(candidate).is_empty() or normalize_version(installed).is_empty():
		return false
	var candidate_parts := normalize_version(candidate).split(".")
	var installed_parts := normalize_version(installed).split(".")
	for index in range(3):
		var next := int(candidate_parts[index])
		var current := int(installed_parts[index])
		if next != current:
			return next > current
	return false


func valid_pack(path: String, digest: String, size: int) -> bool:
	if size < 4 or size > MAX_PATCH_BYTES or not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	return file != null and file.get_length() == size and file.get_buffer(4).get_string_from_ascii() == "GDPC" and FileAccess.get_sha256(path) == digest


func stage_update(version: String, digest: String, size: int) -> Error:
	if not is_newer(version, installed_version) or not valid_pack(DOWNLOAD_PATH, digest, size):
		return ERR_FILE_CORRUPT
	var path := _pack_path(version)
	var rename_error := DirAccess.rename_absolute(DOWNLOAD_PATH, path)
	if rename_error != OK:
		return rename_error
	var receipt := ConfigFile.new()
	receipt.set_value("patch", "version", version)
	receipt.set_value("patch", "sha256", digest)
	receipt.set_value("patch", "size", size)
	var pending := RECEIPT_PATH + ".tmp"
	var save_error := receipt.save(pending)
	if save_error != OK:
		return save_error
	return DirAccess.rename_absolute(pending, RECEIPT_PATH)


func _pack_path(version: String) -> String:
	return "user://update_" + version + ".pck"
