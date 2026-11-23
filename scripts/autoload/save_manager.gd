extends Node

signal save_changed(new_save: Dictionary)
signal settings_changed(new_settings: Dictionary)

const SAVE_PATH := "user://save_data.json"
const SETTINGS_PATH := "user://settings.cfg"

var save_data: Dictionary = {}
var settings: Dictionary = {
	"muted": false,
	"volume": 0.55,
	"vibration": true,
	"screen_shake": true,
	"day_night_effects": true,
	"show_damage_numbers": true,
	"language": "en",
	"color_blind_mode": "normal",
	"text_size": "normal",
	"server_url": "http://127.0.0.1:7350",
	"home_intro_seen": false,
}


func _ready() -> void:
	load_settings()
	load_save()


func load_save() -> Dictionary:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var raw_text := file.get_as_text()
			var parsed = JSON.parse_string(raw_text)
			if typeof(parsed) == TYPE_DICTIONARY:
				save_data = GameRules.migrate_save_data(parsed)
				save_changed.emit(save_data)
				return save_data
	save_data = GameRules.create_default_save_data()
	write_save(save_data)
	return save_data


func write_save(next_save: Dictionary) -> void:
	save_data = GameRules.migrate_save_data(next_save)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
	save_changed.emit(save_data)


func reset_local_save() -> void:
	var fresh := GameRules.create_default_save_data(
		str(save_data.get("username", "Ranger")),
		str(save_data.get("gender", "male")),
		str(save_data.get("user_id", "local_player")),
		str(save_data.get("hero_class", "ranger"))
	)
	write_save(fresh)


func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for k in settings.keys():
			settings[k] = cfg.get_value("general", k, settings[k])
	settings_changed.emit(settings)
	return settings


func write_settings(next_settings: Dictionary) -> void:
	for k in next_settings.keys():
		settings[k] = next_settings[k]
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("general", k, settings[k])
	cfg.save(SETTINGS_PATH)
	settings_changed.emit(settings)


func commit_offline_match_result(summary: Dictionary) -> Dictionary:
	var next := save_data.duplicate(true)
	if str(summary.get("mode", "story")) == "tutorial":
		next["survival_points"] = int(next["survival_points"]) + int(summary.get("points_earned", 0))
		next["experience"] = int(next["experience"]) + int(summary.get("xp_earned", 0))
		next["level"] = int(GameRules.compute_level_from_xp(int(next["experience"]))["level"])
		next["updated_at"] = int(Time.get_unix_time_from_system())
		write_save(next)
		return save_data

	next["survival_points"] = int(next["survival_points"]) + int(summary.get("points_earned", 0))
	next["experience"] = int(next["experience"]) + int(summary.get("xp_earned", 0))
	next["boss_tokens"] = int(next["boss_tokens"]) + int(summary.get("tokens_earned", 0))
	next["level"] = int(GameRules.compute_level_from_xp(int(next["experience"]))["level"])

	var stats: Dictionary = next["statistics"]
	stats["zombie_kills"] = int(stats["zombie_kills"]) + int(summary.get("kills", 0))
	stats["boss_defeats"] = int(stats["boss_defeats"]) + int(summary.get("boss_defeats", 0))
	stats["highest_wave"] = maxi(int(stats["highest_wave"]), int(summary.get("wave_reached", 0)))
	stats["matches_played"] = int(stats["matches_played"]) + 1
	stats["total_points_earned"] = int(stats["total_points_earned"]) + int(summary.get("points_earned", 0))

	if bool(summary.get("victory", false)) and str(summary.get("mode", "")) == "story":
		var sid := int(summary.get("stage_id", 1))
		if sid == 1 and bool(summary.get("task_completed", false)):
			next["antidote_secured"] = true
		if sid == 5 and bool(summary.get("task_completed", false)):
			next["antidote_delivered"] = true
		var task_type := str(summary.get("task_type", ""))
		if task_type in ["repair", "supply", "rescue"]:
			next["last_task_type"] = task_type
		var completed: Array = next["completed_stages"]
		if not completed.has(sid):
			completed.append(sid)
		var earned_stars := maxi(1, int(summary.get("stars_earned", 1)))
		var stars_map: Dictionary = next["stage_stars"]
		var prev_stars := int(stars_map.get(str(sid), 0))
		if earned_stars > prev_stars:
			stars_map[str(sid)] = earned_stars
		if sid < 5:
			var unlocked: Array = next["unlocked_stages"]
			if not unlocked.has(sid + 1):
				unlocked.append(sid + 1)
				unlocked.sort()

	next["updated_at"] = int(Time.get_unix_time_from_system())
	write_save(next)
	return save_data
