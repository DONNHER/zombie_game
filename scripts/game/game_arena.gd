extends Node2D

const ComicActorDraw = preload("res://scripts/game/comic_actor_draw.gd")
const ArenaExploration = preload("res://scripts/game/arena_exploration.gd")

signal hud_updated(snapshot: Dictionary)
signal match_finished(summary: Dictionary)
signal toast_requested(msg: String)
signal maya_transformation_requested
signal maya_boss_started
signal maya_antidote_requested(finisher: Dictionary)
signal maya_finale_completed
signal team_pause_changed(paused: bool, owner_name: String)

const PLAYER_STATE_OP := 3
const WORLD_STATE_OP := 6
const PLAYER_ACTION_OP := 7
const NET_INTERVAL := 0.05
const TEAM_PAUSE_COOLDOWN_MS := 256000
const ENEMY_MOVE_SPEED_SCALE := 0.65
const ENEMY_DAMAGE_SCALE := 0.50
const BOSS_DAMAGE_SCALE := 0.55
const STOCKED_ITEMS := ["ammo_medkit", "build_wall", "build_spike", "build_turret", "revive_kit"]
const WAVE_PREP_SECONDS := 30.0
const ARENA_EDGE_INSET := 128.0
const CORPSE_REST_SECONDS := 0.95
const CORPSE_REACH_SECONDS := 1.25
const CORPSE_GRIP_SECONDS := 0.65
const CORPSE_DRAG_SECONDS := 2.85
const MAX_MOVE_CREDIT_SECONDS := 0.45
const MAX_PENDING_INPUTS := 40
const ENTITY_FIELDS := {
	"enemies": ["id", "x", "y", "radius", "color", "hp", "max_hp", "is_boss", "boss_id", "name", "passes_walls", "corpse_count"],
	"projectiles": ["x", "y", "color"],
	"pickups": ["x", "y", "kind"],
	"builds": ["x", "y", "kind"],
	"clones": ["x", "y"],
	"shockwaves": ["x", "y", "r", "color"],
	"particles": ["x", "y", "color"],
	"floating_texts": ["x", "y", "text", "color"],
	"corpse_visuals": ["sx", "sy", "ex", "ey", "t", "color", "gathering", "boss", "kind", "boss_id", "radius", "delay"],
}

@onready var cam: Camera2D = $Camera2D
@onready var _fog: Sprite2D = $ExplorationFog

# Match config
var mode: String = "story" # "story" | "endless" | "tutorial"
var stage_id: int = 1
var is_online: bool = false
var is_host: bool = true
var portal_realm: int = 1
var _stage_data: Dictionary = {}
var _exploration := ArenaExploration.new()
var _terrain: Array[Rect2] = []

# Player state
var player: Dictionary = {}
var skill_cooldowns: Dictionary = {}
var skill_charges: Dictionary = {}
var skill_levels: Dictionary = {}
var aim_target_id: Variant = null

# Arena entities
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var builds: Array[Dictionary] = []
var clones: Array[Dictionary] = []
var shockwaves: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var corpse_visuals: Array[Dictionary] = []
var corpse_count: int = 0
var gather_timer: float = 0.0
var gather_center: Vector2 = Vector2.ZERO
var rolling_phase: String = "none" # none | gathering | boss | defeated
var _gather_with_maya: bool = false
var _last_final_boss_pos: Vector2 = Vector2.ZERO
var maya_finisher: Dictionary = {}
var remote_players: Dictionary = {} # user_id -> {x, y, hp, max_hp, downed, angle, hero_class, username}

# Wave & bunker state
var wave: int = 1
var current_bunker_idx: int = 0
var enemies_to_spawn: Array[String] = []
var spawn_timer: float = 0.0
var _edge_spawn_index: int = 0
var waiting_for_next_wave: bool = false
var wave_prep_remaining: float = 0.0
var boss_spawned_for_wave: bool = false
var maya_level: int = 1
var maya_hp: float = 160.0
var maya_max_hp: float = 160.0
var maya_fire_timer: float = 0.0
var maya_phase: String = "none" # none | cutscene | boss | done
var _maya_story_ready: Dictionary = {}
var portal_active: bool = false
var stage_task: Dictionary = {}

# Economy & Stats
var coins: int = 120
var kills: int = 0
var boss_defeats: int = 0
var points_earned: int = 0
var xp_earned: int = 0
var tokens_earned: int = 0
var damage_taken: int = 0
var elapsed_seconds: float = 0.0
var time_of_day_hour: float = 12.0
var match_ended: bool = false
var is_paused: bool = false
var shared_paused: bool = false
var shared_pause_owner_id: String = ""
var shared_pause_owner_name: String = ""
var _pause_ready_at_ms: Dictionary = {}
var _guest_pause_remaining: int = 0

# Tutorial state
var tutorial_step_idx: int = 0
var _tut_move_dist: float = 0.0
var _tut_did_fire: bool = false
var _tut_did_shop: bool = false
var _tut_did_skill: bool = false

# Timers & Input
var _next_uid: int = 1
var _shake_trauma: float = 0.0
var _hud_sync_timer: float = 0.0
var _net_sync_timer: float = 0.0
var _hud_ref: Control = null
var _host_user_id: String = ""
var _local_user_id: String = ""
var _world_sequence: int = 0
var _spawn_remaining: int = 0
var _firing: bool = false
var _mouse_fire_down: bool = false
var _input_sequence: int = 0
var _acked_input_sequence: int = 0
var _pending_input_positions: Dictionary = {}
var _enemy_net_targets: Dictionary = {}
var _visual_time: float = 0.0


func bind_hud(hud: Control) -> void:
	_hud_ref = hud


func start_match(config: Dictionary) -> void:
	AudioManager.start_combat_music()
	mode = str(config.get("mode", "story"))
	stage_id = int(config.get("stage_id", 1))
	is_online = bool(config.get("online", false))
	is_host = (not is_online) or NetworkManager.is_room_host()
	portal_realm = 1
	_stage_data = GameData.get_stage_by_id(99 if mode == "endless" else (1 if mode == "tutorial" else stage_id), portal_realm)

	var save := SaveManager.save_data
	var h_class := str(save.get("hero_class", "ranger"))
	var eq: Array = save.get("equipped_weapons", ["basic_pistol", "basic_wand"])
	var wid := str(eq[1]) if h_class == "medic" and eq.size() > 1 else str(eq[0])
	var w_lvl := int(save.get("weapon_upgrades", {}).get(wid, 0))
	var bunkers: Array = _stage_data.get("bunkers", [])
	var start_b: Dictionary = bunkers[0] if not bunkers.is_empty() else {"x": 450.0, "y": 540.0, "radius": 180.0}
	player = _create_player(float(start_b["x"]), float(start_b["y"]), h_class, str(save.get("gender", "male")), str(save.get("username", "Ranger")), wid, w_lvl)

	skill_cooldowns = player["skill_cooldowns"]
	skill_charges = player["skill_charges"]
	skill_levels = player["skill_levels"]

	enemies.clear()
	projectiles.clear()
	pickups.clear()
	builds.clear()
	clones.clear()
	shockwaves.clear()
	particles.clear()
	floating_texts.clear()
	corpse_visuals.clear()
	corpse_count = 0
	gather_timer = 0.0
	gather_center = Vector2.ZERO
	rolling_phase = "none"
	_gather_with_maya = false
	_last_final_boss_pos = Vector2.ZERO
	maya_finisher = {}
	remote_players.clear()
	enemies_to_spawn.clear()

	wave = 1
	current_bunker_idx = 0
	waiting_for_next_wave = false
	wave_prep_remaining = 0.0
	boss_spawned_for_wave = false
	portal_active = false
	stage_task = {}
	maya_level = 1
	maya_phase = "none"
	_maya_story_ready.clear()
	var m_stats := GameRules.get_maya_tower_stats(1)
	maya_max_hp = float(m_stats["max_hp"])
	maya_hp = maya_max_hp

	coins = 250 if mode == "tutorial" else 120
	kills = 0
	boss_defeats = 0
	points_earned = 0
	xp_earned = 0
	tokens_earned = 0
	damage_taken = 0
	elapsed_seconds = 0.0
	time_of_day_hour = 13.0 if stage_id <= 2 else 19.8
	match_ended = false
	is_paused = false
	shared_paused = false
	shared_pause_owner_id = ""
	shared_pause_owner_name = ""
	_pause_ready_at_ms.clear()
	_guest_pause_remaining = 0
	aim_target_id = null

	tutorial_step_idx = 0
	_tut_move_dist = 0.0
	_tut_did_fire = false
	_tut_did_shop = false
	_tut_did_skill = false

	_next_uid = 1
	maya_fire_timer = 0.0
	_net_sync_timer = 0.0
	_world_sequence = 0
	_spawn_remaining = 0
	_firing = false
	_mouse_fire_down = false
	_input_sequence = 0
	_acked_input_sequence = 0
	_pending_input_positions.clear()
	_enemy_net_targets.clear()
	_visual_time = 0.0
	_local_user_id = str(NetworkManager.auth_user.get("user_id", ""))
	_host_user_id = str(NetworkManager.current_room.get("host_user_id", ""))
	if is_host:
		_initialize_stage_task()
	if is_online:
		if not is_host:
			var spawn_pos := _actor_position(player) + _guest_spawn_offset(_local_user_id)
			var resolved := _resolve_world_collisions(spawn_pos.x, spawn_pos.y, float(player["radius"]), false)
			player["x"] = resolved.x
			player["y"] = resolved.y
		if not NetworkManager.match_data_received.is_connected(_on_net_match_data):
			NetworkManager.match_data_received.connect(_on_net_match_data)
		if not NetworkManager.room_updated.is_connected(_on_net_room_updated):
			NetworkManager.room_updated.connect(_on_net_room_updated)
		_broadcast_local_state()
	if is_host:
		_begin_wave(1)
	_reset_exploration()
	_emit_hud_snapshot()
	queue_redraw()


func _guest_spawn_offset(user_id: String) -> Vector2:
	var slot := 0
	for entry in NetworkManager.current_room.get("players", []):
		var uid := str(entry.get("userId", ""))
		if uid == _host_user_id:
			continue
		if uid == user_id:
			break
		slot += 1
	return Vector2.RIGHT.rotated(slot * PI * 0.5) * 54.0


func _create_player(x: float, y: float, h_class: String, gender: String, username: String, wid: String, w_lvl: int) -> Dictionary:
	var weapon := GameRules.compute_effective_weapon_stats(wid, w_lvl)
	var health := 140.0 if h_class == "ranger" else 130.0
	var speed := 228.0 if h_class == "ranger" else 220.0
	return {
		"x": x, "y": y, "angle": 0.0, "radius": 16.0,
		"hp": health, "max_hp": health, "mana": 100.0, "max_mana": 100.0,
		"ammo": int(weapon["mag_size"]), "mag_size": int(weapon["mag_size"]),
		"weapon_id": wid, "weapon_level": w_lvl, "weapon": weapon,
		"hero_class": h_class, "gender": gender, "username": username,
		"downed": false, "revive_progress": 0.0, "warp_id": 0,
		"speed": speed, "move_credit": speed * NET_INTERVAL, "input_sequence": 0,
		"damage_multiplier": 1.0, "hazard_damage": 0.0,
		"reload_timer": 0.0, "fire_timer": 0.0, "mg_timer": 0.0, "invuln_timer": 0.0,
		"shot_count": 0, "last_shot": "", "skill_uses": 0,
		"skill_cooldowns": GameRules.create_empty_skill_cooldowns(),
		"skill_charges": GameRules.create_initial_skill_charges(h_class),
		"skill_levels": GameRules.create_initial_skill_levels(),
		"item_inventory": {},
		"input_firing": false, "last_input_ms": 0, "visual_moving": false,
	}


func set_paused(p: bool) -> void:
	is_paused = p
	if p and is_online and not is_host and _firing:
		_firing = false
		_broadcast_local_state()


func get_local_pause_remaining() -> int:
	if not is_online:
		return 0
	if not is_host:
		return _guest_pause_remaining
	var now := Time.get_ticks_msec()
	return maxi(0, ceili(float(int(_pause_ready_at_ms.get(_local_user_id, 0)) - now) / 1000.0))


func request_team_pause() -> String:
	if not is_online or match_ended or maya_phase in ["cutscene", "finale"]:
		return "Squad pause is unavailable right now."
	if shared_paused:
		return "The squad is already paused."
	var remaining := get_local_pause_remaining()
	if remaining > 0:
		return "Squad pause ready in %d seconds." % remaining
	if is_host:
		return _host_request_team_pause(_local_user_id)
	_send_player_action("team_pause")
	return ""


func request_team_resume() -> void:
	if not is_online or not shared_paused:
		return
	if is_host:
		_set_shared_pause(false, "")
	else:
		_send_player_action("team_resume")


func _host_request_team_pause(user_id: String) -> String:
	if shared_paused or maya_phase in ["cutscene", "finale"] or match_ended:
		return "Squad pause is unavailable right now."
	var now := Time.get_ticks_msec()
	var remaining := maxi(0, ceili(float(int(_pause_ready_at_ms.get(user_id, 0)) - now) / 1000.0))
	if remaining > 0:
		return "Squad pause ready in %d seconds." % remaining
	_pause_ready_at_ms[user_id] = now + TEAM_PAUSE_COOLDOWN_MS
	_set_shared_pause(true, user_id)
	return ""


func _set_shared_pause(paused: bool, owner_id: String) -> void:
	if shared_paused == paused:
		return
	shared_paused = paused
	shared_pause_owner_id = owner_id if paused else ""
	shared_pause_owner_name = ""
	if paused:
		if owner_id == _local_user_id:
			shared_pause_owner_name = str(player.get("username", "Ranger"))
		elif remote_players.has(owner_id):
			shared_pause_owner_name = str(remote_players[owner_id].get("username", "Squadmate"))
		else:
			for entry in NetworkManager.current_room.get("players", []):
				if str(entry.get("userId", "")) == owner_id:
					shared_pause_owner_name = str(entry.get("username", "Squadmate"))
					break
		if shared_pause_owner_name.is_empty():
			shared_pause_owner_name = "Squadmate"
	if paused:
		_firing = false
		for actor in remote_players.values():
			actor["input_firing"] = false
	team_pause_changed.emit(paused, shared_pause_owner_name)
	if is_host:
		_broadcast_world()


func _uid() -> int:
	var id := _next_uid
	_next_uid += 1
	return id


func _begin_wave(w: int) -> void:
	wave = w
	waiting_for_next_wave = false
	wave_prep_remaining = 0.0
	boss_spawned_for_wave = false
	_edge_spawn_index = 0
	enemies_to_spawn.clear()

	var bunkers: Array = _stage_data.get("bunkers", [])
	if mode == "story" and bunkers.size() > 0:
		current_bunker_idx = clampi(w - 1, 0, bunkers.size() - 1)
	elif mode == "endless" and bunkers.size() > 0:
		current_bunker_idx = (w - 1) % bunkers.size()
	_terrain = _terrain_blockers(_get_current_bunker())

	if mode == "tutorial":
		enemies_to_spawn = ["basic", "basic", "basic", "fast"]
		spawn_timer = 0.4
		return

	if mode == "endless":
		var comp := GameRules.calculate_endless_wave_composition(w)
		var mix: Array = comp["allowed_types"]
		for _i in range(int(comp["total_enemies"])):
			enemies_to_spawn.append(str(mix[randi() % mix.size()]))
		if int(comp["mini_boss_count"]) > 0:
			enemies_to_spawn.append("elite")
		if str(comp["boss_id"]) != "":
			enemies_to_spawn.append("BOSS:" + str(comp["boss_id"]))
		spawn_timer = 0.5
		return

	var mix_s: Array = _stage_data.get("enemy_mix", ["basic"])
	var count := 6 + w * 4 + stage_id * 2
	for _i in range(count):
		enemies_to_spawn.append(str(mix_s[randi() % mix_s.size()]))
	if w >= int(_stage_data.get("waves_count", 5)):
		enemies_to_spawn.append("BOSS:" + str(_stage_data.get("boss_id", "village_boss")))
	spawn_timer = 0.5


func _initialize_stage_task() -> void:
	if mode != "story":
		return
	var task_type := ""
	var detail := ""
	match stage_id:
		1:
			task_type = "antidote"
			detail = "prototype antidote"
		5:
			task_type = "deliver_antidote"
			detail = "Omega extraction lab"
		_:
			var options := ["repair", "supply", "rescue"]
			options.erase(str(SaveManager.save_data.get("last_task_type", "")))
			task_type = str(options.pick_random())
			match task_type:
				"repair": detail = str(["field relay", "signal repeater", "power junction"].pick_random())
				"supply": detail = str(["medical crates", "radio batteries", "ammunition cache"].pick_random())
				"rescue": detail = str(["Ranger Inez", "Medic Sol", "Scout Theo"].pick_random())
	var bunkers: Array = _stage_data.get("bunkers", [])
	var target_idx := 1 if stage_id == 1 else (maxi(0, bunkers.size() - 2) if stage_id == 5 else randi_range(1, maxi(1, mini(bunkers.size() - 2, int(_stage_data.get("waves_count", 5)) - 2))))
	var target: Dictionary = bunkers[mini(target_idx, bunkers.size() - 1)]
	var side := -1.0 if randi() % 2 == 0 else 1.0
	stage_task = {
		"type": task_type, "detail": detail, "phase": 0, "complete": false,
		"bunker_idx": target_idx,
		"antidote_carry": stage_id > 1 and bool(SaveManager.save_data.get("antidote_secured", false)),
		"x": float(target["x"]) + side * 105.0,
		"y": float(target["y"]) + randf_range(-65.0, 65.0),
		"drop_x": float(target["x"]) - side * 105.0,
		"drop_y": float(target["y"]) - randf_range(-65.0, 65.0),
		"progress": 0.0,
	}
	if task_type == "deliver_antidote" and not bool(SaveManager.save_data.get("antidote_secured", false)):
		stage_task["phase"] = -1


func _task_target() -> Vector2:
	if int(stage_task.get("phase", 0)) == 1:
		return Vector2(float(stage_task["drop_x"]), float(stage_task["drop_y"]))
	return Vector2(float(stage_task.get("x", 0.0)), float(stage_task.get("y", 0.0)))


func _task_label() -> String:
	if stage_task.is_empty():
		return ""
	if bool(stage_task.get("complete", false)):
		return "TASK COMPLETE · Final wave unlocked"
	if int(stage_task.get("phase", 0)) == -1:
		return "ANTIDOTE MISSING · Clear Stage 1 to retrieve it"
	var name := str(stage_task["detail"])
	match str(stage_task["type"]):
		"antidote": return "Collect the %s at the field clinic" % name
		"deliver_antidote": return "Deliver the antidote to the %s" % name
		"repair": return "Hold near the %s to repair it" % name
		"supply": return "Deliver %s to the bunker" % name if int(stage_task["phase"]) == 1 else "Pick up %s" % name
		"rescue": return "Hold near %s to rescue them" % name
	return "Complete the stage task"


func _antidote_status() -> String:
	if mode != "story" or stage_task.is_empty():
		return ""
	if stage_id == 1:
		return "Prototype antidote secured" if bool(stage_task.get("complete", false)) else ""
	if stage_id == 5:
		if not bool(stage_task.get("antidote_carry", false)):
			return "Antidote missing: retrieve it in Stage 1"
		return "Antidote delivered to Omega" if bool(stage_task.get("complete", false)) else "Antidote carried toward Omega"
	return "Antidote safe with the squad" if bool(stage_task.get("antidote_carry", false)) else ""


func _update_stage_task(delta: float, living: Array[Dictionary]) -> void:
	if stage_task.is_empty() or bool(stage_task.get("complete", false)) or int(stage_task.get("phase", 0)) < 0:
		return
	if mode == "story" and current_bunker_idx < int(stage_task.get("bunker_idx", 0)):
		return
	var target := _task_target()
	var nearby := false
	for actor in living:
		if _actor_position(actor).distance_to(target) <= 52.0:
			nearby = true
			break
	if not nearby:
		if str(stage_task["type"]) in ["repair", "rescue", "deliver_antidote"]:
			stage_task["progress"] = 0.0
		return
	if str(stage_task["type"]) == "supply" and int(stage_task["phase"]) == 0:
		stage_task["phase"] = 1
		toast_requested.emit("Supplies secured! Take them to the marked bunker drop point.")
		return
	if str(stage_task["type"]) in ["antidote", "supply"]:
		_finish_stage_task()
		return
	stage_task["progress"] = float(stage_task["progress"]) + delta
	if float(stage_task["progress"]) >= 1.5:
		_finish_stage_task()


func _finish_stage_task() -> void:
	var completed_label := _task_label()
	stage_task["complete"] = true
	stage_task["progress"] = 1.5
	if str(stage_task["type"]) == "antidote":
		stage_task["antidote_carry"] = true
	coins += 80
	points_earned += 40
	xp_earned += 25
	toast_requested.emit("TASK COMPLETE: %s · +80 Coins!" % completed_label)
	AudioManager.play_pickup()


func _task_blocks_next_wave() -> bool:
	return mode == "story" and waiting_for_next_wave and wave + 1 >= int(_stage_data.get("waves_count", 5)) and not bool(stage_task.get("complete", false))


func _can_skip_wave_preparation() -> bool:
	return is_host and waiting_for_next_wave and wave_prep_remaining > 0.0 and not match_ended and not is_paused and not shared_paused and not _task_blocks_next_wave()


func skip_wave_preparation() -> void:
	if not _can_skip_wave_preparation():
		return
	wave_prep_remaining = 0.0
	launch_next_wave()


func launch_next_wave() -> void:
	if not is_host or not waiting_for_next_wave or match_ended or wave_prep_remaining > 0.0 or _task_blocks_next_wave():
		return
	if mode == "endless" and portal_active:
		_enter_next_endless_portal()
	AudioManager.play_pickup()
	_begin_wave(wave + 1)
	toast_requested.emit("Wave %d deployed!" % wave)


func _process(delta: float) -> void:
	if match_ended or player.is_empty() or (is_paused and not is_online) or not visible:
		return
	_visual_time += delta

	if is_host and maya_phase not in ["cutscene", "finale"] and not shared_paused:
		elapsed_seconds += delta
		time_of_day_hour = fposmod(time_of_day_hour + delta * 0.08, 24.0)
		_update_combat_timers(player, delta)
		if waiting_for_next_wave:
			wave_prep_remaining = maxf(0.0, wave_prep_remaining - delta)
			if wave_prep_remaining <= 0.0:
				launch_next_wave()
	if not is_paused and not shared_paused and maya_phase not in ["cutscene", "finale"] and not bool(player["downed"]):
		_update_player_movement(delta)
		_update_player_aim_and_fire()
	if is_host and not shared_paused:
		_update_shared_world(delta)
	if is_online and not shared_paused:
		_step_remote_smoothing(delta)

	# Camera tracking + shake
	_shake_trauma = maxf(0.0, _shake_trauma - delta * 2.2)
	var shake_mag := _shake_trauma * _shake_trauma * 14.0 if bool(SaveManager.settings.get("screen_shake", true)) else 0.0
	var cam_off := Vector2(randf_range(-shake_mag, shake_mag), randf_range(-shake_mag, shake_mag))
	cam.position = Vector2(float(player["x"]), float(player["y"])) + cam_off

	# Periodic HUD & Online sync
	_hud_sync_timer += delta
	if _hud_sync_timer >= 0.08:
		_hud_sync_timer = 0.0
		if is_host:
			_reveal_squad_positions()
		_exploration.refresh_texture()
		_emit_hud_snapshot()

	if is_online:
		_net_sync_timer += delta
		if _net_sync_timer >= NET_INTERVAL:
			_net_sync_timer = 0.0
			if is_host:
				if not match_ended:
					_broadcast_world()
			else:
				_broadcast_local_state()

	queue_redraw()


func _reset_exploration() -> void:
	var map_size := Vector2(float(_stage_data["map_width"]), float(_stage_data["map_height"]))
	_exploration.reset(map_size, _stage_data.get("bunkers", []))
	_fog.texture = _exploration.texture
	_fog.scale = Vector2.ONE * ArenaExploration.CELL_SIZE
	if is_host:
		_reveal_squad_positions()
		_exploration.refresh_texture()


func _reveal_squad_positions() -> void:
	var barrier_x := _get_active_sector_barrier_x()
	var squad: Array[Dictionary] = [player]
	squad.append_array(remote_players.values())
	for actor in _living_players(squad):
		_exploration.reveal(_actor_position(actor), barrier_x)


func _visible_enemies() -> Array[Dictionary]:
	return enemies.filter(func(enemy: Dictionary) -> bool: return _exploration.can_see(_actor_position(enemy)))


func _init_remote_actor_smoothing(actor: Dictionary, x: float, y: float, angle: float) -> void:
	actor["render_x"] = x
	actor["render_y"] = y
	actor["render_angle"] = angle
	actor["target_x"] = x
	actor["target_y"] = y
	actor["target_angle"] = angle
	actor["net_vx"] = 0.0
	actor["net_vy"] = 0.0
	actor["extrap_time"] = 0.0
	actor["last_pkt_ms"] = Time.get_ticks_msec()


func _update_remote_actor_target(actor: Dictionary, x: float, y: float, angle: float, snap: bool = false) -> void:
	if not actor.has("render_x"):
		_init_remote_actor_smoothing(actor, x, y, angle)
		return
	var now_ms := Time.get_ticks_msec()
	var prev_ms := int(actor.get("last_pkt_ms", now_ms))
	var dt_pkt := clampf(float(now_ms - prev_ms) / 1000.0, 0.016, 0.25)
	var prev_tx := float(actor.get("target_x", x))
	var prev_ty := float(actor.get("target_y", y))
	var raw_vel := Vector2(x - prev_tx, y - prev_ty) / dt_pkt
	if raw_vel.length() > 280.0:
		raw_vel = raw_vel.normalized() * 280.0
	var cur_vel := Vector2(float(actor.get("net_vx", 0.0)), float(actor.get("net_vy", 0.0)))
	var blended_vel := Vector2.ZERO if snap else cur_vel.lerp(raw_vel, 0.65)
	actor["net_vx"] = blended_vel.x
	actor["net_vy"] = blended_vel.y
	actor["target_x"] = x
	actor["target_y"] = y
	actor["target_angle"] = angle
	actor["extrap_time"] = 0.0
	actor["last_pkt_ms"] = now_ms
	var render_pos := Vector2(float(actor["render_x"]), float(actor["render_y"]))
	if snap or render_pos.distance_to(Vector2(x, y)) > 240.0:
		actor["render_x"] = x
		actor["render_y"] = y
		actor["render_angle"] = angle


func _step_remote_smoothing(delta: float) -> void:
	var pos_blend := clampf(18.0 * delta, 0.0, 1.0)
	var rot_blend := clampf(22.0 * delta, 0.0, 1.0)
	for actor in remote_players.values():
		var base_tx := float(actor.get("target_x", actor["x"]))
		var base_ty := float(actor.get("target_y", actor["y"]))
		var extrap_elapsed := float(actor.get("extrap_time", 0.0))
		var extrap_dt := clampf(extrap_elapsed, 0.0, 0.09)
		actor["extrap_time"] = extrap_elapsed + delta
		var tx := base_tx + float(actor.get("net_vx", 0.0)) * extrap_dt
		var ty := base_ty + float(actor.get("net_vy", 0.0)) * extrap_dt
		var rx := float(actor.get("render_x", tx))
		var ry := float(actor.get("render_y", ty))
		var new_rx := lerpf(rx, tx, pos_blend)
		var new_ry := lerpf(ry, ty, pos_blend)
		actor["render_x"] = new_rx
		actor["render_y"] = new_ry
		actor["render_angle"] = lerp_angle(float(actor.get("render_angle", actor["angle"])), float(actor.get("target_angle", actor["angle"])), rot_blend)
		actor["visual_moving"] = Vector2(new_rx - rx, new_ry - ry).length() > 0.25

	if not is_host:
		for e in enemies:
			var eid = e.get("id")
			if _enemy_net_targets.has(eid):
				var target: Vector2 = _enemy_net_targets[eid]
				e["x"] = lerpf(float(e["x"]), target.x, pos_blend)
				e["y"] = lerpf(float(e["y"]), target.y, pos_blend)


func _update_combat_timers(actor: Dictionary, delta: float) -> void:
	var cooldowns: Dictionary = actor["skill_cooldowns"]
	for key in cooldowns:
		cooldowns[key] = maxf(0.0, float(cooldowns[key]) - delta)
	var was_reloading := float(actor["reload_timer"]) > 0.0
	for timer in ["reload_timer", "mg_timer", "invuln_timer", "fire_timer"]:
		actor[timer] = maxf(0.0, float(actor[timer]) - delta)
	if was_reloading and float(actor["reload_timer"]) <= 0.0:
		actor["ammo"] = int(actor["mag_size"])
		if is_same(actor, player):
			AudioManager.play_pickup()
	actor["mana"] = minf(float(actor["max_mana"]), float(actor["mana"]) + delta * 9.5)


func _update_shared_world(delta: float) -> void:
	if maya_phase in ["cutscene", "finale"]:
		return
	var actors: Array[Dictionary] = [player]
	for uid in remote_players:
		var actor: Dictionary = remote_players[uid]
		actors.append(actor)
		_update_combat_timers(actor, delta)
		var speed := _check_hazards(actor, delta)
		actor["move_credit"] = minf(float(actor["move_credit"]) + speed * delta, speed * MAX_MOVE_CREDIT_SECONDS)
		var wants_fire := bool(actor["input_firing"]) and Time.get_ticks_msec() - int(actor["last_input_ms"]) < 700
		if not bool(actor["downed"]) and (wants_fire or float(actor["mg_timer"]) > 0.0):
			_fire_weapon(actor)
	if not is_online and match_ended:
		return
	var living := _living_players(actors)
	if living.is_empty():
		_complete_match(false)
		return
	for actor in actors:
		if bool(actor["downed"]):
			_update_downed_state(actor, living, delta)

	_update_maya_tower(delta)
	_update_clones(delta)
	_update_builds(delta)
	if maya_phase == "finale":
		projectiles.clear()
		return
	_update_stage_task(delta, living)
	_update_corpse_collection(delta)
	_update_spawner(delta)
	if match_ended:
		return
	_update_enemies(delta, living)
	_update_projectiles(delta, living)
	_update_pickups(delta, living)
	_update_fx(delta)


func _actor_position(actor: Dictionary) -> Vector2:
	return Vector2(float(actor["x"]), float(actor["y"]))


func _actor_user_id(actor: Dictionary) -> String:
	if is_same(actor, player):
		return _local_user_id if not _local_user_id.is_empty() else "__host__"
	for uid in remote_players:
		if is_same(actor, remote_players[uid]):
			return str(uid)
	return ""


func _resolve_maya_finisher(last_hitter_id: String, target_pos: Vector2) -> Dictionary:
	var actors := {_actor_user_id(player): player}
	for uid in remote_players:
		actors[str(uid)] = remote_players[uid]
	var finisher_id := last_hitter_id
	if not actors.has(finisher_id):
		var nearest := INF
		for uid in actors:
			var distance := _actor_position(actors[uid]).distance_squared_to(target_pos)
			if distance < nearest:
				nearest = distance
				finisher_id = str(uid)
	var finisher: Dictionary = actors.get(finisher_id, player)
	var squad: Array = []
	for uid in actors:
		if uid != finisher_id:
			var actor: Dictionary = actors[uid]
			squad.append({"name": str(actor.get("username", "Ranger")), "class": str(actor.get("hero_class", "ranger"))})
	return {"user_id": finisher_id, "name": str(finisher.get("username", "Ranger")),
		"class": str(finisher.get("hero_class", "ranger")), "squad": squad}


func _living_players(actors: Array[Dictionary]) -> Array[Dictionary]:
	var living: Array[Dictionary] = []
	for actor in actors:
		if not bool(actor["downed"]):
			living.append(actor)
	return living


func _nearest_living_player(pos: Vector2, actors: Array[Dictionary]) -> Dictionary:
	var nearest: Dictionary = {}
	var best := INF
	for actor in actors:
		if bool(actor["downed"]):
			continue
		var distance := pos.distance_squared_to(_actor_position(actor))
		if distance < best:
			best = distance
			nearest = actor
	return nearest


func _nearest_visible_player_pos(pos: Vector2) -> Vector2:
	var best_pos := _actor_position(player)
	var best_dist := pos.distance_squared_to(best_pos)
	for actor in remote_players.values():
		if bool(actor.get("downed", false)):
			continue
		var rp := Vector2(float(actor.get("render_x", actor["x"])), float(actor.get("render_y", actor["y"])))
		var d := pos.distance_squared_to(rp)
		if d < best_dist:
			best_dist = d
			best_pos = rp
	return best_pos


func _update_player_movement(delta: float) -> void:
	var mv := Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		mv.x -= 1.0
	if Input.is_action_pressed("move_right"):
		mv.x += 1.0
	if Input.is_action_pressed("move_up"):
		mv.y -= 1.0
	if Input.is_action_pressed("move_down"):
		mv.y += 1.0

	if _hud_ref and _hud_ref.has_method("get_touch_move_vector"):
		var tmv: Vector2 = _hud_ref.get_touch_move_vector()
		if tmv.length() > 0.08:
			mv = tmv

	if mv.length() > 1.0:
		mv = mv.normalized()
	player["visual_moving"] = mv.length() > 0.08
	if bool(player["visual_moving"]):
		player["angle"] = mv.angle()

	var spd := _check_hazards(player, delta)

	var nx := float(player["x"]) + mv.x * spd * delta
	var ny := float(player["y"]) + mv.y * spd * delta
	_tut_move_dist += mv.length() * spd * delta
	if mode == "tutorial" and tutorial_step_idx == 0 and _tut_move_dist >= 140.0:
		tutorial_step_idx = 1

	var resolved := _resolve_world_collisions(nx, ny, float(player["radius"]), false)
	player["x"] = resolved.x
	player["y"] = resolved.y


func _check_hazards(actor: Dictionary, delta: float) -> float:
	var spd := float(actor["speed"])
	var hazard_damage := 0.0
	for obs in _stage_data.get("obstacles", []):
		if str(obs.get("kind", "")) == "hazard":
			var r := Rect2(float(obs["x"]), float(obs["y"]), float(obs["w"]), float(obs["h"]))
			if r.has_point(Vector2(float(actor["x"]), float(actor["y"]))):
				var htype := str(obs.get("hazard_type", ""))
				if htype == "mud" or htype == "mire":
					spd *= 0.65
				elif is_host:
					hazard_damage += delta * 12.0
	if is_online and hazard_damage > 0.0:
		var pending := float(actor["hazard_damage"]) + hazard_damage
		var whole_damage := floorf(pending)
		actor["hazard_damage"] = pending - whole_damage
		_apply_player_damage(actor, whole_damage)
	elif hazard_damage > 0.0:
		_apply_player_damage(actor, hazard_damage)

	return spd


func _update_player_aim_and_fire() -> void:
	var manual_mouse_fire := _mouse_fire_down and get_viewport().gui_get_hovered_control() == null
	var wants_fire := manual_mouse_fire or (_hud_ref != null and bool(_hud_ref.is_touch_firing()))
	var barrage_active := float(player["mg_timer"]) > 0.0
	if wants_fire or barrage_active:
		var target := GameRules.select_aim_target(float(player["x"]), float(player["y"]), aim_target_id, _visible_enemies(), 900.0)
		aim_target_id = target.get("id")
		if not target.is_empty():
			player["angle"] = (_actor_position(target) - _actor_position(player)).angle()
		elif manual_mouse_fire:
			player["angle"] = (get_global_mouse_position() - _actor_position(player)).angle()
	if not is_host:
		if wants_fire != _firing:
			_firing = wants_fire
			_broadcast_local_state()
		return
	if wants_fire or barrage_active:
		_fire_weapon(player)


func _fire_weapon(actor: Dictionary) -> void:
	if match_ended or bool(actor["downed"]) or float(actor["fire_timer"]) > 0.0:
		return
	if float(actor["mg_timer"]) > 0.0:
		actor["fire_timer"] = 0.09
		_spawn_projectile(float(actor["x"]), float(actor["y"]), float(actor["angle"]) + randf_range(-0.07, 0.07), 22, 920.0, 2, 0.0, Color("#F59E0B"), "player", _actor_user_id(actor))
		AudioManager.play_pistol_shot(140.0)
		actor["shot_count"] = int(actor["shot_count"]) + 1
		actor["last_shot"] = "machine_gun"
		return

	var w: Dictionary = actor["weapon"]
	var is_magic := str(w.get("category", "pistol")) == "magic"
	if is_magic:
		var m_cost := float(w.get("mana_cost", 8))
		if float(actor["mana"]) < m_cost:
			return
		actor["mana"] = float(actor["mana"]) - m_cost
		AudioManager.play_magic_cast()
	else:
		if float(actor["reload_timer"]) > 0.0:
			return
		if int(actor["ammo"]) <= 0:
			_start_reload(actor)
			return
		actor["ammo"] = int(actor["ammo"]) - 1
		AudioManager.play_pistol_shot()
		if int(actor["ammo"]) <= 0:
			_start_reload(actor)

	actor["fire_timer"] = 1.0 / maxf(0.5, float(w.get("fire_rate", 3.0)))
	actor["shot_count"] = int(actor["shot_count"]) + 1
	actor["last_shot"] = str(w.get("category", "pistol"))
	var count := int(w.get("projectiles_per_shot", 1))
	var spread := float(w.get("spread_rad", 0.03))
	var base_ang := float(actor["angle"])
	for i in range(count):
		var frac := 0.0 if count == 1 else (float(i) / float(count - 1) - 0.5) * 2.0
		var ang := base_ang + frac * spread + randf_range(-0.015, 0.015)
		var dmg := int(round(float(w.get("damage", 24)) * float(actor.get("damage_multiplier", 1.0))))
		if randf() < float(w.get("crit_chance", 0.1)):
			dmg = int(round(float(dmg) * 1.65))
		_spawn_projectile(
			float(actor["x"]) + cos(ang) * 18.0,
			float(actor["y"]) + sin(ang) * 18.0,
			ang,
			dmg,
			float(w.get("projectile_speed", 740.0)),
			int(w.get("penetration", 1)),
			float(w.get("aoe_radius", 0.0)),
			Color(str(w.get("color", "#F59E0B"))),
			"player", _actor_user_id(actor)
		)
	_tut_did_fire = true
	if mode == "tutorial" and tutorial_step_idx == 1:
		tutorial_step_idx = 2


func start_reload() -> void:
	if match_ended or shared_paused or player.is_empty():
		return
	if not is_host:
		_send_player_action("reload")
		return
	_start_reload(player)


func _start_reload(actor: Dictionary) -> void:
	if str(actor.get("hero_class", "ranger")) != "ranger":
		return
	if float(actor["reload_timer"]) > 0.0 or int(actor["ammo"]) >= int(actor["mag_size"]):
		return
	actor["reload_timer"] = float(actor["weapon"].get("reload_time", 1.1))
	AudioManager.play_reload()
	if mode == "tutorial" and tutorial_step_idx == 3:
		tutorial_step_idx = 4


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_mouse_fire_down = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_mouse_fire_down = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or match_ended or is_paused or shared_paused or player.is_empty() or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_mouse_fire_down = true
	elif not (event is InputEventScreenTouch and event.pressed and not event.canceled):
		return
	var click_world: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	var picked_id: Variant = null
	var best_sq := 46.0 * 46.0
	for e in _visible_enemies():
		var er := float(e["radius"]) + 14.0
		var d_sq := click_world.distance_squared_to(_actor_position(e))
		if d_sq <= maxf(best_sq, er * er):
			best_sq = d_sq
			picked_id = e["id"]
	if picked_id != null:
		aim_target_id = picked_id
		if mode == "tutorial" and tutorial_step_idx == 1:
			tutorial_step_idx = 2


func cycle_target() -> void:
	if shared_paused:
		return
	var targets := _visible_enemies()
	if targets.is_empty():
		aim_target_id = null
		return
	var idx := -1
	for i in range(targets.size()):
		if targets[i]["id"] == aim_target_id:
			idx = i
			break
	aim_target_id = targets[(idx + 1) % targets.size()]["id"]
	AudioManager.play_pickup()


func trigger_skill(skill_id: String, target_id: String = "") -> void:
	if match_ended or is_paused or shared_paused or bool(player["downed"]):
		return
	if not is_host:
		_send_player_action("skill", skill_id, target_id)
		return
	_use_skill(player, skill_id, target_id)


func _use_skill(actor: Dictionary, skill_id: String, target_id: String = "") -> void:
	var class_skills: Array = GameData.CLASS_SKILLS.get(str(actor["hero_class"]), [])
	if not class_skills.has(skill_id):
		return
	var revive_target: Dictionary = {}
	if skill_id == "medic_revive_ultimate":
		if not is_online or target_id.is_empty() or target_id == _actor_user_id(actor):
			_notify_actor(actor, "Select a downed teammate to revive.")
			return
		if target_id == _actor_user_id(player):
			revive_target = player
		else:
			revive_target = remote_players.get(target_id, {})
		if revive_target.is_empty() or not bool(revive_target.get("downed", false)):
			_notify_actor(actor, "That teammate is no longer downed.")
			return
	var cooldowns: Dictionary = actor["skill_cooldowns"]
	var charges: Dictionary = actor["skill_charges"]
	var levels: Dictionary = actor["skill_levels"]
	var is_tut := (mode == "tutorial")
	var cd := float(cooldowns.get(skill_id, 0.0))
	var chg := int(charges.get(skill_id, 0))
	var chk := GameRules.can_use_skill(skill_id, wave, cd, float(actor["mana"]), chg, is_tut)
	if not bool(chk["ok"]):
		_notify_actor(actor, str(chk["reason"]))
		return

	var def: Dictionary = GameData.SKILLS[skill_id]
	actor["skill_uses"] = int(actor["skill_uses"]) + 1
	cooldowns[skill_id] = float(def["cooldown"])
	actor["mana"] = maxf(0.0, float(actor["mana"]) - float(def["mana_cost"]))
	if not is_tut:
		charges[skill_id] = maxi(0, chg - 1)

	var mult := GameRules.get_skill_power_multiplier(int(levels.get(skill_id, 1)), portal_realm)
	var px := float(actor["x"])
	var py := float(actor["y"])
	var ang := float(actor["angle"])
	AudioManager.play_skill()
	_shake_trauma = minf(1.0, _shake_trauma + 0.35)
	_tut_did_skill = true
	if is_tut and tutorial_step_idx == 3:
		tutorial_step_idx = 4

	match skill_id:
		"grenade":
			var gx := px + cos(ang) * 165.0
			var gy := py + sin(ang) * 165.0
			_damage_enemies_in_radius(gx, gy, 145.0, int(round(135.0 * mult)), 0.0, _actor_user_id(actor))
			shockwaves.append({"x": gx, "y": gy, "r": 12.0, "max_r": 145.0, "color": Color("#F97316"), "life": 0.38})
		"machine_gun":
			actor["mg_timer"] = 4.5
		"tactical_clone":
			var owner_id := _local_user_id if is_same(actor, player) else ""
			if not is_same(actor, player):
				for uid in remote_players:
					if is_same(actor, remote_players[uid]):
						owner_id = str(uid)
						break
			for i in range(2):
				clones.append({
					"x": px + (-38.0 if i == 0 else 38.0),
					"y": py + 24.0,
					"life": 18.0,
					"fire_timer": 0.2,
					"damage": int(round(28.0 * mult)),
					"owner_id": owner_id, "side": -1.0 if i == 0 else 1.0,
				})
		"ranger_dash":
			actor["invuln_timer"] = 0.65
			var dash_p := _resolve_world_collisions(px + cos(ang) * 155.0, py + sin(ang) * 155.0, float(actor["radius"]), false)
			actor["x"] = dash_p.x
			actor["y"] = dash_p.y
			actor["warp_id"] = int(actor["warp_id"]) + 1
			shockwaves.append({"x": px, "y": py, "r": 10.0, "max_r": 55.0, "color": Color("#FBBF24"), "life": 0.25})
		"ranger_ultimate", "arcane_cataclysm":
			var dmg := int(round((185.0 if skill_id == "ranger_ultimate" else 220.0) * mult))
			_damage_enemies_in_radius(px, py, 320.0, dmg, 0.0, _actor_user_id(actor))
			for i in range(16):
				var sa := float(i) * (TAU / 16.0)
				_spawn_projectile(px, py, sa, int(round(58.0 * mult)), 840.0, 3, 28.0, Color(str(def["color"])), "player", _actor_user_id(actor))
			shockwaves.append({"x": px, "y": py, "r": 16.0, "max_r": 320.0, "color": Color(str(def["color"])), "life": 0.55})
		"arcane_nova":
			_damage_enemies_in_radius(px, py, 190.0, int(round(125.0 * mult)), 75.0, _actor_user_id(actor))
			shockwaves.append({"x": px, "y": py, "r": 14.0, "max_r": 190.0, "color": Color("#38BDF8"), "life": 0.42})
		"frost_ring":
			for i in range(enemies.size() - 1, -1, -1):
				var e := enemies[i]
				if Vector2(float(e["x"]) - px, float(e["y"]) - py).length() <= 215.0:
					e["slow_timer"] = 4.2
					_damage_enemy(e, int(round(62.0 * mult)), _actor_user_id(actor))
			shockwaves.append({"x": px, "y": py, "r": 14.0, "max_r": 215.0, "color": Color("#BAE6FD"), "life": 0.42})
		"healing_totem":
			actor["hp"] = minf(float(actor["max_hp"]), float(actor["hp"]) + 65.0 * mult)
			shockwaves.append({"x": px, "y": py, "r": 12.0, "max_r": 120.0, "color": Color("#22C55E"), "life": 0.45})
			_spawn_floating_text(px, py - 28.0, "+%d HP" % int(round(65.0 * mult)), Color("#22C55E"))
		"medic_revive_ultimate":
			_revive_actor(revive_target, 0.75)
			var target_pos := _actor_position(revive_target)
			shockwaves.append({"x": target_pos.x, "y": target_pos.y, "r": 12.0, "max_r": 120.0, "color": Color("#34D399"), "life": 0.55})
			_notify_actor(actor, "Revived %s!" % str(revive_target["username"]))
			_notify_actor(revive_target, "Revived by Medic %s!" % str(actor["username"]))


func buy_shop_item(item_id: String) -> String:
	if not is_host:
		_send_player_action("buy_item", item_id)
		return ""
	return _buy_shop_item(player, item_id)


func _buy_shop_item(actor: Dictionary, item_id: String) -> String:
	if not GameData.BUNKER_SHOP_ITEMS.has(item_id):
		return "Item not found"
	var found: Dictionary = GameData.BUNKER_SHOP_ITEMS[item_id]
	var chk := GameRules.validate_shop_purchase(coins, stage_id, found)
	if not bool(chk["ok"]):
		return str(chk["reason"])

	coins -= int(found["cost_coins"])
	if item_id in STOCKED_ITEMS:
		var inventory: Dictionary = actor["item_inventory"]
		inventory[item_id] = int(inventory.get(item_id, 0)) + 1
		_tut_did_shop = true
		if mode == "tutorial" and tutorial_step_idx == 2:
			tutorial_step_idx = 3
		AudioManager.play_pickup()
		_emit_hud_snapshot()
		return ""
	var px := float(actor["x"])
	var py := float(actor["y"])
	match item_id:
		"damage_boost":
			actor["damage_multiplier"] = float(actor.get("damage_multiplier", 1.0)) + 0.15
			_spawn_floating_text(px, py - 26.0, "+15% DMG!", Color("#F97316"))
		"armor_plate":
			actor["max_hp"] = float(actor["max_hp"]) + 35.0
			actor["hp"] = minf(float(actor["max_hp"]), float(actor["hp"]) + 35.0)
			_spawn_floating_text(px, py - 26.0, "+35 MAX HP!", Color("#10B981"))
		"mana_core":
			actor["max_mana"] = float(actor["max_mana"]) + 35.0
			actor["mana"] = float(actor["max_mana"])
			_spawn_floating_text(px, py - 26.0, "+35 MANA!", Color("#6366F1"))
	_tut_did_shop = true
	if mode == "tutorial" and tutorial_step_idx == 2:
		tutorial_step_idx = 3
	AudioManager.play_pickup()
	_emit_hud_snapshot()
	return ""


func use_inventory_item(item_id: String) -> String:
	if match_ended or is_paused or shared_paused or player.is_empty() or bool(player.get("downed", false)):
		return "Cannot use an item right now"
	if not is_host:
		_send_player_action("use_item", item_id)
		return ""
	return _use_inventory_item(player, item_id)


func _use_inventory_item(actor: Dictionary, item_id: String) -> String:
	if item_id not in STOCKED_ITEMS:
		return "Item not found"
	var inventory: Dictionary = actor.get("item_inventory", {})
	if int(inventory.get(item_id, 0)) <= 0:
		return "No item available"
	var px := float(actor["x"])
	var py := float(actor["y"])
	var ang := float(actor["angle"])
	match item_id:
		"ammo_medkit":
			actor["ammo"] = int(actor["mag_size"])
			actor["reload_timer"] = 0.0
			actor["hp"] = minf(float(actor["max_hp"]), float(actor["hp"]) + 45.0)
			actor["mana"] = minf(float(actor["max_mana"]), float(actor["mana"]) + 30.0)
		"build_wall":
			builds.append({"id": _uid(), "kind": "wall", "x": px + cos(ang) * 48.0, "y": py + sin(ang) * 48.0, "hp": 360.0, "max_hp": 360.0, "level": 1})
		"build_spike":
			builds.append({"id": _uid(), "kind": "spike_trap", "x": px + cos(ang) * 48.0, "y": py + sin(ang) * 48.0, "hp": 160.0, "max_hp": 160.0, "level": 1, "tick": 0.0, "owner_id": _actor_user_id(actor)})
		"build_turret":
			builds.append({"id": _uid(), "kind": "turret", "x": px + cos(ang) * 48.0, "y": py + sin(ang) * 48.0, "hp": 220.0, "max_hp": 220.0, "level": 1, "fire_timer": 0.0, "owner_id": _actor_user_id(actor)})
		"revive_kit":
			if not is_online or not _revive_online_teammate(actor):
				return "A downed teammate is required to use Squad Defib"
			actor["hp"] = minf(float(actor["max_hp"]), float(actor["hp"]) + 30.0)
	inventory[item_id] = int(inventory[item_id]) - 1
	AudioManager.play_pickup()
	_emit_hud_snapshot()
	return ""


func buy_skill_charge(skill_id: String) -> String:
	if not is_host:
		_send_player_action("buy_charge", skill_id)
		return ""
	return _buy_skill_charge(player, skill_id)


func _buy_skill_charge(actor: Dictionary, skill_id: String) -> String:
	var state: Dictionary = actor["skill_charges"]
	var cur := int(state.get(skill_id, 0))
	var buy_wave := wave + 1 if waiting_for_next_wave else wave
	var chk := GameRules.validate_buy_skill_charge(skill_id, buy_wave, coins, cur, mode == "tutorial")
	if not bool(chk["ok"]):
		return str(chk["reason"])
	coins -= int(GameData.SKILLS[skill_id]["charge_cost_coins"])
	state[skill_id] = cur + 1
	AudioManager.play_pickup()
	_emit_hud_snapshot()
	return ""


func upgrade_skill_rank(skill_id: String) -> String:
	if not is_host:
		_send_player_action("upgrade_skill", skill_id)
		return ""
	return _upgrade_skill_rank(player, skill_id)


func _upgrade_skill_rank(actor: Dictionary, skill_id: String) -> String:
	var state: Dictionary = actor["skill_levels"]
	var cur := int(state.get(skill_id, 1))
	var chk := GameRules.validate_upgrade_skill(skill_id, cur, coins)
	if not bool(chk["ok"]):
		return str(chk["reason"])
	coins -= int(chk["cost"])
	state[skill_id] = cur + 1
	AudioManager.play_skill()
	_emit_hud_snapshot()
	return ""


func upgrade_maya_tower() -> String:
	if maya_phase != "none":
		return "Maya's watchtower is no longer available"
	if not is_host:
		_send_player_action("upgrade_maya")
		return ""
	if maya_level >= GameRules.MAX_MAYA_TOWER_LEVEL:
		return "Maya Watchtower already Max Level"
	var cost := GameRules.get_maya_upgrade_cost(maya_level)
	if coins < cost:
		return "Need %d Coins" % cost
	coins -= cost
	maya_level += 1
	var ms := GameRules.get_maya_tower_stats(maya_level)
	maya_max_hp = float(ms["max_hp"])
	maya_hp = maya_max_hp
	AudioManager.play_victory()
	_emit_hud_snapshot()
	return ""


func get_shop_snapshot() -> Dictionary:
	return {
		"coins": coins,
		"stage_id": stage_id,
		"wave": wave + 1 if waiting_for_next_wave else wave,
		"is_tutorial": mode == "tutorial",
		"online": is_online,
		"hero_class": str(player.get("hero_class", "ranger")),
		"skill_charges": skill_charges.duplicate(),
		"skill_levels": skill_levels.duplicate(),
		"inventory": player.get("item_inventory", {}).duplicate(),
		"maya_level": maya_level,
		"maya_infected": maya_phase == "boss" or maya_phase == "done",
	}


func _update_maya_tower(delta: float) -> void:
	# ENFORCED RULE: Scout Maya stays stationed on her Watchtower and NEVER leaves to revive any teammates.
	if maya_phase != "none":
		return
	maya_fire_timer -= delta
	if maya_fire_timer > 0.0 or enemies.is_empty():
		return
	var bunker := _get_current_bunker()
	var m_pos := GameRules.get_maya_tower_coords(bunker, float(_stage_data["map_width"]), float(_stage_data["map_height"]))
	var ms := GameRules.get_maya_tower_stats(maya_level)
	var m_range := float(ms["range"])
	var best_e: Dictionary = {}
	var best_d := m_range * m_range
	for e in _visible_enemies():
		var d_sq := Vector2(float(e["x"]) - m_pos.x, float(e["y"]) - m_pos.y).length_squared()
		if d_sq < best_d:
			best_d = d_sq
			best_e = e
	if best_e.is_empty():
		return
	maya_fire_timer = float(ms["fire_interval"])
	var base_ang := atan2(float(best_e["y"]) - m_pos.y, float(best_e["x"]) - m_pos.x)
	var shots := int(ms["projectiles_per_shot"])
	for i in range(shots):
		var off := 0.0 if shots == 1 else (float(i) / float(shots - 1) - 0.5) * 0.16
		_spawn_projectile(m_pos.x, m_pos.y, base_ang + off, int(ms["damage"]), 860.0, 2, 0.0, Color("#FDE047"), "maya")


func _update_clones(delta: float) -> void:
	for i in range(clones.size() - 1, -1, -1):
		var c := clones[i]
		c["life"] = float(c["life"]) - delta
		if float(c["life"]) <= 0.0:
			clones.remove_at(i)
			continue
		var owner_id := str(c.get("owner_id", ""))
		var owner: Dictionary = player if owner_id == _local_user_id else remote_players.get(owner_id, {})
		if owner.is_empty():
			clones.remove_at(i)
			continue
		var offset := Vector2(24.0, float(c["side"]) * 38.0).rotated(float(owner["angle"]))
		var follow_pos := _resolve_world_collisions(float(owner["x"]) + offset.x, float(owner["y"]) + offset.y, 12.0, false)
		c["x"] = follow_pos.x
		c["y"] = follow_pos.y
		c["fire_timer"] = float(c["fire_timer"]) - delta
		if float(c["fire_timer"]) <= 0.0 and not enemies.is_empty():
			var near := GameRules.select_aim_target(float(c["x"]), float(c["y"]), null, _visible_enemies(), 480.0)
			if not near.is_empty():
				c["fire_timer"] = 0.28
				var ang := atan2(float(near["y"]) - float(c["y"]), float(near["x"]) - float(c["x"]))
				_spawn_projectile(float(c["x"]), float(c["y"]), ang, int(c["damage"]), 800.0, 1, 0.0, Color("#22C55E"), "player", owner_id)


func _update_builds(delta: float) -> void:
	for b in builds:
		if str(b["kind"]) == "turret":
			b["fire_timer"] = float(b["fire_timer"]) - delta
			if float(b["fire_timer"]) <= 0.0 and not enemies.is_empty():
				var near := GameRules.select_aim_target(float(b["x"]), float(b["y"]), null, _visible_enemies(), 420.0)
				if not near.is_empty():
					b["fire_timer"] = maxf(0.18, 0.48 - float(int(b["level"]) - 1) * 0.07)
					var ang := atan2(float(near["y"]) - float(b["y"]), float(near["x"]) - float(b["x"]))
					_spawn_projectile(float(b["x"]), float(b["y"]), ang, 18 + int(b["level"]) * 6, 780.0, 1, 0.0, Color("#38BDF8"), "player", str(b.get("owner_id", "")))
		elif str(b["kind"]) == "spike_trap":
			b["tick"] = float(b["tick"]) - delta
			if float(b["tick"]) <= 0.0:
				b["tick"] = 0.65
				for i in range(enemies.size() - 1, -1, -1):
					var e := enemies[i]
					if Vector2(float(e["x"]) - float(b["x"]), float(e["y"]) - float(b["y"])).length() <= 36.0:
						e["slow_timer"] = maxf(float(e.get("slow_timer", 0.0)), 1.6)
						_damage_enemy(e, 24, str(b.get("owner_id", "")))


func _update_spawner(delta: float) -> void:
	if maya_phase in ["cutscene", "finale"] or rolling_phase == "gathering":
		return
	if waiting_for_next_wave:
		return
	if not enemies_to_spawn.is_empty():
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = maxf(0.35, 1.15 - float(wave) * 0.04)
			var next_code := str(enemies_to_spawn.pop_front())
			_spawn_enemy_by_code(next_code)
	elif enemies.is_empty():
		if rolling_phase == "none" and ((mode == "story" and wave >= int(_stage_data.get("waves_count", 5))) or (mode == "endless" and GameRules.should_spawn_endless_portal(wave))):
			if not corpse_visuals.is_empty():
				return
			_begin_corpse_gathering()
			return
		if mode == "tutorial":
			_complete_match(true)
			return
		if mode == "story" and wave >= int(_stage_data.get("waves_count", 5)):
			_complete_match(true)
			return
		if mode == "endless" and GameRules.should_spawn_endless_portal(wave):
			portal_active = true
			toast_requested.emit("DIMENSIONAL PORTAL OPENED! Realm warp begins after 30 seconds of preparation.")
		elif mode == "story":
			var bunkers: Array = _stage_data.get("bunkers", [])
			if current_bunker_idx + 1 < bunkers.size():
				toast_requested.emit("Sector clear! Advance to %s. Wave %d starts in 30 seconds." % [str(bunkers[current_bunker_idx + 1]["name"]), wave + 1])
			else:
				toast_requested.emit("Wave %d cleared! Prepare for Wave %d in 30 seconds." % [wave, wave + 1])
		waiting_for_next_wave = true
		wave_prep_remaining = WAVE_PREP_SECONDS


func _random_collection_edge() -> Vector2:
	var mw := float(_stage_data.get("map_width", 2600.0))
	var mh := float(_stage_data.get("map_height", 1200.0))
	match randi() % 4:
		0: return Vector2(randf_range(0.0, mw), -35.0)
		1: return Vector2(randf_range(0.0, mw), mh + 35.0)
		2: return Vector2(-35.0, randf_range(0.0, mh))
		_: return Vector2(mw + 35.0, randf_range(0.0, mh))


func _nearest_collection_edge(pos: Vector2) -> Vector2:
	var mw := float(_stage_data.get("map_width", 2600.0))
	var mh := float(_stage_data.get("map_height", 1200.0))
	var margin := 56.0
	var distances := [pos.x, mw - pos.x, pos.y, mh - pos.y]
	var nearest := 0
	for side in range(1, 4):
		if distances[side] < distances[nearest]:
			nearest = side
	match nearest:
		0: return Vector2(-margin, clampf(pos.y, 0.0, mh))
		1: return Vector2(mw + margin, clampf(pos.y, 0.0, mh))
		2: return Vector2(clampf(pos.x, 0.0, mw), -margin)
		_: return Vector2(clampf(pos.x, 0.0, mw), mh + margin)


func _corpse_total_time(visual: Dictionary) -> float:
	var factor := 1.35 if bool(visual.get("boss", false)) else 1.0
	return (CORPSE_REST_SECONDS + float(visual.get("delay", 0.0)) + CORPSE_REACH_SECONDS + CORPSE_GRIP_SECONDS + CORPSE_DRAG_SECONDS) * factor


func _queue_corpse_collection(e: Dictionary) -> void:
	var edge := _nearest_collection_edge(Vector2(float(e["x"]), float(e["y"])))
	corpse_visuals.append({
		"sx": float(e["x"]), "sy": float(e["y"]), "ex": edge.x, "ey": edge.y,
		"t": 0.0, "color": str(e["color"]), "gathering": false,
		"boss": bool(e["is_boss"]), "kind": str(e.get("type", "basic")),
		"boss_id": str(e.get("boss_id", "")), "radius": float(e.get("radius", 17.0)),
		"delay": randf_range(0.1, 0.65),
	})


func _update_corpse_collection(delta: float) -> void:
	for i in range(corpse_visuals.size() - 1, -1, -1):
		var visual := corpse_visuals[i]
		if bool(visual["gathering"]):
			visual["t"] = minf(1.0, float(visual["t"]) + delta / 2.5)
		else:
			visual["t"] = float(visual["t"]) + delta
			if float(visual["t"]) >= _corpse_total_time(visual):
				corpse_count += 1
				corpse_visuals.remove_at(i)
	if rolling_phase == "gathering":
		gather_timer = maxf(0.0, gather_timer - delta)
		if gather_timer <= 0.0:
			corpse_visuals.clear()
			if _gather_with_maya:
				_begin_maya_transformation()
			else:
				rolling_phase = "boss"
				enemies_to_spawn.append("BOSS:human_tumbleweed")
				spawn_timer = 0.15
				toast_requested.emit("The collected dead have become the Human Tumbleweed!")
				if is_online:
					_broadcast_world()


func _begin_corpse_gathering() -> void:
	if rolling_phase != "none":
		return
	_gather_with_maya = (mode == "story" and stage_id == 5) or (mode == "endless" and wave == 10 and portal_realm == 1)
	gather_center = _last_final_boss_pos
	if gather_center == Vector2.ZERO:
		gather_center = _actor_position(player) + Vector2(130.0, 0.0)
	var pending_corpses := corpse_visuals.size()
	for _i in range(mini(30, corpse_count + pending_corpses)):
		var edge := _random_collection_edge()
		corpse_visuals.append({
			"sx": edge.x, "sy": edge.y, "ex": gather_center.x + randf_range(-38.0, 38.0),
			"ey": gather_center.y + randf_range(-38.0, 38.0), "t": 0.0,
			"color": "#83906B", "gathering": true, "boss": false,
			"kind": "basic", "boss_id": "", "radius": 17.0, "delay": 0.0,
		})
	rolling_phase = "gathering"
	if _gather_with_maya:
		maya_phase = "gathering"
	gather_timer = 3.5
	AudioManager.play_boss_telegraph()
	toast_requested.emit("The dead are being drawn together. Maya is approaching the fallen boss!" if _gather_with_maya else "Tentacles drag the fallen boss into the gathering dead!")
	if is_online:
		_broadcast_world()


func _begin_maya_transformation() -> void:
	maya_phase = "cutscene"
	_maya_story_ready.clear()
	projectiles.clear()
	toast_requested.emit("Maya's final stand... watch the story before the last battle.")
	maya_transformation_requested.emit()
	if is_online:
		_broadcast_world()


func continue_maya_transformation() -> void:
	if maya_phase != "cutscene":
		return
	if not is_host:
		_send_player_action("maya_story_ready")
		return
	_maya_story_ready[_local_user_id if _local_user_id != "" else "__host__"] = true
	_try_start_maya_boss()


func _try_start_maya_boss() -> void:
	if not is_host or maya_phase != "cutscene":
		return
	var required := remote_players.keys()
	if is_online:
		for entry in NetworkManager.current_room.get("players", []):
			var member_id := str(entry.get("userId", ""))
			if member_id != "" and member_id != _local_user_id and not required.has(member_id):
				required.append(member_id)
	for uid in required:
		if not _maya_story_ready.has(uid):
			return
	if not _maya_story_ready.has(_local_user_id if _local_user_id != "" else "__host__"):
		return
	maya_phase = "boss"
	rolling_phase = "boss"
	enemies_to_spawn.append("BOSS:human_tumbleweed")
	spawn_timer = 0.15
	toast_requested.emit("Maya and the fallen have fused into the Human Tumbleweed!")
	maya_boss_started.emit()
	if is_online:
		_broadcast_world()


func continue_maya_antidote_finale() -> void:
	if maya_phase != "finale":
		return
	if not is_host:
		_send_player_action("maya_finale_ready")
		return
	_maya_story_ready[_local_user_id if _local_user_id != "" else "__host__"] = true
	_try_finish_maya_finale()


func _try_finish_maya_finale() -> void:
	if not is_host or maya_phase != "finale":
		return
	var required := remote_players.keys()
	if is_online:
		for entry in NetworkManager.current_room.get("players", []):
			var member_id := str(entry.get("userId", ""))
			if member_id != "" and member_id != _local_user_id and not required.has(member_id):
				required.append(member_id)
	for uid in required:
		if not _maya_story_ready.has(uid):
			return
	if not _maya_story_ready.has(_local_user_id if _local_user_id != "" else "__host__"):
		return
	if mode == "endless":
		projectiles.clear()
		maya_phase = "done"
		portal_active = true
		waiting_for_next_wave = true
		wave_prep_remaining = WAVE_PREP_SECONDS
		maya_finale_completed.emit()
		if is_online:
			_broadcast_world()
	else:
		projectiles.clear()
		_complete_match(true)


func _stage_boss_spawn() -> Vector2:
	var mw := float(_stage_data.get("map_width", 2600.0))
	var mh := float(_stage_data.get("map_height", 1200.0))
	var bunker := _get_current_bunker()
	var bx := float(bunker["x"])
	var by := float(bunker["y"])
	var bnd := GameRules.get_bunker_bounds(bunker)
	var hw := float(bnd["half_w"])
	var hh := float(bnd["half_h"])

	var barrier_x := _get_active_sector_barrier_x()
	var max_spawn_x := mw - 80.0
	if barrier_x > 0.0:
		max_spawn_x = minf(max_spawn_x, barrier_x - 36.0)

	var side := randi() % 4
	var sx := bx
	var sy := by
	match side:
		0:
			sx = clampf(bx + hw + randf_range(90.0, 260.0), 80.0, max_spawn_x)
			sy = clampf(by + randf_range(-hh - 140.0, hh + 140.0), 90.0, mh - 90.0)
		1:
			sx = clampf(bx - hw - randf_range(110.0, 320.0), 80.0, max_spawn_x)
			sy = clampf(by + randf_range(-hh - 140.0, hh + 140.0), 90.0, mh - 90.0)
		2:
			sx = clampf(bx + randf_range(-hw - 120.0, hw + 120.0), 80.0, max_spawn_x)
			sy = clampf(by - hh - randf_range(100.0, 220.0), 90.0, mh - 90.0)
		_:
			sx = clampf(bx + randf_range(-hw - 120.0, hw + 120.0), 80.0, max_spawn_x)
			sy = clampf(by + hh + randf_range(100.0, 220.0), 90.0, mh - 90.0)
	return Vector2(sx, sy)


func _edge_spawn_position(radius: float) -> Vector2:
	var bunker := _get_current_bunker()
	var center := _actor_position(bunker)
	var half_height := float(GameRules.get_bunker_bounds(bunker)["half_h"])
	var map_width := float(_stage_data["map_width"])
	var map_height := float(_stage_data["map_height"])
	var north := _edge_spawn_index % 2 == 0
	_edge_spawn_index += 1
	var edge_buffer := radius + 24.0
	var spawn_y := edge_buffer if north else map_height - edge_buffer
	var arrival_y := center.y + (-1.0 if north else 1.0) * (half_height + 95.0)
	var min_x := ARENA_EDGE_INSET + radius + 12.0
	var max_x := map_width - min_x
	var barrier_x := _get_active_sector_barrier_x()
	if barrier_x > 0.0:
		max_x = minf(max_x, barrier_x - radius - 16.0)
	if mode == "story" and current_bunker_idx > 0:
		min_x = maxf(min_x, GameRules.get_sector_barrier_x(bunker) + radius + 16.0)
	var entrance_x := clampf(center.x, min_x, max_x)
	# Pick a clear lane through this sector's outer obstacles.
	for offset in [0.0, -110.0, 110.0, -220.0, 220.0, -330.0, 330.0]:
		var x := clampf(center.x + float(offset), min_x, max_x)
		var corridor := Rect2(x - radius, minf(spawn_y, arrival_y), radius * 2.0, absf(spawn_y - arrival_y))
		var blocked := false
		for obstacle in _terrain:
			if corridor.intersects(obstacle):
				blocked = true
				break
		if not blocked:
			entrance_x = x
			break
	return Vector2(entrance_x, spawn_y)


func _terrain_blockers(active_bunker: Dictionary) -> Array[Rect2]:
	var blockers: Array[Rect2] = []
	for obs in _stage_data["obstacles"]:
		if str(obs["kind"]) != "hazard":
			blockers.append(Rect2(float(obs["x"]), float(obs["y"]), float(obs["w"]), float(obs["h"])))
	for bunker in _stage_data["bunkers"]:
		if bunker["id"] == active_bunker["id"]:
			continue
		var bounds := GameRules.get_bunker_bounds(bunker)
		var half_size := Vector2(float(bounds["half_w"]), float(bounds["half_h"]))
		blockers.append(Rect2(_actor_position(bunker) - half_size, half_size * 2.0))
	return blockers


func _spawn_enemy_by_code(code: String) -> void:
	if code.begins_with("BOSS:"):
		var bid := code.substr(5)
		var bdef: Dictionary = GameData.BOSSES.get(bid, GameData.BOSSES["village_boss"])
		var b_hp := GameRules.calculate_wave_enemy_hp(float(bdef["base_hp"]), wave)
		var spawn := _stage_boss_spawn()
		if bid == "human_tumbleweed":
			b_hp += mini(corpse_count, 100) * 4
			spawn = gather_center
		enemies.append({
			"id": _uid(), "is_boss": true, "boss_id": bid, "type": "boss",
			"name": str(bdef["name"]), "x": spawn.x, "y": spawn.y,
			"hp": float(b_hp), "max_hp": float(b_hp),
			"speed": float(bdef["speed"]) * ENEMY_MOVE_SPEED_SCALE, "damage": maxi(1, int(round(float(GameRules.calculate_wave_enemy_damage(float(bdef["base_damage"]), wave)) * ENEMY_DAMAGE_SCALE * BOSS_DAMAGE_SCALE))),
			"radius": float(bdef["radius"]) + (minf(18.0, float(corpse_count) * 0.22) if bid == "human_tumbleweed" else 0.0), "color": str(bdef["color"]), "corpse_count": corpse_count,
			"passes_walls": false, "atk_cd": 0.0, "spec_cd": 3.2, "slow_timer": 0.0,
		})
		AudioManager.play_boss_telegraph()
		toast_requested.emit("BOSS INCOMING: %s!" % str(bdef["name"]))
		return

	var edef: Dictionary = GameData.ENEMIES.get(code, GameData.ENEMIES["basic"])
	var e_hp := GameRules.calculate_wave_enemy_hp(float(edef["base_hp"]), wave)
	var radius := float(edef["radius"])
	var spawn := _edge_spawn_position(radius)
	enemies.append({
		"id": _uid(), "is_boss": false, "boss_id": "", "type": code,
		"name": str(edef["name"]), "x": spawn.x, "y": spawn.y,
		"hp": float(e_hp), "max_hp": float(e_hp),
		"speed": float(edef["speed"]) * ENEMY_MOVE_SPEED_SCALE, "damage": maxi(1, int(round(float(GameRules.calculate_wave_enemy_damage(float(edef["base_damage"]), wave)) * ENEMY_DAMAGE_SCALE))),
		"radius": radius, "color": str(edef["color"]), "corpse_count": 0,
		"passes_walls": bool(edef.get("passes_walls", false)),
		"atk_cd": 0.0, "spec_cd": 2.4, "slow_timer": 0.0,
	})


func _update_enemies(delta: float, living: Array[Dictionary]) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e := enemies[i]
		e["atk_cd"] = maxf(0.0, float(e["atk_cd"]) - delta)
		e["slow_timer"] = maxf(0.0, float(e["slow_timer"]) - delta)
		var spd := float(e["speed"]) * (0.45 if float(e["slow_timer"]) > 0.0 else 1.0)
		var passes_walls := bool(e.get("passes_walls", false))

		var ex := float(e["x"])
		var ey := float(e["y"])
		var target := _nearest_living_player(Vector2(ex, ey), living)
		if target.is_empty():
			return
		var px := float(target["x"])
		var py := float(target["y"])
		var dir := Vector2(px - ex, py - ey)
		var dist := dir.length()
		var n_dir := dir.normalized() if dist > 0.001 else Vector2.ZERO

		if not passes_walls:
			var bunker := _get_current_bunker()
			var b_rect := GameRules.get_bunker_bounds(bunker)
			var p_in := GameRules.is_inside_safe_zone(px, py, bunker)
			var e_in := absf(ex - float(bunker["x"])) <= float(b_rect["half_w"]) and absf(ey - float(bunker["y"])) <= float(b_rect["half_h"])
			if p_in and not e_in:
				var doors := GameRules.get_bunker_doorway_points(bunker)
				var best_door := doors[0]
				var best_d := INF
				for dpt in doors:
					var dd := Vector2(dpt.x - ex, dpt.y - ey).length_squared()
					if dd < best_d:
						best_d = dd
						best_door = dpt
				if best_d > 38.0 * 38.0:
					n_dir = (best_door - Vector2(ex, ey)).normalized()

		var next_pos := _move_enemy_toward_player(e, Vector2(ex, ey), Vector2(px, py), n_dir, spd * delta, passes_walls)
		e["x"] = next_pos.x
		e["y"] = next_pos.y

		if str(e["type"]) == "elite" or bool(e["is_boss"]):
			e["spec_cd"] = float(e["spec_cd"]) - delta
			if float(e["spec_cd"]) <= 0.0 and dist < 560.0:
				var is_maya_boss := str(e["boss_id"]) in ["infected_maya", "human_tumbleweed"]
				e["spec_cd"] = 1.55 if is_maya_boss else (2.6 if bool(e["is_boss"]) else 3.2)
				var aim_a := atan2(py - float(e["y"]), px - float(e["x"]))
				var bolts := 5 if str(e["boss_id"]) == "city_boss" or str(e["boss_id"]) == "final_boss" else (3 if bool(e["is_boss"]) else 1)
				for bi in range(bolts):
					var spread := 0.17 if is_maya_boss else 0.45
					var off := 0.0 if bolts == 1 else (float(bi) / float(bolts - 1) - 0.5) * spread
					var muzzle := Vector2(float(e["x"]), float(e["y"])) + Vector2.RIGHT.rotated(aim_a) * (float(e["radius"]) + 8.0 if is_maya_boss else 0.0)
					_spawn_projectile(muzzle.x, muzzle.y, aim_a + off, int(e["damage"]) if not is_maya_boss else maxi(6, int(round(float(e["damage"]) * 0.45))), 760.0 if is_maya_boss else 420.0, 1, 0.0, Color("#D9F99D") if is_maya_boss else Color("#EF4444"), "enemy")
				if bool(e["is_boss"]) and not is_maya_boss and dist < 210.0:
					shockwaves.append({"x": float(e["x"]), "y": float(e["y"]), "r": 16.0, "max_r": 180.0, "color": Color("#EF4444"), "life": 0.4})
					for actor in living:
						if _actor_position(actor).distance_to(next_pos) <= 180.0:
							_apply_player_damage(actor, float(e["damage"]) * 0.9)

		if dist <= float(e["radius"]) + float(target["radius"]) + 6.0 and float(e["atk_cd"]) <= 0.0:
			e["atk_cd"] = 0.85
			_apply_player_damage(target, float(e["damage"]))

		for bi in range(builds.size() - 1, -1, -1):
			var b := builds[bi]
			if Vector2(float(b["x"]) - float(e["x"]), float(b["y"]) - float(e["y"])).length() <= float(e["radius"]) + 20.0:
				b["hp"] = float(b["hp"]) - float(e["damage"]) * delta * 1.4
				if float(b["hp"]) <= 0.0:
					builds.remove_at(bi)


func _move_enemy_toward_player(enemy: Dictionary, from: Vector2, target: Vector2, direction: Vector2, distance: float, passes_walls: bool) -> Vector2:
	var radius := float(enemy["radius"])
	var detour: Array = enemy.get("pursuit_detour", [])
	var requested := from + direction * distance
	if not detour.is_empty():
		var offset: Vector2 = detour[0] - from
		requested = from + offset.limit_length(distance)
		if offset.length() <= distance:
			detour.pop_front()
	var next := _resolve_world_collisions(requested.x, requested.y, radius, passes_walls)
	if not passes_walls and direction != Vector2.ZERO and detour.is_empty() and (next - from).dot(direction) < distance * 0.5:
		for blocker in _terrain:
			if blocker.grow(radius + 1.0).has_point(requested) and not blocker.has_point(target):
				enemy["pursuit_detour"] = _detour_around(blocker, radius, from, target)
				break
	return next


func _detour_around(blocker: Rect2, radius: float, from: Vector2, target: Vector2) -> Array[Vector2]:
	var clearance := blocker.grow(radius + 12.0)
	var corners := [clearance.position, Vector2(clearance.end.x, clearance.position.y), clearance.end, Vector2(clearance.position.x, clearance.end.y)]
	var sides := [absf(from.y - blocker.position.y), absf(from.x - blocker.end.x), absf(from.y - blocker.end.y), absf(from.x - blocker.position.x)]
	var side := sides.find(sides.min())
	var left: Array[Vector2] = [corners[side], corners[(side + 3) % 4]]
	var right: Array[Vector2] = [corners[(side + 1) % 4], corners[(side + 2) % 4]]
	var left_cost := from.distance_to(left[0]) + target.distance_to(left[1])
	var right_cost := from.distance_to(right[0]) + target.distance_to(right[1])
	return left if left_cost <= right_cost else right


func _update_projectiles(delta: float, living: Array[Dictionary]) -> void:
	var bunkers: Array = _stage_data.get("bunkers", [])
	var solid_rects: Array[Rect2] = []
	for bi in range(bunkers.size()):
		var b: Dictionary = bunkers[bi]
		if GameRules.is_bunker_locked(mode, bi, current_bunker_idx, _sector_open_after_prep()):
			var bnd := GameRules.get_bunker_bounds(b)
			solid_rects.append(Rect2(float(b["x"]) - float(bnd["half_w"]), float(b["y"]) - float(bnd["half_h"]), float(bnd["half_w"]) * 2.0, float(bnd["half_h"]) * 2.0))
		else:
			for wr in GameRules.get_bunker_wall_rects(b):
				solid_rects.append(wr)
	for obs in _stage_data.get("obstacles", []):
		if str(obs.get("kind", "")) != "hazard":
			solid_rects.append(Rect2(float(obs["x"]), float(obs["y"]), float(obs["w"]), float(obs["h"])))

	for i in range(projectiles.size() - 1, -1, -1):
		var pr := projectiles[i]
		pr["x"] = float(pr["x"]) + cos(float(pr["angle"])) * float(pr["speed"]) * delta
		pr["y"] = float(pr["y"]) + sin(float(pr["angle"])) * float(pr["speed"]) * delta
		pr["life"] = float(pr["life"]) - delta
		if float(pr["life"]) <= 0.0:
			projectiles.remove_at(i)
			continue

		var pos := Vector2(float(pr["x"]), float(pr["y"]))
		var hit_wall := false
		if str(pr["team"]) != "maya":
			for sr in solid_rects:
				if sr.has_point(pos):
					hit_wall = true
					break
		if not hit_wall and str(pr["team"]) == "enemy":
			for b_idx in range(builds.size() - 1, -1, -1):
				var bld := builds[b_idx]
				if str(bld.get("kind", "")) == "wall":
					var br := Rect2(float(bld["x"]) - 22.0, float(bld["y"]) - 10.0, 44.0, 20.0)
					if br.has_point(pos):
						bld["hp"] = float(bld["hp"]) - float(pr["damage"]) * 0.5
						if float(bld["hp"]) <= 0.0:
							builds.remove_at(b_idx)
						hit_wall = true
						break
		if hit_wall:
			projectiles.remove_at(i)
			continue

		if str(pr["team"]) == "enemy":
			var target := _nearest_living_player(pos, living)
			if not target.is_empty() and pos.distance_to(_actor_position(target)) <= float(target["radius"]) + 6.0:
				_apply_player_damage(target, float(pr["damage"]))
				projectiles.remove_at(i)
				continue
		else:
			var removed := false
			var targets := enemies.duplicate() if float(pr["aoe_radius"]) > 0.0 else enemies
			for ei in range(targets.size() - 1, -1, -1):
				var e: Dictionary = targets[ei]
				if float(e["hp"]) <= 0.0:
					continue
				var hit_list: Array = pr["hit_ids"]
				if hit_list.has(e["id"]):
					continue
				if pos.distance_to(Vector2(float(e["x"]), float(e["y"]))) <= float(e["radius"]) + 8.0:
					hit_list.append(e["id"])
					if float(pr["aoe_radius"]) > 0.0:
						_damage_enemies_in_radius(pos.x, pos.y, float(pr["aoe_radius"]), int(pr["damage"]), 0.0, str(pr.get("owner_id", "")))
						shockwaves.append({"x": pos.x, "y": pos.y, "r": 6.0, "max_r": float(pr["aoe_radius"]), "color": pr["color"], "life": 0.22})
					else:
						_damage_enemy(e, int(pr["damage"]), str(pr.get("owner_id", "")))
					if maya_phase == "finale":
						projectiles.clear()
						return
					pr["penetration"] = int(pr["penetration"]) - 1
					if int(pr["penetration"]) <= 0:
						projectiles.remove_at(i)
						removed = true
						break
			if removed:
				continue


func _damage_enemies_in_radius(cx: float, cy: float, radius: float, dmg: int, knockback: float = 0.0, owner_id: String = "") -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e := enemies[i]
		var d := Vector2(float(e["x"]) - cx, float(e["y"]) - cy)
		if d.length() <= radius + float(e["radius"]):
			if knockback > 0.0 and not bool(e["is_boss"]):
				var dir := d.normalized()
				e["x"] = float(e["x"]) + dir.x * knockback
				e["y"] = float(e["y"]) + dir.y * knockback
			_damage_enemy(e, dmg, owner_id)


func _damage_enemy(e: Dictionary, dmg: int, owner_id: String = "") -> void:
	if not owner_id.is_empty():
		e["last_hitter_id"] = owner_id
	e["hp"] = float(e["hp"]) - float(dmg)
	if bool(SaveManager.settings.get("show_damage_numbers", true)):
		_spawn_floating_text(float(e["x"]), float(e["y"]) - float(e["radius"]), str(dmg), Color("#FDE047"))
	AudioManager.play_enemy_hit()
	if float(e["hp"]) <= 0.0:
		var idx := enemies.find(e)
		if idx != -1:
			enemies.remove_at(idx)
		_on_enemy_killed(e)


func _on_enemy_killed(e: Dictionary) -> void:
	_queue_corpse_collection(e)
	if bool(e["is_boss"]):
		AudioManager.play_boss_death()
	else:
		AudioManager.play_zombie_death()
	kills += 1
	var ex := float(e["x"])
	var ey := float(e["y"])
	for _p in range(6):
		particles.append({"x": ex, "y": ey, "vx": randf_range(-110.0, 110.0), "vy": randf_range(-110.0, 110.0), "color": Color(str(e["color"])), "life": 0.45})

	var day_state := GameRules.get_day_night_state(time_of_day_hour)
	var is_night := bool(day_state["is_night"])
	if bool(e["is_boss"]):
		boss_defeats += 1
		if str(e["boss_id"]) != "human_tumbleweed":
			_last_final_boss_pos = Vector2(ex, ey)
		var br := GameRules.calculate_boss_rewards(str(e["boss_id"]))
		points_earned += int(br["points"])
		xp_earned += int(br["xp"])
		tokens_earned += int(br["tokens"])
		var b_coins := GameRules.calculate_boss_team_coins(str(e["boss_id"]), stage_id)
		coins += b_coins
		_spawn_floating_text(ex, ey - 20.0, "+%d Coins!" % b_coins, Color("#FBBF24"))
	else:
		var kr := GameRules.calculate_kill_rewards(str(e["type"]), is_night)
		points_earned += int(kr["points"])
		xp_earned += int(kr["xp"])
		var c_drop := maxi(1, int(round(float(GameRules.calculate_zombie_coins(str(e["type"]), stage_id, is_night)) * 0.35)))
		coins += c_drop
		_spawn_floating_text(ex, ey - 24.0, "+%dc" % c_drop, Color("#FBBF24"))
		pickups.append({"x": ex, "y": ey, "kind": "coin_fx", "life": 0.85, "fall_speed": -130.0})
		if randf() < 0.14:
			pickups.append({"x": ex + 12.0, "y": ey, "kind": "medkit", "value": 25, "life": 18.0})
	if str(e.get("boss_id", "")) == "human_tumbleweed":
		rolling_phase = "defeated"
		if _gather_with_maya:
			maya_finisher = _resolve_maya_finisher(str(e.get("last_hitter_id", "")), Vector2(ex, ey))
			maya_phase = "finale"
			_maya_story_ready.clear()
			maya_antidote_requested.emit(maya_finisher)
		else:
			toast_requested.emit("Human Tumbleweed destroyed! The sector is safe.")
		if is_online:
			_broadcast_world()


func _update_pickups(delta: float, living: Array[Dictionary]) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pk := pickups[i]
		pk["life"] = float(pk["life"]) - delta
		if float(pk["life"]) <= 0.0:
			pickups.remove_at(i)
			continue
		if str(pk["kind"]) == "coin_fx":
			pk["y"] = float(pk["y"]) + float(pk["fall_speed"]) * delta
			pk["fall_speed"] = float(pk["fall_speed"]) + 460.0 * delta
			continue
		var pos := Vector2(float(pk["x"]), float(pk["y"]))
		var target := _nearest_living_player(pos, living)
		if target.is_empty():
			continue
		var p_pos := _actor_position(target)
		var d := p_pos.distance_to(pos)
		if d < 110.0:
			var pull := (p_pos - Vector2(float(pk["x"]), float(pk["y"]))).normalized()
			pk["x"] = float(pk["x"]) + pull.x * 260.0 * delta
			pk["y"] = float(pk["y"]) + pull.y * 260.0 * delta
		if d <= 26.0:
			if str(pk["kind"]) == "medkit":
				target["hp"] = minf(float(target["max_hp"]), float(target["hp"]) + float(pk["value"]))
				_spawn_floating_text(p_pos.x, p_pos.y - 24.0, "+%d HP" % int(pk["value"]), Color("#22C55E"))
				AudioManager.play_pickup()
			pickups.remove_at(i)


func _update_fx(delta: float) -> void:
	for i in range(shockwaves.size() - 1, -1, -1):
		var sw := shockwaves[i]
		sw["life"] = float(sw["life"]) - delta
		sw["r"] = lerpf(float(sw["r"]), float(sw["max_r"]), delta * 12.0)
		if float(sw["life"]) <= 0.0:
			shockwaves.remove_at(i)
	for i in range(particles.size() - 1, -1, -1):
		var pt := particles[i]
		pt["x"] = float(pt["x"]) + float(pt["vx"]) * delta
		pt["y"] = float(pt["y"]) + float(pt["vy"]) * delta
		pt["life"] = float(pt["life"]) - delta
		if float(pt["life"]) <= 0.0:
			particles.remove_at(i)
	for i in range(floating_texts.size() - 1, -1, -1):
		var ft := floating_texts[i]
		ft["y"] = float(ft["y"]) - 32.0 * delta
		ft["life"] = float(ft["life"]) - delta
		if float(ft["life"]) <= 0.0:
			floating_texts.remove_at(i)


func _apply_player_damage(actor: Dictionary, amount: float) -> void:
	if float(actor["invuln_timer"]) > 0.0 or bool(actor["downed"]) or match_ended:
		return
	var dmg := int(round(amount))
	if dmg <= 0:
		return
	damage_taken += dmg
	actor["hp"] = maxf(0.0, float(actor["hp"]) - float(dmg))
	actor["invuln_timer"] = 0.45
	if is_same(actor, player):
		AudioManager.play_player_hurt()
		_shake_trauma = minf(1.0, _shake_trauma + 0.25)

	if mode == "tutorial" and float(actor["hp"]) < 15.0:
		actor["hp"] = 15.0
		return

	if float(actor["hp"]) <= 0.0:
		if not is_online:
			_complete_match(false)
			return
		actor["downed"] = true
		actor["input_firing"] = false
		_notify_actor(actor, "Downed! Teammates can revive you or use the Revive Station.")


func _update_downed_state(actor: Dictionary, living: Array[Dictionary], delta: float) -> void:
	var station := GameRules.get_revive_station_coords(_get_current_bunker())
	var station_pos := Vector2(float(station["x"]), float(station["y"]))
	for teammate in living:
		var pos := _actor_position(teammate)
		if pos.distance_to(_actor_position(actor)) <= 60.0 or pos.distance_to(station_pos) <= 68.0:
			actor["revive_progress"] = float(actor["revive_progress"]) + delta
			if float(actor["revive_progress"]) >= 1.8:
				_revive_actor(actor, 0.6)
				_notify_actor(actor, "%s revived you!" % str(teammate["username"]))
			return
	actor["revive_progress"] = 0.0


func _revive_actor(actor: Dictionary, portion: float) -> void:
	actor["downed"] = false
	actor["hp"] = float(actor["max_hp"]) * portion
	actor["revive_progress"] = 0.0
	actor["invuln_timer"] = 0.65
	if is_same(actor, player):
		AudioManager.play_victory()


func _revive_online_teammate(actor: Dictionary) -> bool:
	var nearest: Dictionary = {}
	var best := INF
	var squad: Array = remote_players.values()
	squad.append(player)
	for teammate in squad:
		if is_same(teammate, actor) or not bool(teammate["downed"]):
			continue
		var distance := _actor_position(actor).distance_squared_to(_actor_position(teammate))
		if distance < best:
			best = distance
			nearest = teammate
	if nearest.is_empty():
		return false
	_revive_actor(nearest, 0.65)
	_notify_actor(actor, "Revived teammate %s!" % str(nearest["username"]))
	_notify_actor(nearest, "Revived by squadmate!")
	return true


func _enter_next_endless_portal() -> void:
	portal_active = false
	rolling_phase = "none"
	_gather_with_maya = false
	portal_realm += 1
	_stage_data = GameData.get_stage_by_id(99, portal_realm)
	builds.clear()
	var bunker := _get_current_bunker()
	var squad: Array = remote_players.values()
	squad.append(player)
	for actor in squad:
		actor["x"] = float(bunker["x"])
		actor["y"] = float(bunker["y"])
		actor["warp_id"] = int(actor["warp_id"]) + 1
		if not is_same(actor, player):
			_init_remote_actor_smoothing(actor, float(bunker["x"]), float(bunker["y"]), float(actor["angle"]))
	_reset_exploration()
	AudioManager.play_victory()
	toast_requested.emit("PORTAL WARP -> Realm %d (%s)! Skills surged +35%%!" % [portal_realm, str(_stage_data.get("name", ""))])


func _complete_match(victory: bool) -> void:
	if match_ended or not is_host:
		return
	match_ended = true
	AudioManager.stop_combat_music()
	if victory:
		AudioManager.play_victory()
	else:
		AudioManager.play_defeat()
	var stars := GameRules.calculate_stage_stars(victory, mode, stage_id, int(round(elapsed_seconds)), damage_taken)
	var summary := {
		"victory": victory,
		"mode": mode,
		"stage_id": stage_id,
		"wave_reached": wave,
		"kills": kills,
		"boss_defeats": boss_defeats,
		"points_earned": points_earned + (120 if victory else 25),
		"xp_earned": xp_earned + (80 if victory else 20),
		"tokens_earned": tokens_earned + (1 if victory and mode == "story" else 0),
		"elapsed_seconds": int(round(elapsed_seconds)),
		"damage_taken": damage_taken,
		"stars_earned": stars,
		"online": is_online,
		"task_completed": bool(stage_task.get("complete", false)),
		"task_type": str(stage_task.get("type", "")),
	}
	if is_online:
		_broadcast_world(summary)
	match_finished.emit(summary)


func _spawn_projectile(x: float, y: float, angle: float, damage: int, speed: float, pen: int, aoe: float, col: Color, team: String, owner_id: String = "") -> void:
	projectiles.append({
		"x": x, "y": y, "angle": angle, "damage": damage, "speed": speed,
		"penetration": pen, "aoe_radius": aoe, "color": col, "team": team, "owner_id": owner_id,
		"life": 1.35, "hit_ids": [],
	})


func _spawn_floating_text(x: float, y: float, txt: String, col: Color) -> void:
	floating_texts.append({"x": x, "y": y, "text": txt, "color": col, "life": 0.85})


func _get_current_bunker() -> Dictionary:
	var bunkers: Array = _stage_data.get("bunkers", [])
	if bunkers.is_empty():
		return {"x": 450.0, "y": 540.0, "radius": 180.0, "name": "Bunker 1"}
	return bunkers[clampi(current_bunker_idx, 0, bunkers.size() - 1)]


func _get_active_sector_barrier_x() -> float:
	if mode != "story" or _sector_open_after_prep():
		return -1.0
	var bunkers: Array = _stage_data.get("bunkers", [])
	if current_bunker_idx + 1 < bunkers.size():
		return GameRules.get_sector_barrier_x(bunkers[current_bunker_idx + 1])
	return -1.0


func _sector_open_after_prep() -> bool:
	return mode == "story" and waiting_for_next_wave and wave_prep_remaining <= 0.0


func _task_guide_active() -> bool:
	if mode != "story" or stage_task.is_empty() or bool(stage_task.get("complete", false)) or int(stage_task.get("phase", 0)) < 0:
		return false
	var idx := int(stage_task.get("bunker_idx", -1))
	var bunkers: Array = _stage_data.get("bunkers", [])
	if idx < 0 or idx >= bunkers.size() or current_bunker_idx != idx or wave != idx + 1 or player.is_empty():
		return false
	var x := float(player["x"])
	if idx > 0 and x < GameRules.get_sector_barrier_x(bunkers[idx]):
		return false
	return idx + 1 >= bunkers.size() or x < GameRules.get_sector_barrier_x(bunkers[idx + 1])


func _resolve_world_collisions(x: float, y: float, radius: float, passes_walls: bool) -> Vector2:
	var mw := float(_stage_data.get("map_width", 2600.0))
	var mh := float(_stage_data.get("map_height", 1200.0))
	var cx := clampf(x, radius + 16.0, mw - radius - 16.0)
	var cy := clampf(y, radius + 16.0, mh - radius - 16.0)

	if not passes_walls:
		var barrier_x := _get_active_sector_barrier_x()
		if barrier_x > 0.0 and cx + radius > barrier_x:
			cx = barrier_x - radius

		for obs in _stage_data.get("obstacles", []):
			if str(obs.get("kind", "")) == "hazard":
				continue
			var r := Rect2(float(obs["x"]), float(obs["y"]), float(obs["w"]), float(obs["h"]))
			var res := GameRules.resolve_circle_rect_collision(cx, cy, radius, r)
			cx = float(res["x"])
			cy = float(res["y"])

		for bld in builds:
			if str(bld.get("kind", "")) == "wall":
				var br := Rect2(float(bld["x"]) - 22.0, float(bld["y"]) - 10.0, 44.0, 20.0)
				var bres := GameRules.resolve_circle_rect_collision(cx, cy, radius, br)
				cx = float(bres["x"])
				cy = float(bres["y"])

		var bunkers: Array = _stage_data.get("bunkers", [])
		for bi in range(bunkers.size()):
			var b: Dictionary = bunkers[bi]
			if GameRules.is_bunker_locked(mode, bi, current_bunker_idx, _sector_open_after_prep()):
				var bnd := GameRules.get_bunker_bounds(b)
				var full_r := Rect2(float(b["x"]) - float(bnd["half_w"]), float(b["y"]) - float(bnd["half_h"]), float(bnd["half_w"]) * 2.0, float(bnd["half_h"]) * 2.0)
				var res := GameRules.resolve_circle_rect_collision(cx, cy, radius, full_r)
				cx = float(res["x"])
				cy = float(res["y"])
			else:
				for wr in GameRules.get_bunker_wall_rects(b):
					var res := GameRules.resolve_circle_rect_collision(cx, cy, radius, wr)
					cx = float(res["x"])
					cy = float(res["y"])
	return Vector2(cx, cy)


func _broadcast_local_state() -> void:
	if is_host:
		return
	_input_sequence += 1
	_pending_input_positions[_input_sequence] = _actor_position(player)
	if _pending_input_positions.size() > MAX_PENDING_INPUTS:
		_pending_input_positions.erase(_pending_input_positions.keys()[0])
	NetworkManager.send_match_op(PLAYER_STATE_OP, {
		"x": float(player["x"]), "y": float(player["y"]), "angle": float(player["angle"]),
		"hero_class": str(player["hero_class"]), "gender": str(player["gender"]),
		"weapon_id": str(player["weapon_id"]), "weapon_level": int(player["weapon_level"]),
		"warp_id": int(player["warp_id"]), "realm": portal_realm, "firing": _firing, "input_seq": _input_sequence,
	})


func _send_player_action(action: String, arg: String = "", target_id: String = "") -> void:
	if match_ended or _world_sequence <= 0:
		return
	_broadcast_local_state()
	NetworkManager.send_match_op(PLAYER_ACTION_OP, {
		"action": action, "arg": arg, "target_id": target_id, "realm": portal_realm,
		"warp_id": int(player["warp_id"]), "input_seq": _input_sequence,
	})


func _on_net_room_updated(room: Dictionary) -> void:
	if not is_online or match_ended:
		return
	var roster: Array = room.get("players", [])
	var retained := {}
	for entry in roster:
		retained[str(entry.get("userId", ""))] = true
	for uid in remote_players.keys():
		if not retained.has(uid):
			remote_players.erase(uid)
	if is_host and shared_paused and shared_pause_owner_id != "" and not retained.has(shared_pause_owner_id):
		_set_shared_pause(false, "")
	_try_start_maya_boss()
	_try_finish_maya_finale()


func _on_net_match_data(op_code: int, sender_id: String, payload: Dictionary) -> void:
	if not is_online or match_ended or not visible or sender_id == "" or sender_id == _local_user_id:
		return
	if is_host:
		match op_code:
			PLAYER_STATE_OP:
				_receive_player_state(sender_id, payload)
			PLAYER_ACTION_OP:
				_receive_player_action(sender_id, payload)
	elif op_code == WORLD_STATE_OP and sender_id == _host_user_id:
		_apply_world_snapshot(payload)


func _receive_player_state(sender_id: String, payload: Dictionary) -> void:
	if int(payload.get("realm", 0)) != portal_realm:
		return
	var input_seq := int(payload.get("input_seq", 0))
	if input_seq <= 0:
		return
	var actor: Dictionary = remote_players.get(sender_id, {})
	if actor.is_empty():
		var username := ""
		for entry in NetworkManager.current_room.get("players", []):
			if str(entry.get("userId", "")) == sender_id:
				username = str(entry.get("username", "Ally"))
				break
		if username.is_empty():
			return
		var h_class := "medic" if str(payload.get("hero_class", "")) in ["medic", "mage"] else "ranger"
		var gender := "female" if str(payload.get("gender", "")) == "female" else "male"
		var wid := str(payload.get("weapon_id", ""))
		var expected_category := "magic" if h_class == "medic" else "pistol"
		var w_def: Dictionary = GameData.WEAPONS.get(wid, {})
		if str(w_def.get("category", "")) != expected_category:
			wid = "basic_wand" if h_class == "medic" else "basic_pistol"
		var bunker := _get_current_bunker()
		var spawn_pos := Vector2(float(bunker["x"]), float(bunker["y"])) + _guest_spawn_offset(sender_id)
		var resolved := _resolve_world_collisions(spawn_pos.x, spawn_pos.y, 16.0, false)
		actor = _create_player(resolved.x, resolved.y, h_class, gender, username, wid, int(payload.get("weapon_level", 0)))
		_init_remote_actor_smoothing(actor, resolved.x, resolved.y, float(actor["angle"]))
		remote_players[sender_id] = actor
	if maya_phase in ["cutscene", "finale"] or shared_paused:
		actor["input_firing"] = false
		if int(payload.get("warp_id", -1)) == int(actor["warp_id"]):
			actor["input_sequence"] = maxi(int(actor["input_sequence"]), input_seq)
		return
	if int(payload.get("warp_id", -1)) != int(actor["warp_id"]) or input_seq <= int(actor["input_sequence"]):
		return
	actor["input_sequence"] = input_seq
	if bool(actor["downed"]):
		return
	var x := float(payload.get("x", actor["x"]))
	var y := float(payload.get("y", actor["y"]))
	var angle := float(payload.get("angle", actor["angle"]))
	if not is_finite(x) or not is_finite(y) or not is_finite(angle):
		return
	var map_width := float(_stage_data.get("map_width", 2600.0))
	var map_height := float(_stage_data.get("map_height", 1200.0))
	var position := _resolve_guest_movement(actor, Vector2(clampf(x, 0.0, map_width), clampf(y, 0.0, map_height)))
	actor["x"] = position.x
	actor["y"] = position.y
	actor["angle"] = angle
	_update_remote_actor_target(actor, position.x, position.y, angle, false)
	var firing := bool(payload.get("firing", false))
	var just_pressed := firing and not bool(actor["input_firing"])
	actor["input_firing"] = firing
	actor["last_input_ms"] = Time.get_ticks_msec()
	if just_pressed:
		_fire_weapon(actor)


func _resolve_guest_movement(actor: Dictionary, requested: Vector2) -> Vector2:
	var pos := _actor_position(actor)
	var offset := (requested - pos).limit_length(float(actor["move_credit"]))
	var distance := offset.length()
	var steps := ceili(distance / 5.0)
	if steps == 0:
		return pos
	actor["move_credit"] = maxf(0.0, float(actor["move_credit"]) - distance)
	var step := offset / float(steps)
	for i in range(steps):
		var next := pos + step
		pos = _resolve_world_collisions(next.x, next.y, float(actor["radius"]), false)
	return pos


func _receive_player_action(sender_id: String, payload: Dictionary) -> void:
	var action := str(payload.get("action", ""))
	if maya_phase == "finale" and action == "maya_finale_ready":
		var member_in_room := false
		for entry in NetworkManager.current_room.get("players", []):
			if str(entry.get("userId", "")) == sender_id:
				member_in_room = true
				break
		if (remote_players.has(sender_id) or member_in_room) and int(payload.get("realm", 0)) == portal_realm:
			_maya_story_ready[sender_id] = true
			_try_finish_maya_finale()
		return
	if action in ["team_pause", "team_resume"]:
		if maya_phase in ["cutscene", "finale"] or int(payload.get("realm", 0)) != portal_realm:
			return
		var member_in_room := false
		for entry in NetworkManager.current_room.get("players", []):
			if str(entry.get("userId", "")) == sender_id:
				member_in_room = true
				break
		if not member_in_room:
			return
		if action == "team_resume":
			if shared_paused:
				_set_shared_pause(false, "")
		else:
			var reason := _host_request_team_pause(sender_id)
			if not reason.is_empty() and remote_players.has(sender_id):
				_notify_actor(remote_players[sender_id], reason)
		return
	if maya_phase == "cutscene" and str(payload.get("action", "")) == "maya_story_ready":
		var member_in_room := false
		for entry in NetworkManager.current_room.get("players", []):
			if str(entry.get("userId", "")) == sender_id:
				member_in_room = true
				break
		if (remote_players.has(sender_id) or member_in_room) and int(payload.get("realm", 0)) == portal_realm:
			_maya_story_ready[sender_id] = true
			_try_start_maya_boss()
		return
	if maya_phase in ["cutscene", "finale"] or shared_paused:
		return
	var actor: Dictionary = remote_players.get(sender_id, {})
	if actor.is_empty() or bool(actor["downed"]) or int(payload.get("realm", 0)) != portal_realm:
		return
	if int(payload.get("warp_id", -1)) != int(actor["warp_id"]) or int(payload.get("input_seq", -1)) != int(actor["input_sequence"]):
		return
	var arg := str(payload.get("arg", ""))
	if action in ["skill", "buy_charge", "upgrade_skill"]:
		var class_skills: Array = GameData.CLASS_SKILLS.get(str(actor["hero_class"]), [])
		if not class_skills.has(arg):
			_notify_actor(actor, "This skill is unavailable for your class")
			return
	var message := ""
	match action:
		"reload":
			_start_reload(actor)
		"skill":
			_use_skill(actor, arg, str(payload.get("target_id", "")))
		"buy_item":
			message = _buy_shop_item(actor, arg)
		"use_item":
			message = _use_inventory_item(actor, arg)
		"buy_charge":
			message = _buy_skill_charge(actor, arg)
		"upgrade_skill":
			message = _upgrade_skill_rank(actor, arg)
		"upgrade_maya":
			message = upgrade_maya_tower()
	if not message.is_empty():
		_notify_actor(actor, message)


func _notify_actor(actor: Dictionary, message: String) -> void:
	if is_same(actor, player):
		toast_requested.emit(message)
	else:
		actor["notice"] = message


func _encode_entities(entities: Array[Dictionary], fields: Array, limit: int = -1) -> Array:
	var encoded: Array = []
	var start := maxi(0, entities.size() - limit) if limit >= 0 else 0
	for i in range(start, entities.size()):
		var row: Array = []
		for key in fields:
			var value: Variant = entities[i][key]
			match typeof(value):
				TYPE_COLOR:
					row.append("#" + value.to_html())
				TYPE_FLOAT:
					row.append(snappedf(value, 0.1))
				_:
					row.append(value)
		encoded.append(row)
	return encoded


func _decode_entities(rows: Array, fields: Array, color_is_native: bool = false) -> Array[Dictionary]:
	var decoded: Array[Dictionary] = []
	for row in rows:
		if not row is Array or row.size() != fields.size():
			continue
		var entity := {}
		for i in range(fields.size()):
			var key: String = fields[i]
			entity[key] = Color(str(row[i])) if key == "color" and color_is_native else row[i]
		decoded.append(entity)
	return decoded


func _encode_actor(actor: Dictionary) -> Dictionary:
	var state := {}
	for key in ["x", "y", "angle", "hp", "max_hp", "mana", "max_mana", "ammo", "mag_size",
			"hero_class", "gender", "username", "weapon_id", "downed", "warp_id", "reload_timer", "visual_moving",
			"skill_cooldowns", "skill_charges", "skill_levels", "item_inventory", "shot_count", "last_shot", "skill_uses", "input_sequence"]:
		state[key] = actor[key]
	if actor.has("notice"):
		state["notice"] = actor["notice"]
		actor.erase("notice")
	return state


func _broadcast_world(summary: Dictionary = {}) -> void:
	_world_sequence += 1
	NetworkManager.send_match_op(WORLD_STATE_OP, _create_world_snapshot(summary))


func _create_world_snapshot(summary: Dictionary = {}) -> Dictionary:
	var squad := {_local_user_id: _encode_actor(player)}
	for uid in remote_players:
		squad[uid] = _encode_actor(remote_players[uid])
	var pause_remaining := {}
	var now := Time.get_ticks_msec()
	for uid in _pause_ready_at_ms:
		var seconds := maxi(0, ceili(float(int(_pause_ready_at_ms[uid]) - now) / 1000.0))
		if seconds > 0:
			pause_remaining[uid] = seconds
	return {
		"seq": _world_sequence, "players": squad,
		"explored": _exploration.encode(),
		"team_paused": shared_paused, "pause_owner": shared_pause_owner_id,
		"pause_owner_name": shared_pause_owner_name,
		"pause_remaining": pause_remaining,
		"stage_task": stage_task.duplicate(),
		"maya_phase": maya_phase, "maya_finisher": maya_finisher.duplicate(true),
		"rolling_phase": rolling_phase, "gather_with_maya": _gather_with_maya,
		"corpse_count": corpse_count, "gather_timer": gather_timer,
		"gather_x": gather_center.x, "gather_y": gather_center.y,
		"corpse_visuals": _encode_entities(corpse_visuals, ENTITY_FIELDS["corpse_visuals"]),
		"realm": portal_realm, "bunker": current_bunker_idx, "portal": portal_active,
		"wave": wave, "waiting": waiting_for_next_wave, "prep_remaining": wave_prep_remaining, "pending": enemies_to_spawn.size(),
		"elapsed": elapsed_seconds, "hour": time_of_day_hour,
		"coins": coins, "points": points_earned, "xp": xp_earned,
		"tokens": tokens_earned, "kills": kills, "boss_defeats": boss_defeats,
		"maya_level": maya_level, "maya_hp": maya_hp, "maya_max_hp": maya_max_hp,
		"enemies": _encode_entities(enemies, ENTITY_FIELDS["enemies"]),
		"projectiles": _encode_entities(projectiles, ENTITY_FIELDS["projectiles"]),
		"pickups": _encode_entities(pickups, ENTITY_FIELDS["pickups"]),
		"builds": _encode_entities(builds, ENTITY_FIELDS["builds"]),
		"clones": _encode_entities(clones, ENTITY_FIELDS["clones"]),
		"shockwaves": _encode_entities(shockwaves, ENTITY_FIELDS["shockwaves"], 24),
		"particles": _encode_entities(particles, ENTITY_FIELDS["particles"], 32),
		"floating_texts": _encode_entities(floating_texts, ENTITY_FIELDS["floating_texts"], 24),
		"summary": summary,
	}


func _apply_world_snapshot(state: Dictionary) -> void:
	var sequence := int(state.get("seq", 0))
	if sequence <= _world_sequence:
		return
	_world_sequence = sequence
	var was_team_paused := shared_paused
	shared_paused = bool(state.get("team_paused", false))
	shared_pause_owner_id = str(state.get("pause_owner", "")) if shared_paused else ""
	shared_pause_owner_name = str(state.get("pause_owner_name", "Squadmate")) if shared_paused else ""
	_guest_pause_remaining = int(state.get("pause_remaining", {}).get(_local_user_id, 0))
	if shared_paused:
		_firing = false
	var realm := int(state.get("realm", 1))
	if portal_realm != realm:
		portal_realm = realm
		_stage_data = GameData.get_stage_by_id(99, realm)
		_reset_exploration()
		toast_requested.emit("Portal warp to Realm %d" % realm)
	_exploration.apply(str(state.get("explored", "")))
	current_bunker_idx = int(state.get("bunker", 0))
	stage_task = state.get("stage_task", {}).duplicate()
	portal_active = bool(state.get("portal", false))
	var previous_maya_phase := maya_phase
	maya_phase = str(state.get("maya_phase", "none"))
	rolling_phase = str(state.get("rolling_phase", "none"))
	_gather_with_maya = bool(state.get("gather_with_maya", false))
	maya_finisher = state.get("maya_finisher", {}).duplicate(true)
	corpse_count = int(state.get("corpse_count", 0))
	gather_timer = float(state.get("gather_timer", 0.0))
	gather_center = Vector2(float(state.get("gather_x", 0.0)), float(state.get("gather_y", 0.0)))
	if maya_phase == "cutscene" and previous_maya_phase != "cutscene":
		maya_transformation_requested.emit()
	elif maya_phase == "boss" and previous_maya_phase == "cutscene":
		maya_boss_started.emit()
	elif maya_phase == "finale" and previous_maya_phase != "finale":
		maya_antidote_requested.emit(maya_finisher)
	elif maya_phase == "done" and previous_maya_phase == "finale":
		maya_finale_completed.emit()
	var previous_wave := wave
	var was_waiting := waiting_for_next_wave
	wave = int(state.get("wave", 1))
	waiting_for_next_wave = bool(state.get("waiting", false))
	wave_prep_remaining = float(state.get("prep_remaining", 0.0))
	if wave > previous_wave:
		toast_requested.emit("Wave %d deployed!" % wave)
	elif waiting_for_next_wave and not was_waiting:
		toast_requested.emit("Wave %d cleared!" % wave)
	_spawn_remaining = int(state.get("pending", 0))
	elapsed_seconds = float(state.get("elapsed", 0.0))
	time_of_day_hour = float(state.get("hour", 13.0))
	coins = int(state.get("coins", 0))
	points_earned = int(state.get("points", 0))
	xp_earned = int(state.get("xp", 0))
	tokens_earned = int(state.get("tokens", 0))
	var previous_kills := kills
	var previous_boss_defeats := boss_defeats
	kills = int(state.get("kills", 0))
	boss_defeats = int(state.get("boss_defeats", 0))
	if boss_defeats > previous_boss_defeats:
		AudioManager.play_boss_death()
	elif kills > previous_kills:
		AudioManager.play_zombie_death()
	maya_level = int(state.get("maya_level", 1))
	maya_hp = float(state.get("maya_hp", maya_hp))
	maya_max_hp = float(state.get("maya_max_hp", maya_max_hp))

	var prev_enemy_pos := {}
	for existing_e in enemies:
		prev_enemy_pos[existing_e.get("id")] = Vector2(float(existing_e["x"]), float(existing_e["y"]))
	enemies = _decode_entities(state.get("enemies", []), ENTITY_FIELDS["enemies"])
	var active_enemy_ids := {}
	for e in enemies:
		var eid = e.get("id")
		active_enemy_ids[eid] = true
		var target_pos := Vector2(float(e["x"]), float(e["y"]))
		_enemy_net_targets[eid] = target_pos
		if prev_enemy_pos.has(eid):
			var prev_pos: Vector2 = prev_enemy_pos[eid]
			if prev_pos.distance_to(target_pos) <= 220.0:
				e["x"] = prev_pos.x
				e["y"] = prev_pos.y
	for eid in _enemy_net_targets.keys():
		if not active_enemy_ids.has(eid):
			_enemy_net_targets.erase(eid)

	projectiles = _decode_entities(state.get("projectiles", []), ENTITY_FIELDS["projectiles"], true)
	pickups = _decode_entities(state.get("pickups", []), ENTITY_FIELDS["pickups"])
	builds = _decode_entities(state.get("builds", []), ENTITY_FIELDS["builds"])
	clones = _decode_entities(state.get("clones", []), ENTITY_FIELDS["clones"])
	shockwaves = _decode_entities(state.get("shockwaves", []), ENTITY_FIELDS["shockwaves"], true)
	particles = _decode_entities(state.get("particles", []), ENTITY_FIELDS["particles"], true)
	floating_texts = _decode_entities(state.get("floating_texts", []), ENTITY_FIELDS["floating_texts"], true)
	corpse_visuals = _decode_entities(state.get("corpse_visuals", []), ENTITY_FIELDS["corpse_visuals"])

	var seen_uids := {}
	var squad: Dictionary = state.get("players", {})
	for uid in squad:
		var actor: Dictionary = squad[uid]
		if uid == _local_user_id:
			_apply_local_actor_snapshot(actor)
		else:
			seen_uids[uid] = true
			var ax := float(actor.get("x", 0.0))
			var ay := float(actor.get("y", 0.0))
			var aang := float(actor.get("angle", 0.0))
			if remote_players.has(uid):
				var existing: Dictionary = remote_players[uid]
				var warped := int(actor.get("warp_id", 0)) != int(existing.get("warp_id", 0))
				for key in actor:
					existing[key] = actor[key]
				_update_remote_actor_target(existing, ax, ay, aang, warped)
			else:
				_init_remote_actor_smoothing(actor, ax, ay, aang)
				remote_players[uid] = actor
	for uid in remote_players.keys():
		if not seen_uids.has(uid):
			remote_players.erase(uid)

	if was_team_paused != shared_paused:
		team_pause_changed.emit(shared_paused, shared_pause_owner_name)
	_emit_hud_snapshot()
	queue_redraw()

	var summary: Dictionary = state.get("summary", {})
	if not summary.is_empty():
		match_ended = true
		AudioManager.stop_combat_music()
		if bool(summary.get("victory", false)):
			AudioManager.play_victory()
		else:
			AudioManager.play_defeat()
		match_finished.emit(summary)


func _apply_local_actor_snapshot(actor: Dictionary) -> void:
	_reconcile_local_movement(actor)
	var was_downed := bool(player["downed"])
	var was_reloading := float(player["reload_timer"]) > 0.0
	if float(actor["hp"]) < float(player["hp"]):
		AudioManager.play_player_hurt()
		_shake_trauma = minf(1.0, _shake_trauma + 0.25)
	elif was_downed and not bool(actor["downed"]):
		AudioManager.play_victory()
	if int(actor["shot_count"]) > int(player["shot_count"]):
		match str(actor["last_shot"]):
			"magic":
				AudioManager.play_magic_cast()
			"machine_gun":
				AudioManager.play_pistol_shot(140.0)
			_:
				AudioManager.play_pistol_shot()
	if not was_reloading and float(actor["reload_timer"]) > 0.0:
		AudioManager.play_reload()
	elif was_reloading and float(actor["reload_timer"]) <= 0.0:
		AudioManager.play_pickup()
	if int(actor["skill_uses"]) > int(player["skill_uses"]):
		AudioManager.play_skill()
		_shake_trauma = minf(1.0, _shake_trauma + 0.35)

	for key in ["hp", "max_hp", "mana", "max_mana", "ammo", "mag_size", "downed", "reload_timer",
			"skill_cooldowns", "skill_charges", "skill_levels", "item_inventory", "shot_count", "skill_uses"]:
		player[key] = actor[key]
	if bool(player["downed"]):
		_firing = false
	skill_cooldowns = player["skill_cooldowns"]
	skill_charges = player["skill_charges"]
	skill_levels = player["skill_levels"]
	if actor.has("notice"):
		toast_requested.emit(str(actor["notice"]))


func _reconcile_local_movement(actor: Dictionary) -> void:
	var input_ack := int(actor["input_sequence"])
	var host_pos := _actor_position(actor)
	var warped := int(actor["warp_id"]) != int(player["warp_id"])
	if warped:
		player["warp_id"] = actor["warp_id"]
		player["x"] = host_pos.x
		player["y"] = host_pos.y
		_acked_input_sequence = input_ack
		_pending_input_positions.clear()
		return
	if input_ack <= _acked_input_sequence:
		return
	_acked_input_sequence = input_ack
	var correction := Vector2.ZERO
	if bool(actor["downed"]) or not _pending_input_positions.has(input_ack):
		correction = host_pos - _actor_position(player)
	else:
		var predicted: Vector2 = _pending_input_positions[input_ack]
		correction = host_pos - predicted
	for seq in _pending_input_positions.keys():
		if int(seq) <= input_ack:
			_pending_input_positions.erase(seq)
		else:
			_pending_input_positions[seq] += correction
	var corrected := _actor_position(player) + correction
	var resolved := _resolve_world_collisions(corrected.x, corrected.y, float(player["radius"]), false)
	player["x"] = resolved.x
	player["y"] = resolved.y


func _emit_hud_snapshot() -> void:
	if player.is_empty():
		return
	var day := GameRules.get_day_night_state(time_of_day_hour)
	var bunker := _get_current_bunker()
	var in_b := GameRules.is_inside_safe_zone(float(player["x"]), float(player["y"]), bunker)

	var boss_hp := 0
	var boss_max := 0
	var boss_n := ""
	for e in enemies:
		if bool(e.get("is_boss", false)):
			boss_hp = int(e["hp"])
			boss_max = int(e["max_hp"])
			boss_n = str(e["name"])
			break

	var squad_arr: Array = []
	var revive_targets: Array = []
	for uid in remote_players.keys():
		var rp: Dictionary = remote_players[uid]
		squad_arr.append("%s (%s)" % [str(rp.get("username", "Ally")), "DOWNED" if bool(rp.get("downed", false)) else "%d HP" % int(rp.get("hp", 100))])
		revive_targets.append({"user_id": str(uid), "name": str(rp.get("username", "Ally")), "downed": bool(rp.get("downed", false))})

	var tut_txt := ""
	if mode == "tutorial" and tutorial_step_idx < GameData.TUTORIAL_STEPS.size():
		tut_txt = str(GameData.TUTORIAL_STEPS[tutorial_step_idx])

	hud_updated.emit({
		"mode": mode,
		"stage_id": stage_id,
		"stage_name": str(_stage_data.get("name", "")),
		"waves_count": int(_stage_data.get("waves_count", 5)),
		"portal_realm": portal_realm,
		"wave": wave,
		"bunker_name": str(bunker.get("name", "Bunker")),
		"in_bunker": in_b,
		"day_phase": str(day["phase"]),
		"day_time": str(day["formatted_time"]),
		"enemies_remaining": enemies.size() + (enemies_to_spawn.size() if is_host else _spawn_remaining),
		"elapsed_seconds": int(round(elapsed_seconds)),
		"hp": int(player["hp"]),
		"max_hp": int(player["max_hp"]),
		"downed": bool(player["downed"]),
		"mana": int(player["mana"]),
		"max_mana": int(player["max_mana"]),
		"ammo": int(player["ammo"]),
		"mag_size": int(player["mag_size"]),
		"reloading": float(player["reload_timer"]) > 0.0,
		"hero_class": str(player["hero_class"]),
		"username": str(player["username"]),
		"coins": coins,
		"points_earned": points_earned,
		"maya_level": maya_level,
		"boss_hp": boss_hp,
		"boss_max_hp": boss_max,
		"boss_name": boss_n,
		"waiting_for_next_wave": waiting_for_next_wave,
		"wave_prep_remaining": wave_prep_remaining,
		"can_skip_wave_preparation": _can_skip_wave_preparation(),
		"skill_buy_wave": wave + 1 if waiting_for_next_wave else wave,
		"task_text": _task_label(),
		"antidote_status": _antidote_status(),
		"task_complete": bool(stage_task.get("complete", true)),
		"task_blocks_next_wave": _task_blocks_next_wave(),
		"task_distance": int(round(_actor_position(player).distance_to(_task_target()))) if not stage_task.is_empty() and not bool(stage_task.get("complete", false)) else 0,
		"skill_cooldowns": skill_cooldowns.duplicate(),
		"skill_charges": skill_charges.duplicate(),
		"inventory": player.get("item_inventory", {}).duplicate(),
		"online": is_online,
		"team_paused": shared_paused,
		"pause_remaining": get_local_pause_remaining(),
		"squad_statuses": squad_arr,
		"revive_targets": revive_targets,
		"tutorial_hint": tut_txt,
	})


func _draw_online_actor(actor: Dictionary, font: Font, local: bool) -> void:
	var draw_actor := actor
	if not local:
		draw_actor = actor.duplicate()
		draw_actor["x"] = float(actor.get("render_x", actor["x"]))
		draw_actor["y"] = float(actor.get("render_y", actor["y"]))
		draw_actor["angle"] = float(actor.get("render_angle", actor["angle"]))
	var pos := _actor_position(draw_actor)
	ComicActorDraw.draw_player(self, draw_actor, _visual_time, local)

	if not local:
		var outline := Color("#BAE6FD")
		var label := str(actor["username"])
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, pos + Vector2(-label_width * 0.5, -26.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, outline)
		var hp_ratio := clampf(float(actor["hp"]) / maxf(float(actor["max_hp"]), 1.0), 0.0, 1.0)
		draw_rect(Rect2(pos.x - 16.0, pos.y + 20.0, 32.0, 4.0), Color("#0F172A"))
		draw_rect(Rect2(pos.x - 16.0, pos.y + 20.0, hp_ratio * 32.0, 4.0), Color("#22C55E"))


func _draw_collection_tentacle(origin: Vector2, tip: Vector2, boss: bool, seed: float, gripping: bool) -> void:
	var distance := origin.distance_to(tip)
	if distance < 5.0:
		return
	var direction := (tip - origin) / distance
	var normal := Vector2(-direction.y, direction.x)
	var points := PackedVector2Array()
	for j in range(13):
		var u := float(j) / 12.0
		var sway := sin(_visual_time * 3.3 + u * 9.0 + seed) * sin(u * PI) * minf(24.0, distance * 0.065)
		points.append(origin.lerp(tip, u) + normal * sway)
	var base_width := 13.0 if boss else 8.0
	for j in range(12):
		var taper := 1.0 - float(j) / 18.0
		draw_line(points[j], points[j + 1], Color("#102A24"), base_width * taper + 2.0, true)
		draw_line(points[j], points[j + 1], Color("#4D8063"), base_width * taper, true)
		draw_line(points[j] - normal * 1.3, points[j + 1] - normal * 1.3, Color("#83AE75", 0.65), 1.2, true)
	for j in range(2, 12, 2):
		var cup := points[j] + normal * (base_width * 0.36)
		draw_circle(cup, 2.2 if boss else 1.6, Color("#B4D097"))
	if gripping:
		var hook := 16.0 if boss else 10.0
		draw_arc(tip, hook, direction.angle() - 1.15, direction.angle() + 1.15, 10, Color("#234938"), 4.5 if boss else 3.0, true)
		draw_circle(tip + normal * hook * 0.7, 3.0, Color("#A4C58D"))


func _draw() -> void:
	if _stage_data.is_empty() or player.is_empty():
		return
	var mw := float(_stage_data.get("map_width", 2600.0))
	var mh := float(_stage_data.get("map_height", 1200.0))
	var floor_col := Color(str(_stage_data.get("floor_color", "#36453B")))
	var grid_col := Color(str(_stage_data.get("floor_grid_color", "#2B382F")))
	var font := ThemeDB.fallback_font
	var visible_enemies := _visible_enemies()

	# Terrain floor + subtle tactical grid
	draw_rect(Rect2(0, 0, mw, mh), floor_col)
	for gx in range(0, int(mw), 80):
		draw_line(Vector2(gx, 0), Vector2(gx, mh), grid_col, 1.5)
	for gy in range(0, int(mh), 80):
		draw_line(Vector2(0, gy), Vector2(mw, gy), grid_col, 1.5)
	var edge := Vector2.ONE * ARENA_EDGE_INSET
	draw_rect(Rect2(edge, Vector2(mw, mh) - edge * 2.0), Color(0.67, 0.74, 0.76, 0.64), false, 2.0)

	# Obstacles & Hazards
	for obs in _stage_data.get("obstacles", []):
		var r := Rect2(float(obs["x"]), float(obs["y"]), float(obs["w"]), float(obs["h"]))
		var col := Color(str(obs.get("color", "#64748B")))
		draw_rect(r, col)
		draw_rect(r, Color("#0F172A"), false, 2.0)

	# Bunkers
	var bunkers: Array = _stage_data.get("bunkers", [])
	for bi in range(bunkers.size()):
		var b: Dictionary = bunkers[bi]
		var bx := float(b["x"])
		var by := float(b["y"])
		var bnd := GameRules.get_bunker_bounds(b)
		var hw := float(bnd["half_w"])
		var hh := float(bnd["half_h"])
		var locked := GameRules.is_bunker_locked(mode, bi, current_bunker_idx, _sector_open_after_prep())

		draw_rect(Rect2(bx - hw - 42, by - hh - 42, hw * 2 + 84, hh * 2 + 84), Color(0.11, 0.13, 0.16, 0.65))
		var floor_r := Rect2(bx - hw, by - hh, hw * 2, hh * 2)
		draw_rect(floor_r, Color("#3E291C"))
		for py in range(int(by - hh) + 18, int(by + hh), 20):
			draw_line(Vector2(bx - hw, py), Vector2(bx + hw, py), Color("#2A1B12"), 1.5)
		draw_rect(Rect2(bx - hw * 0.25, by - hh * 0.22, hw * 0.50, hh * 0.44), Color("#4A2525"))
		draw_rect(Rect2(bx - hw + 24, by - hh + 24, 72, 28), Color("#64748B"))
		draw_rect(Rect2(bx - hw + 24, by + hh - 64, 62, 34), Color("#334155"))
		draw_rect(Rect2(bx + hw - 88, by + hh - 64, 58, 30), Color("#E2E8F0"))
		draw_rect(Rect2(bx + hw - 76, by - hh + 24, 44, 24), Color("#15803D"))

		var shop_c := GameRules.get_shop_station_coords(b)
		draw_circle(Vector2(float(shop_c["x"]), float(shop_c["y"])), 24.0, Color(0.13, 0.77, 0.37, 0.25))
		draw_rect(Rect2(float(shop_c["x"]) - 14, float(shop_c["y"]) - 14, 28, 28), Color("#F59E0B"))
		draw_string(font, Vector2(float(shop_c["x"]) - 22, float(shop_c["y"]) + 32), "SHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#FDE68A"))

		for wr in GameRules.get_bunker_wall_rects(b):
			draw_rect(wr, Color("#78716C"))
			draw_rect(wr, Color("#1C1917"), false, 2.0)

		if locked:
			draw_rect(floor_r, Color(0.94, 0.27, 0.27, 0.22))
			draw_string(font, Vector2(bx - 56, by), "SECTOR LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#FCA5A5"))

	# Sector Lockdown Barrier
	var active_barrier_x := _get_active_sector_barrier_x()
	if active_barrier_x > 0.0:
		var bar_x := active_barrier_x
		var bar_col := Color("#EF4444")
		draw_rect(Rect2(bar_x - 3.0, 0.0, 6.0, mh), Color(bar_col.r, bar_col.g, bar_col.b, 0.22))
		for dy in range(20, int(mh), 44):
			draw_line(Vector2(bar_x, float(dy)), Vector2(bar_x, float(dy + 24)), bar_col, 4.0)
		var bar_label := "SECTOR OPENS IN %ds" % ceili(wave_prep_remaining) if waiting_for_next_wave else "SECTOR BARRIER (CLEAR WAVE)"
		draw_string(font, Vector2(bar_x - 108.0, float(player["y"]) - 48.0), bar_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, bar_col)

	# Scout Maya Watchtower + Revive Station
	var cur_b := _get_current_bunker()
	var m_pos := GameRules.get_maya_tower_coords(cur_b, mw, mh)
	draw_rect(Rect2(m_pos.x - 28, m_pos.y - 28, 56, 56), Color("#451A03"))
	if maya_phase in ["gathering", "boss", "finale", "done"]:
		draw_rect(Rect2(m_pos.x - 28, m_pos.y - 28, 56, 56), Color("#64748B"), false, 3.0)
		draw_string(font, Vector2(m_pos.x - 44, m_pos.y - 34), "MAYA'S EMPTY POST", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#CBD5E1"))
		if maya_phase == "gathering":
			var approach := clampf(1.0 - gather_timer / 3.5, 0.0, 1.0)
			var maya_pos := m_pos.lerp(gather_center, approach)
			ComicActorDraw.draw_maya_ranger(self, maya_pos, _visual_time, gather_center - maya_pos)
	else:
		draw_rect(Rect2(m_pos.x - 28, m_pos.y - 28, 56, 56), Color("#F59E0B"), false, 3.0)
		var maya_target := GameRules.select_aim_target(m_pos.x, m_pos.y, null, visible_enemies, 620.0)
		var maya_aim := Vector2(float(maya_target["x"]) - m_pos.x, float(maya_target["y"]) - m_pos.y) if not maya_target.is_empty() else Vector2.RIGHT
		var maya_recoil := clampf(maya_fire_timer * 3.0, 0.0, 1.0)
		ComicActorDraw.draw_maya_ranger(self, m_pos, _visual_time, maya_aim, maya_recoil)
		draw_string(font, Vector2(m_pos.x - 42, m_pos.y - 34), "SCOUT MAYA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#FDE047"))

	if is_online:
		var rev := GameRules.get_revive_station_coords(cur_b)
		var rp := Vector2(float(rev["x"]), float(rev["y"]))
		draw_circle(rp, 30.0, Color(0.22, 0.74, 0.97, 0.28))
		draw_arc(rp, 30.0, 0.0, TAU, 24, Color("#38BDF8"), 2.5)
		draw_string(font, Vector2(rp.x - 40, rp.y + 44), "REVIVE STATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#BAE6FD"))

	# Endless Portal Vortex
	if mode == "endless" and portal_active:
		var pc := GameRules.get_endless_portal_coords(cur_b, mw, mh)
		var pp := Vector2(float(pc["x"]), float(pc["y"]))
		draw_circle(pp, 44.0, Color(0.66, 0.33, 0.97, 0.35))
		draw_arc(pp, 44.0, 0.0, TAU, 32, Color("#C084FC"), 4.0)
		draw_string(font, Vector2(pp.x - 50, pp.y - 52), "REALM WARP %ds" % ceili(wave_prep_remaining), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#E9D5FF"))

	# Stage Task Marker + Player Compass Arrow
	if _task_guide_active():
		var task_pos := _task_target()
		var task_color := Color("#38BDF8") if str(stage_task["type"]) == "antidote" or str(stage_task["type"]) == "deliver_antidote" else Color("#FBBF24")
		var task_pulse := 2.0 * sin(elapsed_seconds * 5.0)
		draw_circle(task_pos, 27.0 + task_pulse, Color(task_color, 0.23))
		draw_arc(task_pos, 26.0 + task_pulse, 0.0, TAU, 28, task_color, 3.0)
		match str(stage_task["type"]):
			"antidote", "deliver_antidote":
				draw_rect(Rect2(task_pos.x - 8.0, task_pos.y - 12.0, 16.0, 24.0), Color("#0E7490"))
				draw_rect(Rect2(task_pos.x - 6.0, task_pos.y - 9.0, 12.0, 17.0), Color("#67E8F9"))
				draw_rect(Rect2(task_pos.x - 5.0, task_pos.y - 16.0, 10.0, 5.0), Color("#E2E8F0"))
			"rescue":
				draw_circle(task_pos + Vector2(0, -6), 7.0, Color("#FBC9A0"))
				draw_line(task_pos + Vector2(0, 2), task_pos + Vector2(0, 13), Color("#3B82F6"), 8.0)
			_:
				draw_rect(Rect2(task_pos.x - 12.0, task_pos.y - 10.0, 24.0, 20.0), task_color.darkened(0.35))
				draw_rect(Rect2(task_pos.x - 12.0, task_pos.y - 10.0, 24.0, 20.0), task_color, false, 2.0)
		if float(stage_task.get("progress", 0.0)) > 0.0:
			draw_arc(task_pos, 34.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(float(stage_task["progress"]) / 1.5, 0.0, 1.0), 24, Color("#22C55E"), 4.0)
		draw_string(font, task_pos + Vector2(-65, -42), "STAGE TASK", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, task_color)
		var task_dir := task_pos - _actor_position(player)
		if task_dir.length() > 180.0:
			var arrow_pos := _actor_position(player) + task_dir.normalized() * 64.0
			draw_circle(arrow_pos, 12.0, Color("#0F172A"))
			draw_colored_polygon(PackedVector2Array([arrow_pos + task_dir.normalized() * 11.0, arrow_pos + task_dir.normalized().rotated(2.4) * 9.0, arrow_pos + task_dir.normalized().rotated(-2.4) * 9.0]), task_color)

	# Builds & Clones
	for b in builds:
		var bp := Vector2(float(b["x"]), float(b["y"]))
		var kind := str(b["kind"])
		if kind == "wall":
			draw_rect(Rect2(bp.x - 22, bp.y - 10, 44, 20), Color("#92400E"))
		elif kind == "spike_trap":
			draw_rect(Rect2(bp.x - 18, bp.y - 18, 36, 36), Color("#64748B"))
		else:
			draw_circle(bp, 16.0, Color("#0EA5E9"))
	for c in clones:
		var cp := Vector2(float(c["x"]), float(c["y"]))
		var clone_near := GameRules.select_aim_target(cp.x, cp.y, null, visible_enemies, 480.0)
		var clone_target := Vector2(float(clone_near["x"]), float(clone_near["y"])) if not clone_near.is_empty() else cp + Vector2.RIGHT.rotated(float(player["angle"])) * 100.0
		ComicActorDraw.draw_clone(self, c, _visual_time, clone_target)

	# Pickups
	for pk in pickups:
		var coin_effect := str(pk["kind"]) == "coin_fx"
		var col := Color("#FBBF24") if coin_effect else Color("#22C55E")
		var drop_pos := Vector2(float(pk["x"]), float(pk["y"]))
		draw_circle(drop_pos, 9.0, col)
		if coin_effect:
			draw_arc(drop_pos, 12.0, 0.0, TAU, 16, Color("#FEF08A"), 2.0)

	# Corpses
	for visual in corpse_visuals:
		var from_pos := Vector2(float(visual["sx"]), float(visual["sy"]))
		var to_pos := Vector2(float(visual["ex"]), float(visual["ey"]))
		var position := from_pos
		var dragging := 0.0
		if bool(visual["gathering"]):
			dragging = clampf(float(visual["t"]), 0.0, 1.0)
			position = from_pos.lerp(to_pos, dragging)
			_draw_collection_tentacle(to_pos, position, false, from_pos.x * 0.01 + from_pos.y * 0.01, true)
		else:
			var factor := 1.35 if bool(visual["boss"]) else 1.0
			var rest_end := (CORPSE_REST_SECONDS + float(visual["delay"])) * factor
			var reach_end := rest_end + CORPSE_REACH_SECONDS * factor
			var grip_end := reach_end + CORPSE_GRIP_SECONDS * factor
			var age := float(visual["t"])
			if age >= grip_end:
				var drag_t := clampf((age - grip_end) / (CORPSE_DRAG_SECONDS * factor), 0.0, 1.0)
				dragging = drag_t * drag_t * (3.0 - 2.0 * drag_t)
				position = from_pos.lerp(to_pos, dragging)
			if age >= rest_end:
				var reach_t := clampf((age - rest_end) / (CORPSE_REACH_SECONDS * factor), 0.0, 1.0)
				var tip := to_pos.lerp(position, reach_t)
				_draw_collection_tentacle(to_pos, tip, bool(visual["boss"]), from_pos.x * 0.01 + from_pos.y * 0.01, age >= reach_end)
		ComicActorDraw.draw_corpse(self, visual, position, dragging)

	# Enemies
	for e in visible_enemies:
		var ep := Vector2(float(e["x"]), float(e["y"]))
		var er := float(e["radius"])
		var face_target := _nearest_visible_player_pos(ep)
		if bool(e.get("passes_walls", false)):
			draw_circle(ep, er + 5.0, Color(0.6, 0.7, 1.0, 0.18))
		if str(e.get("boss_id", "")) == "human_tumbleweed":
			ComicActorDraw.draw_human_tumbleweed(self, ep, _visual_time, er, int(e.get("corpse_count", corpse_count)), _gather_with_maya)
		else:
			ComicActorDraw.draw_enemy(self, e, _visual_time, face_target)
		if aim_target_id == e["id"]:
			draw_arc(ep, er + 8.0, 0.0, TAU, 24, Color("#EF4444"), 2.5)
		var hp_pct := clampf(float(e["hp"]) / maxf(1.0, float(e["max_hp"])), 0.0, 1.0)
		draw_rect(Rect2(ep.x - er, ep.y - er - 9.0, er * 2.0 * hp_pct, 4.0), Color("#EF4444"))

	# Players
	if is_online:
		for actor in remote_players.values():
			_draw_online_actor(actor, font, false)
		_draw_online_actor(player, font, true)
	else:
		ComicActorDraw.draw_player(self, player, _visual_time, true)

	# Projectiles
	for pr in projectiles:
		draw_circle(Vector2(float(pr["x"]), float(pr["y"])), 5.0, pr["color"])

	# FX
	for sw in shockwaves:
		var c: Color = sw["color"]
		draw_arc(Vector2(float(sw["x"]), float(sw["y"])), float(sw["r"]), 0.0, TAU, 28, Color(c.r, c.g, c.b, 0.75), 3.0)
	for pt in particles:
		draw_rect(Rect2(float(pt["x"]) - 3, float(pt["y"]) - 3, 6, 6), pt["color"])
	for ft in floating_texts:
		draw_string(font, Vector2(float(ft["x"]) - 14, float(ft["y"])), str(ft["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ft["color"])

	# Day/Night atmospheric overlay
	if bool(SaveManager.settings.get("day_night_effects", true)):
		var day := GameRules.get_day_night_state(time_of_day_hour)
		var alpha := float(day["darkness_alpha"])
		if alpha > 0.02:
			var tc: Color = day["tint_color"]
			draw_rect(Rect2(0, 0, mw, mh), Color(tc.r, tc.g, tc.b, alpha * 0.62))
			for lan in _stage_data.get("lanterns", []):
				draw_circle(Vector2(float(lan["x"]), float(lan["y"])), float(lan["radius"]) * 0.65, Color(1.0, 0.92, 0.6, 0.14))

	for bunker in bunkers:
		var bounds := GameRules.get_bunker_bounds(bunker)
		var center := _actor_position(bunker)
		var light_x := float(bounds["half_w"]) + 14.0
		for offset in [-light_x, light_x]:
			var light := center + Vector2(float(offset), -42.0)
			draw_circle(light, 60.0, Color(1.0, 0.72, 0.28, 0.06))
			draw_circle(light, 30.0, Color(1.0, 0.78, 0.39, 0.12))
			draw_circle(light, 6.0, Color("#FDE68A"))
