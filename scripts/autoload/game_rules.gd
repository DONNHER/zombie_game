extends Node

const SAVE_VERSION := 1
const MAX_WEAPON_UPGRADE_LEVEL := 5
const MAX_MAYA_TOWER_LEVEL := 5
const BUNKER_DOOR_HALF := 42.0
const BUNKER_WALL_THICKNESS := 16.0

const STAGE_TARGET_TIMES := {
	1: 240,
	2: 300,
	3: 340,
	4: 390,
	5: 450,
}

func calculate_wave_enemy_hp(base_hp: float, wave: int) -> int:
	var w := maxi(1, wave)
	var mult := minf(1.0 + 0.12 * float(w - 1), 8.5)
	return int(round(base_hp * mult))


func calculate_wave_enemy_damage(base_damage: float, wave: int) -> int:
	var w := maxi(1, wave)
	var mult := minf(1.0 + 0.08 * float(w - 1), 4.5)
	return int(round(base_damage * mult))


func calculate_endless_wave_composition(wave: int) -> Dictionary:
	var w := maxi(1, wave)
	var total_enemies := mini(8 + w * 3, 64)
	var spawn_interval := maxf(0.32, 1.35 - float(w) * 0.03)

	if w <= 5:
		var allowed: Array[String] = ["basic"]
		if w >= 4:
			allowed = ["basic", "fast", "spirit", "flying"]
		elif w >= 2:
			allowed = ["basic", "flying", "spirit"]
		return {"total_enemies": total_enemies, "allowed_types": allowed, "spawn_interval": spawn_interval, "mini_boss_count": 0, "boss_id": ""}
	if w <= 10:
		return {"total_enemies": total_enemies, "allowed_types": ["basic", "fast", "tank", "spirit", "flying"], "spawn_interval": spawn_interval, "mini_boss_count": 0, "boss_id": "village_boss" if w == 10 else ""}
	if w <= 20:
		return {"total_enemies": total_enemies, "allowed_types": ["basic", "fast", "tank", "elite", "spirit", "flying"], "spawn_interval": spawn_interval, "mini_boss_count": 1 if w % 5 == 0 else 0, "boss_id": "forest_boss" if w == 20 else ""}
	if w <= 30:
		return {"total_enemies": total_enemies, "allowed_types": ["basic", "fast", "tank", "elite", "spirit", "flying"], "spawn_interval": spawn_interval, "mini_boss_count": 1 if w % 3 == 0 else 0, "boss_id": "city_boss" if w == 30 else ""}

	var recurring := ["village_boss", "forest_boss", "city_boss", "laboratory_boss", "final_boss"]
	var is_boss := w % 5 == 0
	var boss_idx := int(floor(float(w) / 5.0)) % recurring.size()
	return {"total_enemies": total_enemies, "allowed_types": ["fast", "tank", "elite", "spirit", "flying"], "spawn_interval": spawn_interval, "mini_boss_count": 1, "boss_id": recurring[boss_idx] if is_boss else ""}


func get_day_night_state(raw_hour: float) -> Dictionary:
	var hour := fposmod(raw_hour, 24.0)
	var phase := "Day"
	if hour >= 5.0 and hour < 6.0:
		phase = "Dawn"
	elif hour >= 6.0 and hour < 9.0:
		phase = "Sunrise"
	elif hour >= 9.0 and hour < 12.0:
		phase = "Morning"
	elif hour >= 12.0 and hour < 16.0:
		phase = "Day"
	elif hour >= 16.0 and hour < 18.0:
		phase = "Afternoon"
	elif hour >= 18.0 and hour < 20.0:
		phase = "Sunset"
	elif hour >= 20.0:
		phase = "Night"
	elif hour < 5.0:
		phase = "Midnight"

	var is_night := hour >= 19.5 or hour < 5.5
	var darkness_alpha := 0.0
	var tint_color := Color("#0A1224")

	if hour >= 16.0 and hour < 19.5:
		var t := (hour - 16.0) / 3.5
		darkness_alpha = snappedf(t * 0.48, 0.001)
		tint_color = Color("#432818") if hour < 18.2 else Color("#181E38")
	elif hour >= 19.5:
		var t := minf(1.0, (hour - 19.5) / 2.5)
		darkness_alpha = snappedf(0.48 + t * 0.16, 0.001)
		tint_color = Color("#0B1226")
	elif hour < 5.0:
		darkness_alpha = 0.64
		tint_color = Color("#090F20")
	elif hour >= 5.0 and hour < 7.5:
		var t := 1.0 - (hour - 5.0) / 2.5
		darkness_alpha = snappedf(t * 0.64, 0.001)
		tint_color = Color("#1E243B") if hour < 6.2 else Color("#4A2E20")

	var whole_hour := int(floor(hour))
	var minutes := int(floor((hour - float(whole_hour)) * 60.0))
	var period := "PM" if whole_hour >= 12 else "AM"
	var display_hour := 12 if whole_hour % 12 == 0 else whole_hour % 12
	var formatted_time := "%d:%02d %s" % [display_hour, minutes, period]

	return {
		"hour": hour,
		"phase": phase,
		"formatted_time": formatted_time,
		"is_night": is_night,
		"darkness_alpha": darkness_alpha,
		"tint_color": tint_color,
	}


func compute_effective_weapon_stats(weapon_id: String, upgrade_level: int = 0) -> Dictionary:
	var base: Dictionary = GameData.WEAPONS[weapon_id].duplicate(true)
	var lvl := clampi(upgrade_level, 0, MAX_WEAPON_UPGRADE_LEVEL)
	base["damage"] = int(round(float(base["damage"]) * (1.0 + float(lvl) * 0.14)))
	base["fire_rate"] = snappedf(float(base["fire_rate"]) * (1.0 + float(lvl) * 0.06), 0.01)
	base["reload_time"] = snappedf(maxf(0.45, float(base["reload_time"]) * (1.0 - float(lvl) * 0.06)), 0.01)
	base["crit_chance"] = snappedf(minf(0.65, float(base["crit_chance"]) + float(lvl) * 0.025), 0.001)
	base["projectile_speed"] = float(round(float(base["projectile_speed"]) * (1.0 + float(lvl) * 0.04)))
	return base


func xp_for_next_level(level: int) -> int:
	return int(round(100.0 * pow(float(maxi(1, level)), 1.35)))


func compute_level_from_xp(total_xp: int) -> Dictionary:
	var level := 1
	var remaining := maxi(0, total_xp)
	while remaining >= xp_for_next_level(level) and level < 99:
		remaining -= xp_for_next_level(level)
		level += 1
	return {
		"level": level,
		"current_level_xp": remaining,
		"next_level_xp": xp_for_next_level(level),
	}


func can_unlock_weapon(save: Dictionary, weapon_id: String) -> Dictionary:
	var unlocked: Array = save.get("unlocked_weapons", [])
	if unlocked.has(weapon_id):
		return {"ok": false, "reason": "Already unlocked"}
	var def: Dictionary = GameData.WEAPONS[weapon_id]
	var parent_id := str(def.get("parent_id", ""))
	if parent_id != "" and not unlocked.has(parent_id):
		return {"ok": false, "reason": "Requires %s" % str(GameData.WEAPONS[parent_id]["name"])}
	if int(save.get("survival_points", 0)) < int(def["cost_points"]):
		return {"ok": false, "reason": "Need %d Survival Points" % int(def["cost_points"])}
	if int(save.get("boss_tokens", 0)) < int(def["cost_tokens"]):
		return {"ok": false, "reason": "Need %d Boss Tokens" % int(def["cost_tokens"])}
	return {"ok": true, "reason": ""}


func apply_weapon_unlock(save: Dictionary, weapon_id: String) -> Dictionary:
	var check := can_unlock_weapon(save, weapon_id)
	if not bool(check["ok"]):
		return {"ok": false, "next_save": save, "reason": check["reason"]}
	var def: Dictionary = GameData.WEAPONS[weapon_id]
	var next := save.duplicate(true)
	next["survival_points"] = int(next["survival_points"]) - int(def["cost_points"])
	next["boss_tokens"] = int(next["boss_tokens"]) - int(def["cost_tokens"])
	var unlocked: Array = next["unlocked_weapons"]
	unlocked.append(weapon_id)
	var eq: Array = next["equipped_weapons"]
	if str(def["category"]) == "pistol":
		eq[0] = weapon_id
	else:
		eq[1] = weapon_id
	next["updated_at"] = int(Time.get_unix_time_from_system())
	return {"ok": true, "next_save": next, "reason": ""}


func get_weapon_upgrade_cost(weapon_id: String, current_level: int) -> int:
	var def: Dictionary = GameData.WEAPONS[weapon_id]
	return int(round((80.0 + float(def["tier"]) * 55.0) * float(current_level + 1)))


func apply_weapon_upgrade(save: Dictionary, weapon_id: String) -> Dictionary:
	var unlocked: Array = save.get("unlocked_weapons", [])
	if not unlocked.has(weapon_id):
		return {"ok": false, "next_save": save, "reason": "Weapon not unlocked yet"}
	var upgrades: Dictionary = save.get("weapon_upgrades", {})
	var cur := int(upgrades.get(weapon_id, 0))
	if cur >= MAX_WEAPON_UPGRADE_LEVEL:
		return {"ok": false, "next_save": save, "reason": "Maximum upgrade level reached"}
	var cost := get_weapon_upgrade_cost(weapon_id, cur)
	if int(save.get("survival_points", 0)) < cost:
		return {"ok": false, "next_save": save, "reason": "Need %d Survival Points" % cost}
	var next := save.duplicate(true)
	next["survival_points"] = int(next["survival_points"]) - cost
	next["weapon_upgrades"][weapon_id] = cur + 1
	next["updated_at"] = int(Time.get_unix_time_from_system())
	return {"ok": true, "next_save": next, "reason": ""}


func calculate_kill_rewards(enemy_type: String, is_night: bool) -> Dictionary:
	var def: Dictionary = GameData.ENEMIES[enemy_type]
	var night_bonus := 1.25 if is_night else 1.0
	return {
		"points": int(round(float(def["points_reward"]) * night_bonus)),
		"xp": int(round(float(def["xp_reward"]) * night_bonus)),
	}


func calculate_zombie_coins(enemy_type: String, stage_id: int, is_night: bool) -> int:
	var base := {"basic": 8, "fast": 12, "tank": 22, "elite": 28, "spirit": 18, "flying": 16}
	var eff := 2 if stage_id == 99 else maxi(1, stage_id)
	var stage_scale := 1.0 + float(eff - 1) * 0.15
	var night_scale := 1.25 if is_night else 1.0
	return maxi(5, int(round(float(base.get(enemy_type, 8)) * stage_scale * night_scale)))


func calculate_boss_team_coins(boss_id: String, stage_id: int) -> int:
	var boss: Dictionary = GameData.BOSSES[boss_id]
	var eff := 3 if stage_id == 99 else maxi(1, stage_id)
	return int(round(90.0 + float(boss["stage_id"]) * 30.0 + float(eff) * 15.0))


func calculate_boss_rewards(boss_id: String) -> Dictionary:
	var boss: Dictionary = GameData.BOSSES[boss_id]
	return {
		"points": int(boss["points_reward"]),
		"xp": int(boss["xp_reward"]),
		"tokens": int(boss["token_reward"]),
	}


func select_aim_target(px: float, py: float, selected_id: Variant, candidates: Array, max_range: float = 950.0) -> Dictionary:
	if candidates.is_empty():
		return {}
	if selected_id != null:
		for c in candidates:
			if c["id"] == selected_id:
				if Vector2(float(c["x"]) - px, float(c["y"]) - py).length() <= max_range * 1.2:
					return c
				break
	var closest: Dictionary = {}
	var best_sq := max_range * max_range
	for c in candidates:
		var dx := float(c["x"]) - px
		var dy := float(c["y"]) - py
		var d_sq := dx * dx + dy * dy
		if d_sq < best_sq:
			best_sq = d_sq
			closest = c
	return closest


func get_bunker_bounds(bunker: Dictionary) -> Dictionary:
	var r := float(bunker.get("radius", 180.0))
	return {"half_w": round(r * 1.06), "half_h": round(r * 0.84)}


func get_bunker_lock_radius(bunker: Dictionary) -> float:
	return round(float(bunker.get("radius", 180.0)) * 1.42)


func is_inside_safe_zone(x: float, y: float, bunker: Dictionary) -> bool:
	var b := get_bunker_bounds(bunker)
	return absf(x - float(bunker["x"])) <= float(b["half_w"]) + 12.0 and absf(y - float(bunker["y"])) <= float(b["half_h"]) + 12.0


func does_enemy_pass_walls(enemy_type: String) -> bool:
	return bool(GameData.ENEMIES.get(enemy_type, {}).get("passes_walls", false))


func get_bunker_wall_rects(bunker: Dictionary) -> Array[Rect2]:
	var bx := float(bunker["x"])
	var by := float(bunker["y"])
	var bnd := get_bunker_bounds(bunker)
	var half_w := float(bnd["half_w"])
	var half_h := float(bnd["half_h"])
	var seg_w := half_w - BUNKER_DOOR_HALF
	var seg_h := half_h - BUNKER_DOOR_HALF
	var part_h := maxf(22.0, round(half_w * 0.28))
	var part_v := maxf(22.0, round(half_h * 0.30))
	var p_thick := 9.0
	var wt := BUNKER_WALL_THICKNESS
	return [
		Rect2(bx - half_w, by - half_h, seg_w, wt),
		Rect2(bx + BUNKER_DOOR_HALF, by - half_h, seg_w, wt),
		Rect2(bx - half_w, by + half_h - wt, seg_w, wt),
		Rect2(bx + BUNKER_DOOR_HALF, by + half_h - wt, seg_w, wt),
		Rect2(bx - half_w, by - half_h, wt, seg_h),
		Rect2(bx - half_w, by + BUNKER_DOOR_HALF, wt, seg_h),
		Rect2(bx + half_w - wt, by - half_h, wt, seg_h),
		Rect2(bx + half_w - wt, by + BUNKER_DOOR_HALF, wt, seg_h),
		Rect2(bx - p_thick * 0.5, by - half_h + wt, p_thick, part_v),
		Rect2(bx - p_thick * 0.5, by + half_h - wt - part_v, p_thick, part_v),
		Rect2(bx - half_w + wt, by - p_thick * 0.5, part_h, p_thick),
		Rect2(bx + half_w - wt - part_h, by - p_thick * 0.5, part_h, p_thick),
	]


func get_bunker_doorway_points(bunker: Dictionary) -> Array[Vector2]:
	var bx := float(bunker["x"])
	var by := float(bunker["y"])
	var bnd := get_bunker_bounds(bunker)
	var half_w := float(bnd["half_w"])
	var half_h := float(bnd["half_h"])
	return [
		Vector2(bx - half_w - 10.0, by),
		Vector2(bx + half_w + 10.0, by),
		Vector2(bx, by - half_h - 10.0),
		Vector2(bx, by + half_h + 10.0),
	]


func get_sector_barrier_x(next_bunker: Dictionary) -> float:
	return round(float(next_bunker["x"]) - get_bunker_lock_radius(next_bunker) - 20.0)


func is_bunker_locked(mode: String, bunker_index: int, current_bunker_index: int, wave_cleared: bool = false) -> bool:
	if mode == "tutorial":
		return bunker_index != 0
	if mode == "endless":
		return bunker_index != current_bunker_index
	var max_open := current_bunker_index + (1 if wave_cleared else 0)
	return bunker_index > max_open


func get_revive_station_coords(bunker: Dictionary) -> Dictionary:
	return {
		"x": float(bunker["x"]) + float(bunker.get("revive_offset_x", -320.0)),
		"y": float(bunker["y"]) + float(bunker.get("revive_offset_y", 0.0)),
		"radius": 44.0,
	}


func get_shop_station_coords(bunker: Dictionary) -> Dictionary:
	var bnd := get_bunker_bounds(bunker)
	return {
		"x": float(bunker["x"]) + round(float(bnd["half_w"]) * 0.5),
		"y": float(bunker["y"]) - round(float(bnd["half_h"]) * 0.48),
		"radius": 46.0,
	}


func get_maya_tower_coords(bunker: Dictionary, map_width: float, map_height: float) -> Vector2:
	var bnd := get_bunker_bounds(bunker)
	return Vector2(
		clampf(float(bunker["x"]) + float(bnd["half_w"]) + 76.0, 70.0, map_width - 70.0),
		clampf(float(bunker["y"]) - float(bnd["half_h"]) - 22.0, 75.0, map_height - 75.0)
	)


func get_endless_portal_coords(bunker: Dictionary, map_width: float, map_height: float) -> Dictionary:
	var bnd := get_bunker_bounds(bunker)
	return {
		"x": clampf(float(bunker["x"]) + float(bnd["half_w"]) + 84.0, 85.0, map_width - 85.0),
		"y": clampf(float(bunker["y"]) + float(bnd["half_h"]) - 8.0, 85.0, map_height - 85.0),
		"radius": 48.0,
	}


func should_spawn_endless_portal(wave: int) -> bool:
	return wave > 0 and wave % 10 == 0


func get_maya_upgrade_cost(current_level: int) -> int:
	return int(round(70.0 * float(maxi(1, current_level))))


func get_maya_tower_stats(level: int) -> Dictionary:
	var lvl := clampi(level, 1, MAX_MAYA_TOWER_LEVEL)
	return {
		"level": lvl,
		"max_hp": 160 + (lvl - 1) * 55,
		"damage": 18 + (lvl - 1) * 11,
		"fire_interval": snappedf(maxf(0.28, 0.68 - float(lvl - 1) * 0.09), 0.01),
		"range": 520.0 + float(lvl - 1) * 65.0,
		"projectiles_per_shot": 3 if lvl >= 5 else (2 if lvl >= 3 else 1),
	}


func resolve_circle_rect_collision(cx: float, cy: float, radius: float, rect: Rect2) -> Dictionary:
	var closest_x := clampf(cx, rect.position.x, rect.position.x + rect.size.x)
	var closest_y := clampf(cy, rect.position.y, rect.position.y + rect.size.y)
	var dx := cx - closest_x
	var dy := cy - closest_y
	var dist_sq := dx * dx + dy * dy
	if dist_sq >= radius * radius:
		return {"x": cx, "y": cy, "collided": false}
	var dist := sqrt(dist_sq)
	if dist > 0.0001:
		var overlap := radius - dist
		return {"x": cx + (dx / dist) * overlap, "y": cy + (dy / dist) * overlap, "collided": true}
	var left_pen := cx - rect.position.x
	var right_pen := rect.position.x + rect.size.x - cx
	var top_pen := cy - rect.position.y
	var bottom_pen := rect.position.y + rect.size.y - cy
	var min_pen := minf(minf(left_pen, right_pen), minf(top_pen, bottom_pen))
	if min_pen == left_pen:
		return {"x": rect.position.x - radius, "y": cy, "collided": true}
	if min_pen == right_pen:
		return {"x": rect.position.x + rect.size.x + radius, "y": cy, "collided": true}
	if min_pen == top_pen:
		return {"x": cx, "y": rect.position.y - radius, "collided": true}
	return {"x": cx, "y": rect.position.y + rect.size.y + radius, "collided": true}


func create_empty_skill_cooldowns() -> Dictionary:
	return {
		"grenade": 0.0, "machine_gun": 0.0, "tactical_clone": 0.0, "ranger_dash": 0.0,
		"ranger_ultimate": 0.0, "arcane_nova": 0.0, "frost_ring": 0.0, "healing_totem": 0.0, "medic_revive_ultimate": 0.0,
	}


func create_initial_skill_charges(hero_class: String = "ranger") -> Dictionary:
	return {
		"grenade": 1 if hero_class == "ranger" else 0,
		"machine_gun": 0, "tactical_clone": 0, "ranger_dash": 1, "ranger_ultimate": 0,
		"arcane_nova": 1 if hero_class == "medic" else 0,
		"frost_ring": 0, "healing_totem": 0, "medic_revive_ultimate": 0,
	}


func create_initial_skill_levels() -> Dictionary:
	return {
		"grenade": 1, "machine_gun": 1, "tactical_clone": 1, "ranger_dash": 1,
		"ranger_ultimate": 1, "arcane_nova": 1, "frost_ring": 1, "healing_totem": 1, "medic_revive_ultimate": 1,
	}


func is_skill_unlocked_at_wave(skill_id: String, wave: int, is_tutorial: bool = false) -> bool:
	if is_tutorial:
		return true
	var def: Dictionary = GameData.SKILLS.get(skill_id, {})
	if def.is_empty():
		return false
	return maxi(1, wave) >= int(def["unlock_wave"])


func get_skill_upgrade_cost(skill_id: String, current_level: int) -> int:
	var def: Dictionary = GameData.SKILLS[skill_id]
	return int(round(float(def["upgrade_cost_coins"]) * float(maxi(1, current_level))))


func get_skill_power_multiplier(skill_level: int, portal_realm: int = 1) -> float:
	var lvl_bonus := 1.0 + float(maxi(0, skill_level - 1)) * 0.25
	var realm_bonus := 1.0 + float(maxi(0, portal_realm - 1)) * 0.35
	return snappedf(lvl_bonus * realm_bonus, 0.001)


func can_use_skill(skill_id: String, wave: int, cooldown: float, mana: float, charges: int, is_tutorial: bool = false) -> Dictionary:
	var def: Dictionary = GameData.SKILLS.get(skill_id, {})
	if def.is_empty():
		return {"ok": false, "reason": "Invalid skill"}
	if not is_skill_unlocked_at_wave(skill_id, wave, is_tutorial):
		return {"ok": false, "reason": "Unlocks at Wave %d" % int(def["unlock_wave"])}
	if not is_tutorial and charges <= 0:
		return {"ok": false, "reason": "Out of stock — buy in Shop [B]"}
	if cooldown > 0.0:
		return {"ok": false, "reason": "Skill cooling down"}
	if mana < float(def["mana_cost"]):
		return {"ok": false, "reason": "Need %d Mana" % int(def["mana_cost"])}
	return {"ok": true, "reason": ""}


func validate_buy_skill_charge(skill_id: String, wave: int, coins: int, current_charges: int, is_tutorial: bool = false) -> Dictionary:
	var def: Dictionary = GameData.SKILLS.get(skill_id, {})
	if def.is_empty():
		return {"ok": false, "reason": "Invalid skill"}
	if not is_skill_unlocked_at_wave(skill_id, wave, is_tutorial):
		return {"ok": false, "reason": "Unlocks at Wave %d" % int(def["unlock_wave"])}
	if current_charges >= int(def["max_charges"]):
		return {"ok": false, "reason": "Max stock (%d)" % int(def["max_charges"])}
	if coins < int(def["charge_cost_coins"]):
		return {"ok": false, "reason": "Need %d Coins" % int(def["charge_cost_coins"])}
	return {"ok": true, "reason": ""}


func validate_upgrade_skill(skill_id: String, current_level: int, coins: int) -> Dictionary:
	var def: Dictionary = GameData.SKILLS.get(skill_id, {})
	if def.is_empty():
		return {"ok": false, "cost": 0, "reason": "Invalid skill"}
	var cost := get_skill_upgrade_cost(skill_id, current_level)
	if current_level >= int(def["max_upgrade_level"]):
		return {"ok": false, "cost": cost, "reason": "Max skill level reached"}
	if coins < cost:
		return {"ok": false, "cost": cost, "reason": "Need %d Coins" % cost}
	return {"ok": true, "cost": cost, "reason": ""}


func validate_shop_purchase(coins: int, stage_id: int, item: Dictionary) -> Dictionary:
	var eff := 5 if stage_id == 99 else stage_id
	if eff < int(item["min_stage"]):
		return {"ok": false, "reason": "Unlocks in Stage %d" % int(item["min_stage"])}
	if coins < int(item["cost_coins"]):
		return {"ok": false, "reason": "Need %d Coins" % int(item["cost_coins"])}
	return {"ok": true, "reason": ""}


func should_mark_afk(idle_seconds: float) -> bool:
	return idle_seconds >= 10.0


func get_stage_required_stars(stage_id: int) -> int:
	var reqs := {1: 0, 2: 1, 3: 2, 4: 3, 5: 4}
	return int(reqs.get(stage_id, 0))


func calculate_stage_stars(victory: bool, mode: String, stage_id: int, elapsed_seconds: int, damage_taken: int) -> int:
	if not victory or mode != "story":
		return 0
	var target := int(STAGE_TARGET_TIMES.get(stage_id, 260))
	if elapsed_seconds <= target and damage_taken <= 140:
		return 3
	if elapsed_seconds <= int(round(float(target) * 1.45)) or damage_taken <= 240:
		return 2
	return 1


func get_total_stars(stage_stars: Dictionary) -> int:
	var total := 0
	for s in range(1, 6):
		var v := int(stage_stars.get(str(s), stage_stars.get(s, 0)))
		if v > 0:
			total += mini(3, v)
	return total


func is_stage_unlocked(save: Dictionary, stage_id: int) -> bool:
	if stage_id <= 1:
		return true
	var unlocked: Array = save.get("unlocked_stages", [1])
	if not unlocked.has(stage_id):
		return false
	return get_total_stars(save.get("stage_stars", {})) >= get_stage_required_stars(stage_id)


func create_default_save_data(username: String = "Ranger", gender: String = "male", user_id: String = "local_player", hero_class: String = "ranger") -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"user_id": user_id,
		"username": username,
		"gender": gender,
		"hero_class": hero_class,
		"level": 1,
		"experience": 0,
		"survival_points": 150,
		"boss_tokens": 0,
		"unlocked_stages": [1],
		"completed_stages": [],
		"stage_stars": {},
		"antidote_secured": false,
		"antidote_delivered": false,
		"last_task_type": "",
		"unlocked_weapons": ["basic_pistol", "basic_wand"],
		"equipped_weapons": ["basic_pistol", "basic_wand"],
		"weapon_upgrades": {},
		"statistics": {
			"zombie_kills": 0,
			"boss_defeats": 0,
			"highest_wave": 0,
			"matches_played": 0,
			"total_points_earned": 0,
		},
		"updated_at": int(Time.get_unix_time_from_system()),
	}


func migrate_save_data(raw: Variant) -> Dictionary:
	var base := create_default_save_data()
	if typeof(raw) != TYPE_DICTIONARY:
		return base
	var data: Dictionary = raw
	var unlocked_weapons: Array = []
	for id_val in data.get("unlocked_weapons", base["unlocked_weapons"]):
		var sid := str(id_val)
		if GameData.WEAPONS.has(sid) and not unlocked_weapons.has(sid):
			unlocked_weapons.append(sid)
	if not unlocked_weapons.has("basic_pistol"):
		unlocked_weapons.append("basic_pistol")
	if not unlocked_weapons.has("basic_wand"):
		unlocked_weapons.append("basic_wand")

	var raw_eq: Array = data.get("equipped_weapons", ["basic_pistol", "basic_wand"])
	var eq0 := "basic_pistol"
	if raw_eq.size() >= 1 and unlocked_weapons.has(str(raw_eq[0])) and str(GameData.WEAPONS[str(raw_eq[0])]["category"]) == "pistol":
		eq0 = str(raw_eq[0])
	var eq1 := "basic_wand"
	if raw_eq.size() >= 2 and unlocked_weapons.has(str(raw_eq[1])) and str(GameData.WEAPONS[str(raw_eq[1])]["category"]) == "magic":
		eq1 = str(raw_eq[1])

	var unlocked_stages: Array = [1]
	for st in data.get("unlocked_stages", [1]):
		var si := int(st)
		if si >= 1 and si <= 5 and not unlocked_stages.has(si):
			unlocked_stages.append(si)
	unlocked_stages.sort()

	var completed_stages: Array = []
	for st in data.get("completed_stages", []):
		var si := int(st)
		if si >= 1 and si <= 5 and not completed_stages.has(si):
			completed_stages.append(si)

	var stage_stars: Dictionary = {}
	var raw_stars = data.get("stage_stars", {})
	if typeof(raw_stars) == TYPE_DICTIONARY:
		for s in range(1, 6):
			var v := int(raw_stars.get(str(s), raw_stars.get(s, 0)))
			if v >= 1:
				stage_stars[str(s)] = mini(3, v)
	for s in completed_stages:
		if not stage_stars.has(str(s)):
			stage_stars[str(s)] = 1

	var xp := maxi(0, int(data.get("experience", 0)))
	var lvl_info := compute_level_from_xp(xp)
	var stats_in: Dictionary = data.get("statistics", {}) if typeof(data.get("statistics", {})) == TYPE_DICTIONARY else {}
	var saved_class := str(data.get("hero_class", "ranger"))

	return {
		"version": SAVE_VERSION,
		"user_id": str(data.get("user_id", base["user_id"])) if str(data.get("user_id", "")) != "" else base["user_id"],
		"username": str(data.get("username", base["username"])) if str(data.get("username", "")) != "" else base["username"],
		"gender": "female" if str(data.get("gender", "male")) == "female" else "male",
		"hero_class": "medic" if saved_class in ["mage", "medic"] else "ranger",
		"level": int(lvl_info["level"]),
		"experience": xp,
		"survival_points": maxi(0, int(data.get("survival_points", base["survival_points"]))),
		"boss_tokens": maxi(0, int(data.get("boss_tokens", 0))),
		"unlocked_stages": unlocked_stages,
		"completed_stages": completed_stages,
		"stage_stars": stage_stars,
		"antidote_secured": bool(data.get("antidote_secured", completed_stages.has(1))),
		"antidote_delivered": bool(data.get("antidote_delivered", completed_stages.has(5))),
		"last_task_type": str(data.get("last_task_type", "")) if str(data.get("last_task_type", "")) in ["repair", "supply", "rescue"] else "",
		"unlocked_weapons": unlocked_weapons,
		"equipped_weapons": [eq0, eq1],
		"weapon_upgrades": data.get("weapon_upgrades", {}) if typeof(data.get("weapon_upgrades", {})) == TYPE_DICTIONARY else {},
		"statistics": {
			"zombie_kills": int(stats_in.get("zombie_kills", 0)),
			"boss_defeats": int(stats_in.get("boss_defeats", 0)),
			"highest_wave": int(stats_in.get("highest_wave", 0)),
			"matches_played": int(stats_in.get("matches_played", 0)),
			"total_points_earned": int(stats_in.get("total_points_earned", 0)),
		},
		"updated_at": int(data.get("updated_at", Time.get_unix_time_from_system())),
	}
