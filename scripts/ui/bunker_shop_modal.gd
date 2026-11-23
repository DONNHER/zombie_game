extends Control

signal buy_item(item_id: String)
signal buy_skill_charge(skill_id: String)
signal upgrade_skill(skill_id: String)
signal upgrade_maya_tower
signal closed

const ITEM_COPY := {
	"ammo_medkit": ["+", "Reload your weapon and patch yourself up."],
	"build_wall": ["▤", "Put a barrier between the horde and the bunker."],
	"build_spike": ["▲", "Slow zombies down and hurt them as they pass."],
	"build_turret": ["⊕", "Let a sentry cover the bunker for you."],
	"damage_boost": ["»", "Make your shots and spells hit harder."],
	"armor_plate": ["◆", "Take more hits and recover some health."],
	"mana_core": ["ϟ", "Cast more spells and refill your mana."],
	"revive_kit": ["♥", "Get downed teammates back on their feet."],
	"grenade": ["✹", "Blast a group of zombies at once."],
	"machine_gun": ["≡", "Overwhelm the horde with rapid fire."],
	"tactical_clone": ["▦", "Call in reinforcements to fight beside you."],
	"ranger_dash": ["»", "Dodge danger and get clear fast."],
	"ranger_ultimate": ["✦", "Unleash heavy fire in every direction."],
	"arcane_nova": ["◎", "Push nearby zombies back with a magic blast."],
	"frost_ring": ["✳", "Slow nearby zombies so you can get away."],
	"healing_totem": ["+", "Heal yourself and shake off slowing effects."],
	"arcane_cataclysm": ["ϟ", "Rain meteors and lightning on the horde."],
	"medic_revive_ultimate": ["♥", "Choose a downed teammate and bring them back into the fight."],
}

const TEXT_COLOR := Color("#F1F5F0")
const MUTED_COLOR := Color("#B1C1BC")
const GOLD := Color("#F5CE79")
const PANEL_SIZE := Vector2(930, 596)
const PANEL_INSET := Vector2(32, 32)
const COMPACT_WIDTH := 790.0
const COMPACT_MAX_HEIGHT := 900.0

@onready var panel: PanelContainer = $Center/Panel
@onready var coins_label: Label = $Center/Panel/Margin/VBox/Header/CoinsLabel
@onready var close_btn: Button = $Center/Panel/Margin/VBox/Header/CloseBtn
@onready var supply_tab: Button = $Center/Panel/Margin/VBox/Tabs/SupplyTab
@onready var skills_tab: Button = $Center/Panel/Margin/VBox/Tabs/SkillsTab
@onready var maya_tab: Button = $Center/Panel/Margin/VBox/Tabs/MayaTab
@onready var notice_label: Label = $Center/Panel/Margin/VBox/NoticeLabel
@onready var scroll: ScrollContainer = $Center/Panel/Margin/VBox/Scroll
@onready var list_box: VBoxContainer = $Center/Panel/Margin/VBox/Scroll/List

var _tab := "supply"
var _snap: Dictionary = {}
var _open_details: Dictionary = {}
var _compact := false


func _ready() -> void:
	close_btn.pressed.connect(func() -> void:
		hide()
		closed.emit()
	)
	supply_tab.pressed.connect(_select_tab.bind("supply"))
	skills_tab.pressed.connect(_select_tab.bind("skills"))
	maya_tab.pressed.connect(_select_tab.bind("maya"))
	_style_button(close_btn, MUTED_COLOR)
	close_btn.tooltip_text = "Close shop"
	resized.connect(_fit_panel)
	_fit_panel()


func _fit_panel() -> void:
	var available := size - PANEL_INSET
	var compact := available.x < COMPACT_WIDTH
	var maximum := Vector2(PANEL_SIZE.x, COMPACT_MAX_HEIGHT if compact else PANEL_SIZE.y)
	panel.custom_minimum_size = available.clamp(Vector2.ZERO, maximum)
	if _compact != compact:
		_compact = compact
		if not _snap.is_empty():
			_rebuild()


func _select_tab(tab: String) -> void:
	if _tab == tab:
		return
	_tab = tab
	_open_details.clear()
	scroll.scroll_vertical = 0
	_rebuild()


func open_shop(snapshot: Dictionary) -> void:
	_snap = snapshot
	_open_details.clear()
	scroll.scroll_vertical = 0
	notice_label.hide()
	_rebuild()
	show()


func refresh_snapshot(snapshot: Dictionary) -> void:
	_snap = snapshot
	if visible:
		_rebuild()


func show_feedback(msg: String) -> void:
	notice_label.text = msg
	notice_label.show()


func _rebuild() -> void:
	coins_label.text = "%d Coins" % int(_snap.get("coins", 0))
	_style_button(supply_tab, GOLD, _tab == "supply")
	_style_button(skills_tab, GOLD, _tab == "skills")
	_style_button(maya_tab, GOLD, _tab == "maya")

	for card in list_box.get_children():
		list_box.remove_child(card)
		card.queue_free()

	match _tab:
		"supply":
			_build_supplies()
		"skills":
			_build_skills()
		"maya":
			_build_maya()


func _build_supplies() -> void:
	var coins := int(_snap.get("coins", 0))
	var stage_id := int(_snap.get("stage_id", 1))
	for id in GameData.BUNKER_SHOP_ORDER:
		if id == "revive_kit" and not bool(_snap.get("online", false)):
			continue
		var item: Dictionary = GameData.BUNKER_SHOP_ITEMS[id]
		var check := GameRules.validate_shop_purchase(coins, stage_id, item)
		var requirements := "Available from Stage %d" % int(item["min_stage"])
		if id == "revive_kit":
			requirements += "  ·  Online co-op"
		if not bool(check["ok"]) and str(check["reason"]).begins_with("Need"):
			requirements += "  ·  " + str(check["reason"])
		var copy: Array = ITEM_COPY.get(id, ["•", ""])
		var inventory: Dictionary = _snap.get("inventory", {})
		var stocked := int(inventory.get(id, 0))
		var details := "%s\n%s" % [str(item["description"]), requirements]
		var benefit := str(copy[1])
		if id in ["ammo_medkit", "build_wall", "build_spike", "build_turret", "revive_kit"]:
			benefit += "  In bag: %d. Tap its button beside Shop to use." % stocked
		var row := _add_card(id, str(copy[0]), str(item["name"]), benefit, Color(str(item["color"])), details)
		var price := int(item["cost_coins"])
		var action := "Buy"
		_add_action(row, "%s · %d Coins" % [action, price], check, buy_item.emit.bind(id), true)


func _build_skills() -> void:
	var coins := int(_snap.get("coins", 0))
	var wave := int(_snap.get("wave", 1))
	var tutorial := bool(_snap.get("is_tutorial", false))
	var charges: Dictionary = _snap.get("skill_charges", {})
	var levels: Dictionary = _snap.get("skill_levels", {})
	for id: String in GameData.CLASS_SKILLS.get(str(_snap.get("hero_class", "ranger")), []):
		var skill: Dictionary = GameData.SKILLS[id]
		var charge_count := int(charges.get(id, 0))
		var level := int(levels.get(id, 1))
		var max_level := int(skill["max_upgrade_level"])
		var charge_check := GameRules.validate_buy_skill_charge(id, wave, coins, charge_count, tutorial)
		var upgrade_check := GameRules.validate_upgrade_skill(id, level, coins)
		var details := "%s\nRank %d/%d  ·  Charges %d/%d  ·  Base cooldown %ss  ·  Mana %d\nUnlocks at Wave %d" % [
			str(skill["description"]), level, max_level, charge_count, int(skill["max_charges"]),
			str(skill["cooldown"]), int(skill["mana_cost"]), int(skill["unlock_wave"]),
		]
		if not bool(charge_check["ok"]):
			details += "\nCharge: " + str(charge_check["reason"])
		if not bool(upgrade_check["ok"]) and level < max_level:
			details += "\nRank up: " + str(upgrade_check["reason"])
		var copy: Array = ITEM_COPY.get(id, ["•", ""])
		var row := _add_card(id, str(copy[0]), str(skill["name"]), str(copy[1]), Color(str(skill["color"])), details)
		_add_action(row, "+1 Charge · %d Coins" % int(skill["charge_cost_coins"]), charge_check, buy_skill_charge.emit.bind(id), true)
		var upgrade_text := "Max rank" if level >= max_level else "Rank Up · %d Coins" % int(upgrade_check["cost"])
		_add_action(row, upgrade_text, upgrade_check, upgrade_skill.emit.bind(id))


func _build_maya() -> void:
	var level := int(_snap.get("maya_level", 1))
	var max_level := GameRules.MAX_MAYA_TOWER_LEVEL
	var stats := GameRules.get_maya_tower_stats(level)
	var unavailable := bool(_snap.get("maya_infected", false))
	var benefit := "Strengthen Maya's tower and give her more firepower."
	var details := "Level %d/%d  ·  Health %d  ·  Rifle damage %d  ·  Shots x%d  ·  Range %dm\nMaya defends from her watchtower. Online squadmates can revive downed allies." % [
		level, max_level, int(stats["max_hp"]), int(stats["damage"]),
		int(stats["projectiles_per_shot"]), int(stats["range"]),
	]
	if unavailable:
		benefit = "Maya's watchtower is offline."
		details = "Maya is infected. Her watchtower can no longer be upgraded."
	var row := _add_card("maya", "⌂", "Scout Maya Watchtower", benefit, GOLD if not unavailable else Color("#F87171"), details)
	if unavailable:
		_add_action(row, "Tower Offline", {"ok": false}, upgrade_maya_tower.emit, true)
	elif level >= max_level:
		_add_action(row, "Max Level", {"ok": false}, upgrade_maya_tower.emit, true)
	else:
		var cost := GameRules.get_maya_upgrade_cost(level)
		var check := {"ok": int(_snap.get("coins", 0)) >= cost, "reason": "Need %d Coins" % cost}
		_add_action(row, "Upgrade · %d Coins" % cost, check, upgrade_maya_tower.emit, true)


func _add_card(id: String, icon: String, title: String, benefit: String, accent: Color, details: String) -> HBoxContainer:
	var panel := PanelContainer.new()
	var surface := _box(Color("#1A2927"), Color("#31433C"), 10)
	surface.border_width_left = 3
	surface.border_color = accent.darkened(0.48)
	surface.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", surface)
	list_box.add_child(panel)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(52, 52)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", _box(accent.darkened(0.82), accent.darkened(0.55), 8))
	var glyph := _label(icon, 27, accent.lightened(0.18))
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(glyph)
	row.add_child(badge)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	info.add_child(_label(title, 20, TEXT_COLOR))
	info.add_child(_label(benefit, 16, MUTED_COLOR))
	row.add_child(info)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _compact:
		body.add_child(actions)
	else:
		row.add_child(actions)

	var toggle := Button.new()
	toggle.custom_minimum_size = Vector2(105, 44)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_button(toggle, MUTED_COLOR)
	actions.add_child(toggle)

	var inset := PanelContainer.new()
	var inset_style := _box(Color("#111C1A"), Color("#2E4339"), 7)
	inset_style.set_content_margin_all(12.0)
	inset.add_theme_stylebox_override("panel", inset_style)
	var detail_label := _label(details, 16, MUTED_COLOR)
	detail_label.add_theme_constant_override("line_spacing", 4)
	inset.add_child(detail_label)
	body.add_child(inset)

	inset.visible = _open_details.has(id)
	toggle.text = "Hide Details" if inset.visible else "Details"
	toggle.pressed.connect(func() -> void:
		inset.visible = not inset.visible
		if inset.visible:
			_open_details[id] = true
			_scroll_to_details(inset)
		else:
			_open_details.erase(id)
		toggle.text = "Hide Details" if inset.visible else "Details"
	)
	return actions


func _scroll_to_details(inset: PanelContainer) -> void:
	await get_tree().process_frame
	if is_instance_valid(inset) and scroll.is_ancestor_of(inset) and inset.is_visible_in_tree():
		scroll.ensure_control_visible(inset)


func _add_action(row: HBoxContainer, title: String, check: Dictionary, action: Callable, primary: bool = false) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 44)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.text = title
	button.disabled = not bool(check["ok"])
	if button.disabled:
		button.tooltip_text = str(check.get("reason", ""))
	button.pressed.connect(action)
	_style_button(button, GOLD, primary)
	row.add_child(button)


func _style_button(button: Button, color: Color, primary: bool = false) -> void:
	var background := color if primary else Color("#24342E")
	var text := Color("#182018") if primary else TEXT_COLOR
	button.add_theme_stylebox_override("normal", _button_box(background, color.darkened(0.4)))
	button.add_theme_stylebox_override("hover", _button_box(background.lightened(0.14), color))
	button.add_theme_stylebox_override("pressed", _button_box(background.darkened(0.12), color))
	button.add_theme_stylebox_override("disabled", _button_box(Color("#212E2A"), Color("#36443E")))
	var focus := _button_box(Color.TRANSPARENT, Color("#F2EEE0"))
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_hover_color", text)
	button.add_theme_color_override("font_pressed_color", text)
	button.add_theme_color_override("font_focus_color", text)
	button.add_theme_color_override("font_disabled_color", Color("#9BAC9F"))
	button.add_theme_font_size_override("font_size", 16)


func _button_box(background: Color, border: Color) -> StyleBoxFlat:
	var style := _box(background, border, 8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style


func _box(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _label(value: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	return label
