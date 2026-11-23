extends Control

signal closed

@onready var balance_label: Label = $Center/Panel/Margin/VBox/Header/BalanceLabel
@onready var close_btn: Button = $Center/Panel/Margin/VBox/Header/CloseBtn
@onready var pistol_tab: Button = $Center/Panel/Margin/VBox/Tabs/PistolTab
@onready var magic_tab: Button = $Center/Panel/Margin/VBox/Tabs/MagicTab
@onready var notice_label: Label = $Center/Panel/Margin/VBox/NoticeLabel
@onready var list_box: VBoxContainer = $Center/Panel/Margin/VBox/Scroll/List

var _category: String = "pistol"


func _ready() -> void:
	magic_tab.text = "Medic Energy Weapons"
	close_btn.pressed.connect(func() -> void:
		hide()
		closed.emit()
	)
	pistol_tab.pressed.connect(func() -> void:
		_category = "pistol"
		_rebuild()
	)
	magic_tab.pressed.connect(func() -> void:
		_category = "magic"
		_rebuild()
	)
	SaveManager.save_changed.connect(func(_s: Dictionary) -> void:
		if visible:
			_rebuild()
	)


func open_modal(initial_category: String = "") -> void:
	if initial_category != "":
		_category = initial_category
	else:
		_category = "magic" if str(SaveManager.save_data.get("hero_class", "ranger")) == "medic" else "pistol"
	notice_label.hide()
	_rebuild()
	show()


func _rebuild() -> void:
	var save := SaveManager.save_data
	balance_label.text = "%d SP · %d Boss Tokens" % [int(save.get("survival_points", 0)), int(save.get("boss_tokens", 0))]
	pistol_tab.modulate = Color("#FFFFFF") if _category == "pistol" else Color("#94A3B8")
	magic_tab.modulate = Color("#FFFFFF") if _category == "magic" else Color("#94A3B8")

	for c in list_box.get_children():
		c.queue_free()

	var unlocked: Array = save.get("unlocked_weapons", [])
	var equipped: Array = save.get("equipped_weapons", ["basic_pistol", "basic_wand"])
	var upgrades: Dictionary = save.get("weapon_upgrades", {})

	for wid in GameData.WEAPON_ORDER:
		var def: Dictionary = GameData.WEAPONS[wid]
		if str(def["category"]) != _category:
			continue
		var is_unlocked := unlocked.has(wid)
		var is_equipped := equipped.has(wid)
		var up_lvl := int(upgrades.get(wid, 0))
		var eff := GameRules.compute_effective_weapon_stats(wid, up_lvl)

		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#16202C") if not is_equipped else Color("#182838")
		sb.border_color = Color("#F59E0B") if is_equipped else Color("#2C3B4E")
		sb.set_border_width_all(2 if is_equipped else 1)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(12)
		card.add_theme_stylebox_override("panel", sb)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		row.add_child(info)

		var title := Label.new()
		var parent_txt := ""
		if str(def["parent_id"]) != "":
			parent_txt = " · Requires %s" % str(GameData.WEAPONS[str(def["parent_id"])]["name"])
		title.text = "Tier %d · %s (+%d)%s" % [int(def["tier"]), str(def["name"]), up_lvl, parent_txt]
		title.add_theme_color_override("font_color", Color(str(def["color"])))
		title.add_theme_font_size_override("font_size", 16)
		info.add_child(title)

		var stats := Label.new()
		stats.text = "%s | DMG %d | Rate %.1f/s | Crit %d%% | Pierce %d" % [
			str(def["role"]),
			int(eff["damage"]),
			float(eff["fire_rate"]),
			int(round(float(eff["crit_chance"]) * 100.0)),
			int(eff["penetration"]),
		]
		stats.add_theme_color_override("font_color", Color("#94A3B8"))
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(stats)

		var btns := HBoxContainer.new()
		btns.add_theme_constant_override("separation", 8)
		row.add_child(btns)

		if is_unlocked:
			var eq_btn := Button.new()
			eq_btn.custom_minimum_size = Vector2(108, 42)
			eq_btn.text = "EQUIPPED" if is_equipped else "Equip"
			eq_btn.disabled = is_equipped
			eq_btn.pressed.connect(func() -> void: _on_equip(wid, _category))
			btns.add_child(eq_btn)

			var up_btn := Button.new()
			up_btn.custom_minimum_size = Vector2(146, 42)
			if up_lvl >= GameRules.MAX_WEAPON_UPGRADE_LEVEL:
				up_btn.text = "MAX LEVEL"
				up_btn.disabled = true
			else:
				var cost := GameRules.get_weapon_upgrade_cost(wid, up_lvl)
				up_btn.text = "Upgrade (%d SP)" % cost
				up_btn.disabled = int(save.get("survival_points", 0)) < cost
				up_btn.pressed.connect(func() -> void: _on_upgrade(wid))
			btns.add_child(up_btn)
		else:
			var check := GameRules.can_unlock_weapon(save, wid)
			var unlock_btn := Button.new()
			unlock_btn.custom_minimum_size = Vector2(180, 42)
			var tok_txt := " + %d Tok" % int(def["cost_tokens"]) if int(def["cost_tokens"]) > 0 else ""
			unlock_btn.text = "Unlock (%d SP%s)" % [int(def["cost_points"]), tok_txt]
			unlock_btn.disabled = not bool(check["ok"])
			if not bool(check["ok"]):
				unlock_btn.tooltip_text = str(check["reason"])
			unlock_btn.pressed.connect(func() -> void: _on_unlock(wid))
			btns.add_child(unlock_btn)

		list_box.add_child(card)


func _on_equip(wid: String, cat: String) -> void:
	var next := SaveManager.save_data.duplicate(true)
	var eq: Array = next["equipped_weapons"]
	if cat == "pistol":
		eq[0] = wid
	else:
		eq[1] = wid
	next["updated_at"] = int(Time.get_unix_time_from_system())
	SaveManager.write_save(next)
	NetworkManager.sync_save_to_cloud(next)
	AudioManager.play_pickup()
	notice_label.hide()


func _on_unlock(wid: String) -> void:
	var res := GameRules.apply_weapon_unlock(SaveManager.save_data, wid)
	if not bool(res["ok"]):
		notice_label.text = str(res["reason"])
		notice_label.show()
		return
	SaveManager.write_save(res["next_save"])
	NetworkManager.sync_save_to_cloud(res["next_save"])
	AudioManager.play_victory()
	notice_label.hide()


func _on_upgrade(wid: String) -> void:
	var res := GameRules.apply_weapon_upgrade(SaveManager.save_data, wid)
	if not bool(res["ok"]):
		notice_label.text = str(res["reason"])
		notice_label.show()
		return
	SaveManager.write_save(res["next_save"])
	NetworkManager.sync_save_to_cloud(res["next_save"])
	AudioManager.play_skill()
	notice_label.hide()
