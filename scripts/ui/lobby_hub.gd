extends Control

signal request_start_match(config: Dictionary)
signal request_open_armory
signal request_open_social
signal request_open_leaderboard
signal request_open_settings
signal request_open_auth(error_msg: String)
signal request_open_online_room(mode: String, stage_id: int)
signal request_replay_intro

@onready var brand_title: Label = $Margin/RootVBox/TopBar/BrandTitle
@onready var armory_btn: Button = $Margin/RootVBox/TopBar/ArmoryBtn
@onready var social_btn: Button = $Margin/RootVBox/TopBar/SocialBtn
@onready var leaderboard_btn: Button = $Margin/RootVBox/TopBar/LeaderboardBtn
@onready var settings_btn: Button = $Margin/RootVBox/TopBar/SettingsBtn
@onready var auth_btn: Button = $Margin/RootVBox/TopBar/AuthBtn

@onready var hero_col: PanelContainer = $Margin/RootVBox/Columns/HeroCol
@onready var mission_col: PanelContainer = $Margin/RootVBox/Columns/MissionCol
@onready var callsign_label: Label = $Margin/RootVBox/Columns/HeroCol/HeroScroll/HeroVBox/CallsignLabel
@onready var xp_bar: ProgressBar = $Margin/RootVBox/Columns/HeroCol/HeroScroll/HeroVBox/XpBar
@onready var hero_preview: Control = $Margin/RootVBox/Columns/HeroCol/HeroScroll/HeroVBox/HeroPreview
@onready var ranger_btn: Button = $Margin/RootVBox/Columns/HeroCol/HeroScroll/HeroVBox/ClassRow/RangerBtn
@onready var medic_btn: Button = $Margin/RootVBox/Columns/HeroCol/HeroScroll/HeroVBox/ClassRow/MedicBtn
@onready var male_btn: Button = $Margin/RootVBox/Columns/HeroCol/HeroScroll/HeroVBox/GenderRow/MaleBtn
@onready var female_btn: Button = $Margin/RootVBox/Columns/HeroCol/HeroScroll/HeroVBox/GenderRow/FemaleBtn
@onready var weapon_summary: Label = $Margin/RootVBox/Columns/HeroCol/HeroScroll/HeroVBox/WeaponSummary
@onready var wallet_label: Label = $Margin/RootVBox/Columns/HeroCol/HeroScroll/HeroVBox/WalletLabel
@onready var career_stats: Label = $Margin/RootVBox/Columns/HeroCol/HeroScroll/HeroVBox/CareerStats
@onready var tutorial_btn: Button = $Margin/RootVBox/Columns/HeroCol/HeroScroll/HeroVBox/TutorialBtn

@onready var offline_mode_btn: Button = $Margin/RootVBox/Columns/MissionCol/MissionVBox/NetRow/OfflineModeBtn
@onready var online_mode_btn: Button = $Margin/RootVBox/Columns/MissionCol/MissionVBox/NetRow/OnlineModeBtn
@onready var server_error_banner: PanelContainer = $Margin/RootVBox/Columns/MissionCol/MissionVBox/ServerErrorBanner
@onready var err_msg: Label = $Margin/RootVBox/Columns/MissionCol/MissionVBox/ServerErrorBanner/ErrRow/ErrMsg
@onready var err_offline_btn: Button = $Margin/RootVBox/Columns/MissionCol/MissionVBox/ServerErrorBanner/ErrRow/ErrOfflineBtn

@onready var story_mode_btn: Button = $Margin/RootVBox/Columns/MissionCol/MissionVBox/ModeRow/StoryModeBtn
@onready var endless_mode_btn: Button = $Margin/RootVBox/Columns/MissionCol/MissionVBox/ModeRow/EndlessModeBtn
@onready var stars_banner: Label = $Margin/RootVBox/Columns/MissionCol/MissionVBox/StarsBanner
@onready var stages_list: VBoxContainer = $Margin/RootVBox/Columns/MissionCol/MissionVBox/StageScroll/StagesList
@onready var deploy_btn: Button = $Margin/RootVBox/Columns/MissionCol/MissionVBox/DeployBtn

var _want_online: bool = false
var _mission_mode: String = "story"
var _selected_stage_id: int = 1


func _ready() -> void:
	_style_panels()
	var story_btn := Button.new()
	story_btn.text = "Story"
	story_btn.custom_minimum_size = Vector2(82, 40)
	var top_bar: HBoxContainer = $Margin/RootVBox/TopBar
	top_bar.add_child(story_btn)
	top_bar.move_child(story_btn, 1)
	story_btn.pressed.connect(func() -> void: request_replay_intro.emit())
	armory_btn.pressed.connect(func() -> void: request_open_armory.emit())
	social_btn.pressed.connect(func() -> void: request_open_social.emit())
	leaderboard_btn.pressed.connect(func() -> void: request_open_leaderboard.emit())
	settings_btn.pressed.connect(func() -> void: request_open_settings.emit())
	auth_btn.pressed.connect(func() -> void: request_open_auth.emit(""))

	ranger_btn.pressed.connect(func() -> void: _set_hero_class("ranger"))
	medic_btn.pressed.connect(func() -> void: _set_hero_class("medic"))
	male_btn.pressed.connect(func() -> void: _set_gender("male"))
	female_btn.pressed.connect(func() -> void: _set_gender("female"))
	tutorial_btn.pressed.connect(func() -> void:
		request_start_match.emit({"mode": "tutorial", "stage_id": 1, "online": false})
	)

	offline_mode_btn.pressed.connect(func() -> void:
		_want_online = false
		server_error_banner.hide()
		refresh_ui()
	)
	online_mode_btn.pressed.connect(_on_select_online_mode)
	err_offline_btn.pressed.connect(func() -> void:
		_want_online = false
		server_error_banner.hide()
		refresh_ui()
	)

	story_mode_btn.pressed.connect(func() -> void:
		_mission_mode = "story"
		refresh_ui()
	)
	endless_mode_btn.pressed.connect(func() -> void:
		_mission_mode = "endless"
		refresh_ui()
	)
	deploy_btn.pressed.connect(_on_deploy)

	SaveManager.save_changed.connect(func(_s: Dictionary) -> void: refresh_ui())
	SaveManager.settings_changed.connect(func(_s: Dictionary) -> void: refresh_ui())
	NetworkManager.connection_changed.connect(func(ok: bool, err: String) -> void:
		if not ok and _want_online and err != "":
			err_msg.text = err
			server_error_banner.show()
		elif ok:
			server_error_banner.hide()
		refresh_ui()
	)
	refresh_ui()


func _style_panels() -> void:
	var pad := StyleBoxFlat.new()
	pad.bg_color = Color("#141B25")
	pad.border_color = Color("#263244")
	pad.set_border_width_all(1)
	pad.set_corner_radius_all(10)
	pad.set_content_margin_all(14)
	hero_col.add_theme_stylebox_override("panel", pad)
	mission_col.add_theme_stylebox_override("panel", pad.duplicate())

	var err_sb := StyleBoxFlat.new()
	err_sb.bg_color = Color("#3B1219")
	err_sb.border_color = Color("#EF4444")
	err_sb.set_border_width_all(1)
	err_sb.set_corner_radius_all(8)
	err_sb.set_content_margin_all(10)
	server_error_banner.add_theme_stylebox_override("panel", err_sb)

	var d_sb := StyleBoxFlat.new()
	d_sb.bg_color = Color("#F59E0B")
	d_sb.set_corner_radius_all(10)
	deploy_btn.add_theme_stylebox_override("normal", d_sb)
	deploy_btn.add_theme_color_override("font_color", Color("#0F172A"))


func _set_hero_class(c: String) -> void:
	var next := SaveManager.save_data.duplicate(true)
	next["hero_class"] = c
	next["updated_at"] = int(Time.get_unix_time_from_system())
	SaveManager.write_save(next)
	NetworkManager.sync_save_to_cloud(next)
	AudioManager.play_pickup()


func _set_gender(g: String) -> void:
	var next := SaveManager.save_data.duplicate(true)
	next["gender"] = g
	next["updated_at"] = int(Time.get_unix_time_from_system())
	SaveManager.write_save(next)
	NetworkManager.sync_save_to_cloud(next)


func _on_select_online_mode() -> void:
	_want_online = true
	if NetworkManager.is_online:
		server_error_banner.hide()
		refresh_ui()
		return
	online_mode_btn.disabled = true
	online_mode_btn.text = "Checking Nakama..."
	var ok := await NetworkManager.check_server_health()
	online_mode_btn.disabled = false
	online_mode_btn.text = "Online Co-op (Nakama)"
	if ok:
		server_error_banner.hide()
		request_open_auth.emit("")
	else:
		err_msg.text = NetworkManager.last_error if NetworkManager.last_error != "" else "Multiplayer server unreachable. Check Wi-Fi or switch to Offline Mode."
		server_error_banner.show()
	refresh_ui()


func show_online_notice(message: String) -> void:
	err_msg.text = message
	server_error_banner.show()


func refresh_ui() -> void:
	var save := SaveManager.save_data
	var lang := str(SaveManager.settings.get("language", "en"))
	var h_class := str(save.get("hero_class", "ranger"))
	var gender := str(save.get("gender", "male"))
	var lvl_info := GameRules.compute_level_from_xp(int(save.get("experience", 0)))

	brand_title.text = str(ProjectSettings.get_setting("application/config/name", "Zombie Apocalypse: Ranger Outbreak"))
	armory_btn.text = GameData.t(lang, "armory")
	social_btn.text = GameData.t(lang, "social")
	leaderboard_btn.text = GameData.t(lang, "leaderboards")
	settings_btn.text = GameData.t(lang, "settings")
	tutorial_btn.text = GameData.t(lang, "play_tutorial") + " (No Death)"

	if NetworkManager.is_online:
		auth_btn.text = "%s · Online" % str(NetworkManager.auth_user.get("username", "User"))
		auth_btn.modulate = Color("#22C55E")
	else:
		auth_btn.text = "Offline Save"
		auth_btn.modulate = Color("#F59E0B")

	callsign_label.text = "%s · Lv.%d %s" % [str(save.get("username", "Ranger")), int(lvl_info["level"]), h_class.capitalize()]
	xp_bar.max_value = float(lvl_info["next_level_xp"])
	xp_bar.value = float(lvl_info["current_level_xp"])

	var eq: Array = save.get("equipped_weapons", ["basic_pistol", "basic_wand"])
	var active_wid := str(eq[1]) if h_class == "medic" and eq.size() > 1 else str(eq[0])
	hero_preview.configure(h_class, gender, active_wid)

	ranger_btn.modulate = Color("#F59E0B") if h_class == "ranger" else Color("#94A3B8")
	medic_btn.modulate = Color("#2DD4BF") if h_class == "medic" else Color("#94A3B8")
	male_btn.modulate = Color("#FFFFFF") if gender == "male" else Color("#94A3B8")
	female_btn.modulate = Color("#FFFFFF") if gender == "female" else Color("#94A3B8")

	var w_name := str(GameData.WEAPONS.get(active_wid, {}).get("name", active_wid))
	var w_lvl := int(save.get("weapon_upgrades", {}).get(active_wid, 0))
	weapon_summary.text = "Equipped: %s (+%d) · Tap Armory to upgrade" % [w_name, w_lvl]
	wallet_label.text = "%d SP · %d Boss Tokens" % [int(save.get("survival_points", 0)), int(save.get("boss_tokens", 0))]

	var stats: Dictionary = save.get("statistics", {})
	career_stats.text = "Kills: %d · Bosses: %d · Best Wave: %d" % [
		int(stats.get("zombie_kills", 0)),
		int(stats.get("boss_defeats", 0)),
		int(stats.get("highest_wave", 0)),
	]

	offline_mode_btn.modulate = Color("#22C55E") if not _want_online else Color("#94A3B8")
	online_mode_btn.modulate = Color("#38BDF8") if _want_online else Color("#94A3B8")
	story_mode_btn.modulate = Color("#F59E0B") if _mission_mode == "story" else Color("#94A3B8")
	endless_mode_btn.modulate = Color("#A855F7") if _mission_mode == "endless" else Color("#94A3B8")

	var total_stars := GameRules.get_total_stars(save.get("stage_stars", {}))
	stars_banner.text = "CAMPAIGN STARS COLLECTED: %d / 15 ★ (Required to unlock later sectors)" % total_stars

	_rebuild_stages_list(save, total_stars)

	if _mission_mode == "endless":
		deploy_btn.text = "OPEN ONLINE ROOM (ENDLESS)" if _want_online else "DEPLOY TO ENDLESS PORTAL"
	else:
		deploy_btn.text = "OPEN ONLINE ROOM (STAGE %d)" % _selected_stage_id if _want_online else "DEPLOY TO STAGE %d" % _selected_stage_id


func _rebuild_stages_list(save: Dictionary, total_stars: int) -> void:
	for c in stages_list.get_children():
		c.queue_free()

	if _mission_mode == "endless":
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#1B162C")
		sb.border_color = Color("#A855F7")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(14)
		card.add_theme_stylebox_override("panel", sb)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		card.add_child(vb)

		var t := Label.new()
		t.text = "INFINITE DIMENSIONAL PORTALS · 5 REALM BIOMES"
		t.add_theme_color_override("font_color", Color("#C084FC"))
		t.add_theme_font_size_override("font_size", 16)
		vb.add_child(t)

		var d := Label.new()
		d.text = "Survive escalating 10-wave realms, defeat Rift Guardians, and step through the Dimensional Portal to surge your Skill Power (+35% per realm!)."
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(d)
		stages_list.add_child(card)
		return

	var stars_map: Dictionary = save.get("stage_stars", {})
	if not GameRules.is_stage_unlocked(save, _selected_stage_id):
		_selected_stage_id = 1

	for st in GameData.STAGES:
		var sid := int(st["id"])
		var unlocked := GameRules.is_stage_unlocked(save, sid)
		var req_stars := GameRules.get_stage_required_stars(sid)
		var earned := int(stars_map.get(str(sid), 0))
		var is_sel := (_selected_stage_id == sid)

		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#1B2636") if is_sel else Color("#121822")
		if not unlocked:
			sb.bg_color = Color("#10141C")
		sb.border_color = Color("#F59E0B") if is_sel else (Color("#2B394D") if unlocked else Color("#1E293B"))
		sb.set_border_width_all(2 if is_sel else 1)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(12)
		card.add_theme_stylebox_override("panel", sb)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 3)
		row.add_child(info)

		var star_str := ""
		for s_i in range(3):
			star_str += "★" if s_i < earned else "☆"

		var head := Label.new()
		var lock_txt := "" if unlocked else " [LOCKED]"
		head.text = "Stage %d · %s  %s%s" % [sid, str(st["name"]), star_str, lock_txt]
		head.add_theme_color_override("font_color", Color("#F8FAFC") if unlocked else Color("#64748B"))
		head.add_theme_font_size_override("font_size", 15)
		info.add_child(head)

		var sub := Label.new()
		var boss_name := str(GameData.BOSSES[str(st["boss_id"])]["name"])
		if unlocked:
			sub.text = "Goal: Clear %d waves & defeat %s · Target <= %ds" % [
				int(st["waves_count"]),
				boss_name,
				int(GameRules.STAGE_TARGET_TIMES.get(sid, 240)),
			]
			sub.add_theme_color_override("font_color", Color("#94A3B8"))
		else:
			sub.text = "Locked — Clear Stage %d and collect %d/%d Total Stars" % [sid - 1, total_stars, req_stars]
			sub.add_theme_color_override("font_color", Color("#F87171"))
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(sub)

		var sel_btn := Button.new()
		sel_btn.custom_minimum_size = Vector2(110, 42)
		sel_btn.disabled = not unlocked
		sel_btn.text = "LOCKED" if not unlocked else ("SELECTED" if is_sel else "Select")
		var target_sid := sid
		sel_btn.pressed.connect(func() -> void:
			_selected_stage_id = target_sid
			AudioManager.play_pickup()
			refresh_ui()
		)
		row.add_child(sel_btn)

		stages_list.add_child(card)


func _on_deploy() -> void:
	if _want_online:
		if not NetworkManager.is_online:
			var ok := await NetworkManager.check_server_health()
			if not ok:
				var msg := NetworkManager.last_error if NetworkManager.last_error != "" else "Multiplayer server unreachable. Check Wi-Fi or switch to Offline Mode."
				err_msg.text = msg
				server_error_banner.show()
				return
			request_open_auth.emit("")
			return
		request_open_online_room.emit(_mission_mode, _selected_stage_id)
		return

	request_start_match.emit({
		"mode": _mission_mode,
		"stage_id": 99 if _mission_mode == "endless" else _selected_stage_id,
		"online": false,
	})
