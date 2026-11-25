extends Node

const NakamaEndpoint = preload("res://scripts/autoload/nakama_endpoint.gd")

@onready var arena: Node2D = $WorldLayer/GameArena
@onready var splash: Control = $UILayer/SplashScreen
@onready var lobby: Control = $UILayer/LobbyHub
@onready var story_modal: Control = $UILayer/StoryCutsceneModal
@onready var hud: Control = $UILayer/GameHUD
@onready var shop_modal: Control = $UILayer/BunkerShopModal
@onready var pause_modal: Control = $UILayer/PauseModal
@onready var result_modal: Control = $UILayer/ResultModal
@onready var armory_modal: Control = $UILayer/ArmoryModal
@onready var social_modal: Control = $UILayer/SocialModal
@onready var leaderboard_modal: Control = $UILayer/LeaderboardModal
@onready var online_room_modal: Control = $UILayer/OnlineRoomModal
@onready var settings_modal: Control = $UILayer/SettingsModal
@onready var auth_modal: Control = $UILayer/AuthModal
@onready var quit_dialog: ConfirmationDialog = $QuitDialog

var _pending_match_cfg: Dictionary = {}
var _in_match: bool = false
var _online_deploy_sent: bool = false
var _last_shop_snapshot: Dictionary = {}
var _match_host_user_id: String = ""
var _match_epoch: int = 0
var _home_intro_open: bool = false
var _hud_overlay_paused: bool = false


func _ready() -> void:
	arena.bind_hud(hud)
	# The OTA loader in older APKs keeps their original NetworkManager script.
	if OS.get_environment("NAKAMA_SERVER_URL").strip_edges().is_empty():
		var current_url := NetworkManager.server_url
		var resolved_url := NakamaEndpoint.resolve(current_url)
		if current_url != resolved_url:
			NetworkManager.set_server_url(resolved_url)
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	settings_modal.quit_requested.connect(_request_quit)
	quit_dialog.confirmed.connect(_quit_game)

	splash.entered.connect(func() -> void:
		splash.hide()
		lobby.show()
		lobby.refresh_ui()
		if not bool(SaveManager.settings.get("home_intro_seen", false)):
			_open_home_intro()
	)

	lobby.request_open_armory.connect(func() -> void: armory_modal.open_modal())
	lobby.request_open_social.connect(func() -> void: social_modal.open_modal())
	lobby.request_open_leaderboard.connect(func() -> void: leaderboard_modal.open_modal())
	lobby.request_open_settings.connect(func() -> void: settings_modal.open_modal())
	lobby.request_open_auth.connect(func(err: String) -> void: auth_modal.open_modal(err))
	lobby.request_open_online_room.connect(func(m: String, sid: int) -> void: online_room_modal.open_modal(m, sid))
	lobby.request_start_match.connect(_prepare_match)
	lobby.request_replay_intro.connect(_open_home_intro)

	story_modal.deploy_requested.connect(_on_deploy_requested)
	story_modal.sequence_completed.connect(func() -> void:
		if _home_intro_open:
			_home_intro_open = false
			SaveManager.write_settings({"home_intro_seen": true})
			return
		if _in_match and not arena.match_ended:
			if arena.maya_phase == "finale":
				arena.continue_maya_antidote_finale()
			elif arena.maya_phase == "cutscene":
				arena.continue_maya_transformation()
			if not arena.match_ended and arena.maya_phase in ["cutscene", "finale"]:
				var squad_size := maxi(1, int(NetworkManager.current_room.get("players", []).size())) if arena.is_online else 1
				story_modal.set_waiting_for_squad(-1, squad_size)
				story_modal.show()
	)
	story_modal.cancelled.connect(func() -> void:
		if bool(_pending_match_cfg.get("online", false)):
			_match_host_user_id = ""
			_pending_match_cfg = {}
			_online_deploy_sent = false
			NetworkManager.leave_room()
		lobby.show()
		lobby.refresh_ui()
	)

	NetworkManager.match_started.connect(func(payload: Dictionary) -> void:
		online_room_modal.hide()
		_match_host_user_id = str(payload.get("hostUserId", ""))
		var cfg := {
			"mode": str(payload.get("mode", "story")),
			"stage_id": int(payload.get("stageId", 1)),
			"online": true,
		}
		_prepare_match(cfg)
	)
	NetworkManager.room_updated.connect(func(room: Dictionary) -> void:
		if _match_host_user_id == "" or not bool(_pending_match_cfg.get("online", false)):
			return
		var new_host_id := str(room.get("host_user_id", ""))
		if new_host_id != "" and new_host_id != _match_host_user_id:
			_exit_to_lobby()
			lobby.show_online_notice("The host left the match. Rejoin or create a new squad.")
	)
	NetworkManager.realtime_disconnected.connect(func(reason: String) -> void:
		if bool(_pending_match_cfg.get("online", false)) and (not _in_match or not arena.match_ended):
			_exit_to_lobby()
			lobby.show_online_notice(reason)
	)
	NetworkManager.match_deploy_state.connect(func(state: Dictionary) -> void:
		if not bool(_pending_match_cfg.get("online", false)) or _in_match:
			return
		if bool(state.get("allReady", false)):
			if _online_deploy_sent:
				_launch_pending_match()
		elif _online_deploy_sent:
			story_modal.set_waiting_for_squad(int(state.get("readyCount", 0)), int(state.get("total", 1)))
	)

	# In-game HUD signals
	hud.shop_pressed.connect(_toggle_shop)
	hud.pause_pressed.connect(_toggle_pause)
	hud.restart_pressed.connect(_restart_match)
	hud.next_wave_pressed.connect(arena.skip_wave_preparation)
	hud.settings_pressed.connect(func() -> void:
		_pause_for_hud_overlay()
		settings_modal.open_modal()
	)
	hud.help_toggled.connect(func(open: bool) -> void:
		if open:
			_pause_for_hud_overlay()
		else:
			_resume_from_hud_overlay()
	)
	settings_modal.closed.connect(_resume_from_hud_overlay)
	hud.skill_pressed.connect(func(sid: String) -> void: arena.trigger_skill(sid))
	hud.item_use_pressed.connect(func(iid: String) -> void:
		var err: String = arena.use_inventory_item(iid)
		if not err.is_empty():
			hud.show_toast(err)
	)
	hud.revive_target_selected.connect(func(uid: String) -> void: arena.trigger_skill("medic_revive_ultimate", uid))

	# Shop signals
	shop_modal.closed.connect(func() -> void:
		if _in_match:
			arena.set_paused(false)
	)
	shop_modal.buy_item.connect(func(iid: String) -> void:
		var err: String = arena.buy_shop_item(iid)
		if err != "":
			shop_modal.show_feedback(err)
		else:
			shop_modal.refresh_snapshot(arena.get_shop_snapshot())
	)
	shop_modal.buy_skill_charge.connect(func(sid: String) -> void:
		var err: String = arena.buy_skill_charge(sid)
		if err != "":
			shop_modal.show_feedback(err)
		else:
			shop_modal.refresh_snapshot(arena.get_shop_snapshot())
	)
	shop_modal.upgrade_skill.connect(func(sid: String) -> void:
		var err: String = arena.upgrade_skill_rank(sid)
		if err != "":
			shop_modal.show_feedback(err)
		else:
			shop_modal.refresh_snapshot(arena.get_shop_snapshot())
	)
	shop_modal.upgrade_maya_tower.connect(func() -> void:
		var err: String = arena.upgrade_maya_tower()
		if err != "":
			shop_modal.show_feedback(err)
		else:
			shop_modal.refresh_snapshot(arena.get_shop_snapshot())
	)

	# Pause modal signals
	pause_modal.resume_pressed.connect(func() -> void:
		if _in_match:
			if arena.is_online:
				arena.request_team_resume()
			else:
				arena.set_paused(false)
	)
	pause_modal.restart_pressed.connect(_restart_match)
	pause_modal.settings_pressed.connect(func() -> void: settings_modal.open_modal())
	pause_modal.lobby_pressed.connect(_exit_to_lobby)

	# Result modal signals
	result_modal.retry_pressed.connect(_restart_match)
	result_modal.next_pressed.connect(func(next_sid: int) -> void:
		if bool(_pending_match_cfg.get("online", false)):
			_exit_to_lobby()
		else:
			_prepare_match({"mode": "story", "stage_id": next_sid, "online": false})
	)
	result_modal.menu_pressed.connect(_exit_to_lobby)

	# Arena signals
	arena.hud_updated.connect(func(snap: Dictionary) -> void:
		if _in_match:
			hud.update_hud(snap)
			if shop_modal.visible:
				var shop_snapshot: Dictionary = arena.get_shop_snapshot()
				if shop_snapshot != _last_shop_snapshot:
					_last_shop_snapshot = shop_snapshot.duplicate(true)
					shop_modal.refresh_snapshot(shop_snapshot)
	)
	arena.toast_requested.connect(func(msg: String) -> void:
		hud.show_toast(msg)
	)
	arena.team_pause_changed.connect(func(paused: bool, owner_name: String) -> void:
		if not _in_match:
			return
		if paused:
			shop_modal.hide()
			arena.set_paused(true)
			pause_modal.configure_team_pause(true, owner_name)
			pause_modal.show()
		else:
			pause_modal.hide()
			arena.set_paused(false)
	)
	arena.match_finished.connect(_on_match_finished)
	arena.maya_transformation_requested.connect(func() -> void:
		if not _in_match:
			return
		shop_modal.hide()
		pause_modal.hide()
		arena.set_paused(true)
		story_modal.open_maya_infection_story()
	)
	arena.maya_boss_started.connect(func() -> void:
		if _in_match:
			story_modal.hide()
			arena.set_paused(false)
	)
	arena.maya_antidote_requested.connect(func(finisher: Dictionary) -> void:
		if not _in_match:
			return
		shop_modal.hide()
		pause_modal.hide()
		arena.set_paused(true)
		story_modal.open_maya_antidote_finale(str(finisher.get("name", "Ranger")), str(finisher.get("class", "ranger")), finisher.get("squad", []))
	)
	arena.maya_finale_completed.connect(func() -> void:
		if _in_match:
			story_modal.hide()
			arena.set_paused(false)
	)


func _open_home_intro() -> void:
	_home_intro_open = true
	story_modal.open_home_intro()


func _prepare_match(cfg: Dictionary) -> void:
	_pending_match_cfg = cfg.duplicate(true)
	_in_match = false
	_online_deploy_sent = false
	_last_shop_snapshot = {}
	lobby.hide()
	result_modal.hide()
	pause_modal.hide()
	pause_modal.configure_team_pause(false)
	shop_modal.hide()

	var m := str(cfg.get("mode", "story"))
	var sid := int(cfg.get("stage_id", 1))
	if m == "tutorial":
		_launch_pending_match()
	else:
		story_modal.open_briefing(m, sid, 1)


func _on_deploy_requested() -> void:
	if _pending_match_cfg.is_empty():
		return
	if not bool(_pending_match_cfg.get("online", false)):
		_launch_pending_match()
		return
	if _online_deploy_sent:
		return
	_online_deploy_sent = true
	var squad_size := maxi(1, int(NetworkManager.current_room.get("players", []).size()))
	story_modal.set_waiting_for_squad(1, squad_size)
	NetworkManager.send_deploy_ready()


func _launch_pending_match() -> void:
	_match_epoch += 1
	_in_match = true
	lobby.hide()
	story_modal.hide()
	result_modal.hide()
	pause_modal.hide()
	pause_modal.configure_team_pause(false)
	shop_modal.hide()

	var h_class := str(SaveManager.save_data.get("hero_class", "ranger"))
	hud.configure_skills(h_class)
	arena.show()
	hud.show()
	arena.start_match(_pending_match_cfg)


func _restart_match() -> void:
	if _pending_match_cfg.is_empty():
		return
	if bool(_pending_match_cfg.get("online", false)):
		_exit_to_lobby()
		return
	_launch_pending_match()


func _exit_to_lobby() -> void:
	AudioManager.stop_combat_music()
	_match_epoch += 1
	_in_match = false
	_match_host_user_id = ""
	_pending_match_cfg = {}
	_online_deploy_sent = false
	arena.set_paused(true)
	arena.hide()
	hud.hide()
	story_modal.hide()
	shop_modal.hide()
	pause_modal.hide()
	result_modal.hide()
	if not NetworkManager.current_room.is_empty():
		NetworkManager.leave_room()
	lobby.show()
	lobby.refresh_ui()


func _toggle_shop() -> void:
	if not _in_match or arena.match_ended or arena.maya_phase in ["cutscene", "finale"] or arena.shared_paused:
		return
	if shop_modal.visible:
		shop_modal.hide()
		arena.set_paused(false)
	else:
		arena.set_paused(true)
		shop_modal.open_shop(arena.get_shop_snapshot())


func _pause_for_hud_overlay() -> void:
	_hud_overlay_paused = _in_match and not arena.is_online and not arena.is_paused
	if _hud_overlay_paused:
		arena.set_paused(true)


func _resume_from_hud_overlay() -> void:
	if _hud_overlay_paused and _in_match and not arena.is_online and not arena.match_ended:
		arena.set_paused(false)
	_hud_overlay_paused = false


func _toggle_pause() -> void:
	if not _in_match or arena.match_ended or arena.maya_phase in ["cutscene", "finale"]:
		return
	if shop_modal.visible:
		shop_modal.hide()
		arena.set_paused(false)
		if not arena.is_online:
			return
	if arena.is_online:
		if arena.shared_paused:
			arena.request_team_resume()
		else:
			var reason: String = arena.request_team_pause()
			if not reason.is_empty():
				hud.show_toast(reason)
		return
	if pause_modal.visible:
		pause_modal.hide()
		arena.set_paused(false)
	else:
		arena.set_paused(true)
		pause_modal.show()


func _on_match_finished(summary: Dictionary) -> void:
	var finished_epoch := _match_epoch
	_match_host_user_id = ""
	arena.set_paused(true)
	story_modal.hide()
	shop_modal.hide()
	pause_modal.hide()
	if bool(summary.get("online", false)):
		if not NetworkManager.is_online or NetworkManager.current_room.is_empty():
			_exit_to_lobby()
			lobby.show_online_notice("The match result could not be verified after the connection was lost.")
			return
		await NetworkManager.commit_online_match_result(summary)
	else:
		SaveManager.commit_offline_match_result(summary)
	if finished_epoch != _match_epoch:
		return
	result_modal.open_result(summary)


func _unhandled_input(event: InputEvent) -> void:
	if quit_dialog.visible:
		return
	if event.is_action_pressed("pause_game"):
		if settings_modal.visible:
			settings_modal.close_modal()
			get_viewport().set_input_as_handled()
			return
		if not _in_match and (lobby.visible or splash.visible):
			_request_quit()
			get_viewport().set_input_as_handled()
			return
	if not _in_match or arena.match_ended:
		return
	if settings_modal.visible or hud._help_overlay.visible:
		return
	if arena.maya_phase in ["cutscene", "finale"]:
		return
	if event.is_action_pressed("pause_game"):
		_toggle_pause()
	elif event.is_action_pressed("toggle_shop"):
		_toggle_shop()
	elif event.is_action_pressed("reload"):
		arena.start_reload()
	elif not arena.is_paused and not arena.shared_paused:
		var h_class := str(SaveManager.save_data.get("hero_class", "ranger"))
		var skills: Array = GameData.CLASS_SKILLS.get(h_class, [])
		if event.is_action_pressed("skill_q") and skills.size() >= 1:
			arena.trigger_skill(str(skills[0]))
		elif event.is_action_pressed("skill_e") and skills.size() >= 2:
			arena.trigger_skill(str(skills[1]))
		elif event.is_action_pressed("skill_f") and skills.size() >= 3:
			arena.trigger_skill(str(skills[2]))
		elif event.is_action_pressed("skill_space") and skills.size() >= 4:
			arena.trigger_skill(str(skills[3]))
		elif event.is_action_pressed("skill_x") and skills.size() >= 5:
			arena.trigger_skill(str(skills[4]))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		if quit_dialog.visible:
			quit_dialog.hide()
		elif settings_modal.visible:
			settings_modal.close_modal()
		elif _in_match and not arena.match_ended:
			_toggle_pause()
		else:
			_request_quit()


func _request_quit() -> void:
	if not is_node_ready() or quit_dialog.visible:
		return
	quit_dialog.dialog_text = "Quit the game and leave the current match?" if _in_match and not arena.match_ended else "Exit Zombie Apocalypse: Ranger Outbreak?"
	quit_dialog.popup_centered()
	quit_dialog.get_cancel_button().grab_focus()


func _quit_game() -> void:
	if not NetworkManager.current_room.is_empty():
		NetworkManager.leave_room()
	get_tree().quit()
