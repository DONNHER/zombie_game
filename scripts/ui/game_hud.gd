extends Control

signal shop_pressed
signal pause_pressed
signal restart_pressed
signal next_wave_pressed
signal skill_pressed(skill_id: String)
signal revive_target_selected(user_id: String)
signal settings_pressed
signal help_toggled(open: bool)
signal item_use_pressed(item_id: String)

const SKILL_POSITIONS := [Vector2(-360, -235), Vector2(-288, -255), Vector2(-216, -255), Vector2(-144, -235), Vector2(-220, -165)]
const ITEM_ICONS := {"ammo_medkit": "+", "build_wall": "▤", "build_spike": "▲", "build_turret": "⊕", "revive_kit": "♥"}
const ITEM_NAMES := {"ammo_medkit": "Aid", "build_wall": "Wall", "build_spike": "Spike", "build_turret": "Turret", "revive_kit": "Defib"}

const SKILL_BUTTON_NAMES := {
	"arcane_nova": "Repulse",
	"frost_ring": "Cryo Ring",
	"ranger_dash": "Dash",
	"healing_totem": "Medkit",
	"medic_revive_ultimate": "Revive Ally",
	"tactical_clone": "Clone",
	"ranger_ultimate": "Heavy Barrage",
}
@onready var top_margin: MarginContainer = $TopMargin
@onready var stats_card: PanelContainer = $TopMargin/TopRow/StatsCard
@onready var center_card: PanelContainer = $TopMargin/TopRow/CenterCard
@onready var top_spacer: Control = $TopMargin/TopRow/TopSpacer
@onready var hero_lbl: Label = $TopMargin/TopRow/StatsCard/StatsVBox/HeroLbl
@onready var hp_bar: ProgressBar = $TopMargin/TopRow/StatsCard/StatsVBox/HpBar
@onready var sec_lbl: Label = $TopMargin/TopRow/StatsCard/StatsVBox/SecLbl
@onready var economy_lbl: Label = $TopMargin/TopRow/StatsCard/StatsVBox/EconomyLbl
@onready var squad_lbl: Label = $TopMargin/TopRow/StatsCard/StatsVBox/SquadLbl

@onready var stage_wave_lbl: Label = $TopMargin/TopRow/CenterCard/CenterVBox/StageWaveLbl
@onready var goal_lbl: Label = $TopMargin/TopRow/CenterCard/CenterVBox/GoalLbl
@onready var center_vbox: VBoxContainer = $TopMargin/TopRow/CenterCard/CenterVBox
@onready var clock_lbl: Label = $TopMargin/TopRow/CenterCard/CenterVBox/ClockLbl
@onready var boss_box: VBoxContainer = $TopMargin/TopRow/CenterCard/CenterVBox/BossBox
@onready var boss_name_lbl: Label = $TopMargin/TopRow/CenterCard/CenterVBox/BossBox/BossNameLbl
@onready var boss_bar: ProgressBar = $TopMargin/TopRow/CenterCard/CenterVBox/BossBox/BossBar

@onready var details_btn: Button = $TopMargin/TopRow/RightBtns/DetailsBtn
@onready var help_btn: Button = $TopMargin/TopRow/RightBtns/HelpBtn
@onready var settings_btn: Button = $TopMargin/TopRow/RightBtns/SettingsBtn
@onready var settings_menu: PanelContainer = $SettingsMenu
@onready var mute_btn: Button = $SettingsMenu/MenuVBox/MuteBtn
@onready var restart_btn: Button = $SettingsMenu/MenuVBox/RestartBtn
@onready var pause_btn: Button = $SettingsMenu/MenuVBox/PauseBtn
@onready var options_btn: Button = $SettingsMenu/MenuVBox/OptionsBtn
@onready var shop_btn: Button = $BottomShop/ShopBtn

@onready var tutorial_card: PanelContainer = $BannerStack/TutorialCard
@onready var tut_lbl: Label = $BannerStack/TutorialCard/TutLbl
@onready var next_wave_btn: Button = $BannerStack/NextWaveBtn
@onready var toast_lbl: Label = $BannerStack/ToastLbl
@onready var skill_bar: Control = $BottomMargin/SkillBar
@onready var skill_popup: Control = $BottomMargin
@onready var inventory_bar: HBoxContainer = $InventoryBar
@onready var touch_controls: Control = $TouchControls

var _skill_buttons: Dictionary = {}
var _glow_time: float = 0.0
var _toast_timer: float = 0.0
var _task_lbl: Label
var _antidote_lbl: Label
var _revive_overlay: ColorRect
var _revive_list: VBoxContainer
var _revive_targets: Array = []
var _help_overlay: ColorRect
var _details_expanded: bool = true
var _last_inventory: Dictionary = {}


func _ready() -> void:
	_build_revive_picker()
	_build_help()
	_task_lbl = Label.new()
	_task_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task_lbl.add_theme_font_size_override("font_size", 13)
	center_vbox.add_child(_task_lbl)
	center_vbox.move_child(_task_lbl, 2)
	_task_lbl.hide()
	_antidote_lbl = Label.new()
	_antidote_lbl.add_theme_font_size_override("font_size", 12)
	_antidote_lbl.add_theme_color_override("font_color", Color("#67E8F9"))
	center_vbox.add_child(_antidote_lbl)
	center_vbox.move_child(_antidote_lbl, 3)
	_antidote_lbl.hide()
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.06, 0.09, 0.13, 0.84)
	card_sb.border_color = Color(0.20, 0.27, 0.36, 0.90)
	card_sb.set_border_width_all(1)
	card_sb.set_corner_radius_all(8)
	card_sb.set_content_margin_all(8)
	stats_card.add_theme_stylebox_override("panel", card_sb)
	center_card.add_theme_stylebox_override("panel", card_sb.duplicate())
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color("#EF4444")
	hp_fill.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hero_lbl.add_theme_color_override("font_color", Color("#FCA5A5"))
	settings_btn.draw.connect(_draw_settings_icon)
	settings_btn.queue_redraw()

	var nw_sb := StyleBoxFlat.new()
	nw_sb.bg_color = Color("#22C55E")
	nw_sb.set_corner_radius_all(8)
	next_wave_btn.add_theme_stylebox_override("normal", nw_sb)
	next_wave_btn.add_theme_color_override("font_color", Color("#0F172A"))

	shop_btn.pressed.connect(func() -> void: settings_menu.hide(); shop_pressed.emit())
	pause_btn.pressed.connect(func() -> void: settings_menu.hide(); pause_pressed.emit())
	restart_btn.pressed.connect(func() -> void: settings_menu.hide(); restart_pressed.emit())
	options_btn.pressed.connect(func() -> void: settings_menu.hide(); settings_pressed.emit())
	settings_btn.pressed.connect(func() -> void: settings_menu.visible = not settings_menu.visible)
	details_btn.pressed.connect(_toggle_details)
	help_btn.pressed.connect(func() -> void: settings_menu.hide(); _help_overlay.show(); help_toggled.emit(true))
	next_wave_btn.pressed.connect(func() -> void: next_wave_pressed.emit())
	mute_btn.pressed.connect(func() -> void:
		var muted := not bool(SaveManager.settings.get("muted", false))
		SaveManager.write_settings({"muted": muted})
		_sync_mute_text()
	)
	_sync_mute_text()


func _draw_settings_icon() -> void:
	var center := settings_btn.size * 0.5
	var color := Color("#E2E8F0")
	settings_btn.draw_arc(center, 10.0, 0.0, TAU, 24, color, 3.0, true)
	settings_btn.draw_circle(center, 3.0, color)
	for i in range(8):
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
		settings_btn.draw_line(center + dir * 10.0, center + dir * 14.0, color, 3.0, true)


func _toggle_details() -> void:
	_details_expanded = not _details_expanded
	center_card.visible = _details_expanded
	top_spacer.visible = not _details_expanded
	sec_lbl.visible = _details_expanded
	economy_lbl.visible = _details_expanded
	squad_lbl.visible = _details_expanded and not squad_lbl.text.is_empty()
	top_margin.offset_bottom = 148.0 if _details_expanded else 62.0
	details_btn.text = "−" if _details_expanded else "+"


func _build_help() -> void:
	_help_overlay = ColorRect.new()
	_help_overlay.color = Color(0.02, 0.04, 0.06, 0.88)
	_help_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_help_overlay)
	_help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_help_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var label := Label.new()
	label.text = "HOW TO PLAY\n\nMove with the joystick. Hold FIRE to shoot; weapons reload automatically.\n\nTap the skill icons near FIRE to use stocked skills. Buy charges in the SHOP.\n\nTap stocked items beside SHOP to use them.\n\nComplete the stage task before the final wave. The sector opens when preparation ends.\n\nUse the gear for pause, sound, retry and settings."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size.y = 48
	close.pressed.connect(func() -> void: _help_overlay.hide(); help_toggled.emit(false))
	box.add_child(close)
	_help_overlay.hide()


func _process(delta: float) -> void:
	_glow_time += delta
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_lbl.hide()


func _sync_mute_text() -> void:
	var muted := bool(SaveManager.settings.get("muted", false))
	mute_btn.text = "MUTED" if muted else "SFX ON"


func show_toast(msg: String, duration: float = 2.6) -> void:
	toast_lbl.text = msg
	toast_lbl.show()
	_toast_timer = duration


func configure_skills(hero_class: String) -> void:
	skill_popup.show()
	settings_menu.hide()
	for c in skill_bar.get_children():
		skill_bar.remove_child(c)
		c.queue_free()
	_skill_buttons.clear()
	var sids: Array = GameData.CLASS_SKILLS.get(hero_class, [])
	for index in range(mini(sids.size(), SKILL_POSITIONS.size())):
		var sid_v = sids[index]
		var sid := str(sid_v)
		var def: Dictionary = GameData.SKILLS[sid]
		var btn := Button.new()
		btn.anchor_left = 1.0
		btn.anchor_top = 1.0
		btn.anchor_right = 1.0
		btn.anchor_bottom = 1.0
		btn.offset_left = SKILL_POSITIONS[index].x
		btn.offset_top = SKILL_POSITIONS[index].y
		btn.offset_right = SKILL_POSITIONS[index].x + 68.0
		btn.offset_bottom = SKILL_POSITIONS[index].y + 68.0
		btn.add_theme_font_size_override("font_size", 10)
		btn.text = "\n\n" + str(def["name"])
		btn.tooltip_text = str(def["name"])
		btn.add_theme_color_override("font_color", Color("#F8FAFC"))
		var shape := StyleBoxFlat.new()
		shape.bg_color = Color("#152B31")
		shape.border_color = Color(str(def["color"]))
		shape.set_border_width_all(2)
		shape.set_corner_radius_all(25)
		btn.add_theme_stylebox_override("normal", shape)
		var disabled_shape := shape.duplicate()
		disabled_shape.bg_color = Color("#273037")
		disabled_shape.border_color = Color("#59656A")
		btn.add_theme_stylebox_override("disabled", disabled_shape)
		btn.pressed.connect(func() -> void: _on_skill_button_pressed(sid))
		btn.draw.connect(_draw_skill_icon.bind(btn, sid))
		skill_bar.add_child(btn)
		_skill_buttons[sid] = btn
	_last_inventory.clear()
	_refresh_inventory({})


func _on_skill_button_pressed(skill_id: String) -> void:
	if skill_id == "medic_revive_ultimate":
		_open_revive_picker()
		return
	skill_pressed.emit(skill_id)


func _draw_skill_icon(btn: Button, sid: String) -> void:
	var c := Vector2(btn.size.x * 0.5, 22.0)
	var color := Color(str(GameData.SKILLS[sid]["color"])) if not btn.disabled else Color("#819096")
	btn.draw_circle(c, 14.0, Color(color, 0.18))
	match sid:
		"grenade":
			btn.draw_circle(c + Vector2(0, 2), 8.0, color)
			btn.draw_rect(Rect2(c.x - 4, c.y - 10, 8, 4), color)
		"machine_gun":
			for i in range(3):
				btn.draw_line(c + Vector2(-10, -5 + i * 5), c + Vector2(10, -5 + i * 5), color, 3.0)
		"tactical_clone":
			for dx in [-6.0, 6.0]:
				btn.draw_circle(c + Vector2(dx, -5), 4.0, color)
				btn.draw_line(c + Vector2(dx, 1), c + Vector2(dx, 9), color, 5.0)
		"ranger_dash":
			btn.draw_colored_polygon(PackedVector2Array([c + Vector2(-8,-9), c + Vector2(10,0), c + Vector2(-8,9), c + Vector2(-2,0)]), color)
		"healing_totem", "medic_revive_ultimate":
			btn.draw_rect(Rect2(c.x - 3, c.y - 11, 6, 22), color)
			btn.draw_rect(Rect2(c.x - 11, c.y - 3, 22, 6), color)
			if sid == "medic_revive_ultimate":
				btn.draw_arc(c, 14.0, 0.0, TAU, 24, color, 2.0)
		"frost_ring":
			for i in range(3):
				var d := Vector2.RIGHT.rotated(float(i) * PI / 3.0) * 11.0
				btn.draw_line(c - d, c + d, color, 3.0)
		_:
			btn.draw_arc(c, 10.0, 0.0, TAU, 24, color, 3.0)
			for i in range(6):
				var d := Vector2.RIGHT.rotated(float(i) * TAU / 6.0)
				btn.draw_line(c + d * 4.0, c + d * 14.0, color, 2.5)


func _refresh_inventory(inventory: Dictionary) -> void:
	if inventory == _last_inventory and inventory_bar.get_child_count() > 0:
		return
	_last_inventory = inventory.duplicate(true)
	for child in inventory_bar.get_children():
		inventory_bar.remove_child(child)
		child.queue_free()
	for id in ITEM_ICONS:
		var count := int(inventory.get(id, 0))
		if count <= 0:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(53, 58)
		btn.add_theme_font_size_override("font_size", 11)
		btn.text = "%s %d\n%s" % [str(ITEM_ICONS[id]), count, str(ITEM_NAMES[id])]
		btn.tooltip_text = "Use " + str(ITEM_NAMES[id])
		btn.pressed.connect(func() -> void: item_use_pressed.emit(str(id)))
		inventory_bar.add_child(btn)


func _build_revive_picker() -> void:
	_revive_overlay = ColorRect.new()
	_revive_overlay.color = Color(0.02, 0.04, 0.06, 0.82)
	_revive_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_revive_overlay)
	_revive_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_revive_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	_revive_list = VBoxContainer.new()
	_revive_list.add_theme_constant_override("separation", 10)
	margin.add_child(_revive_list)
	_revive_overlay.hide()


func _open_revive_picker() -> void:
	var downed: Array = []
	for target in _revive_targets:
		if bool(target.get("downed", false)):
			downed.append(target)
	if downed.is_empty():
		show_toast("No downed teammate to revive.")
		return
	for child in _revive_list.get_children():
		_revive_list.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = "Choose a teammate to revive"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_revive_list.add_child(title)
	for target in downed:
		var button := Button.new()
		button.custom_minimum_size = Vector2(300, 50)
		button.text = str(target.get("name", "Teammate"))
		var user_id := str(target.get("user_id", ""))
		button.pressed.connect(func() -> void:
			_revive_overlay.hide()
			revive_target_selected.emit(user_id)
		)
		_revive_list.add_child(button)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: _revive_overlay.hide())
	_revive_list.add_child(cancel)
	_revive_overlay.show()


func update_hud(snap: Dictionary) -> void:
	var online := bool(snap.get("online", false))
	var team_paused := bool(snap.get("team_paused", false))
	var pause_remaining := int(snap.get("pause_remaining", 0))
	if online:
		pause_btn.text = "Resume" if team_paused else ("Pause %d:%02d" % [pause_remaining / 60, pause_remaining % 60] if pause_remaining > 0 else "Pause")
		pause_btn.disabled = not team_paused and pause_remaining > 0
	else:
		pause_btn.text = "Pause"
		pause_btn.disabled = false
	var hp := int(snap.get("hp", 120))
	var max_hp := maxi(1, int(snap.get("max_hp", 120)))
	var h_class := str(snap.get("hero_class", "ranger"))
	hero_lbl.text = "%s · HP %d / %d%s" % [
		str(snap.get("username", "Ranger")),
		hp,
		max_hp,
		" [DOWNED]" if bool(snap.get("downed", false)) else "",
	]
	hp_bar.max_value = float(max_hp)
	hp_bar.value = float(hp)

	var ammo := int(snap.get("ammo", 12))
	var mag := int(snap.get("mag_size", 12))
	var mana := int(snap.get("mana", 100))
	var max_mana := int(snap.get("max_mana", 100))
	var reloading := bool(snap.get("reloading", false))
	if h_class == "ranger":
		sec_lbl.text = "RELOADING..." if reloading else "Ammo %d/%d" % [ammo, mag]
	else:
		sec_lbl.text = "Medical Energy %d/%d" % [mana, max_mana]

	economy_lbl.text = "Coins: %d · +%d SP" % [
		int(snap.get("coins", 0)),
		int(snap.get("points_earned", 0)),
	]

	var peers: Array = snap.get("squad_statuses", [])
	if peers.size() > 0:
		squad_lbl.show()
		squad_lbl.text = "Squad: " + ", ".join(peers)
	else:
		squad_lbl.hide()
		squad_lbl.text = ""
	squad_lbl.visible = _details_expanded and peers.size() > 0

	var mode := str(snap.get("mode", "story"))
	var wave := int(snap.get("wave", 1))
	var max_w := int(snap.get("waves_count", 5))
	if mode == "endless":
		stage_wave_lbl.text = "ENDLESS PORTAL REALM %d · WAVE %d" % [int(snap.get("portal_realm", 1)), wave]
		goal_lbl.text = "Goal: Survive every 10-wave realm & defeat Rift Bosses"
	elif mode == "tutorial":
		stage_wave_lbl.text = "TRAINING OUTPOST · TUTORIAL"
		goal_lbl.text = "Goal: Complete training drills (Zero Death Risk)"
	else:
		stage_wave_lbl.text = "Stage %d: %s · Wave %d / %d" % [
			int(snap.get("stage_id", 1)),
			str(snap.get("stage_name", "")),
			wave,
			max_w,
		]
		goal_lbl.text = "Goal: Clear %d waves & defeat Boss in <= %ds for 3★" % [
			max_w,
			int(GameRules.STAGE_TARGET_TIMES.get(int(snap.get("stage_id", 1)), 240)),
		]

	clock_lbl.text = "%s · %s %s · Hostiles: %d · Time: %ds" % [
		str(snap.get("bunker_name", "Bunker")),
		str(snap.get("day_phase", "Day")),
		str(snap.get("day_time", "12:00 PM")),
		int(snap.get("enemies_remaining", 0)),
		int(snap.get("elapsed_seconds", 0)),
	]
	var task_text := str(snap.get("task_text", ""))
	_task_lbl.visible = not task_text.is_empty()
	if _task_lbl.visible:
		_task_lbl.text = "TASK: %s%s" % [task_text, " · %d away" % int(snap.get("task_distance", 0)) if not bool(snap.get("task_complete", false)) and int(snap.get("task_distance", 0)) > 70 else ""]
		_task_lbl.add_theme_color_override("font_color", Color("#86EFAC") if bool(snap.get("task_complete", false)) else Color("#FDE68A"))
	_antidote_lbl.text = str(snap.get("antidote_status", ""))
	_antidote_lbl.visible = not _antidote_lbl.text.is_empty()

	var boss_hp := int(snap.get("boss_hp", 0))
	var boss_max := int(snap.get("boss_max_hp", 0))
	if boss_max > 0 and boss_hp > 0:
		boss_box.show()
		boss_name_lbl.text = "BOSS: %s (%d / %d)" % [str(snap.get("boss_name", "OVERLORD")).to_upper(), boss_hp, boss_max]
		boss_bar.max_value = float(boss_max)
		boss_bar.value = float(boss_hp)
	else:
		boss_box.hide()

	var tut_txt := str(snap.get("tutorial_hint", ""))
	if tut_txt != "":
		tutorial_card.show()
		tut_lbl.text = tut_txt
	else:
		tutorial_card.hide()

	var waiting_wave := bool(snap.get("waiting_for_next_wave", false))
	next_wave_btn.visible = waiting_wave
	var can_skip := bool(snap.get("can_skip_wave_preparation", false))
	next_wave_btn.disabled = not can_skip
	if waiting_wave:
		var prep_seconds := maxi(0, ceili(float(snap.get("wave_prep_remaining", 0.0))))
		if can_skip:
			next_wave_btn.text = "SKIP PREP · START WAVE %d NOW (%ds)" % [wave + 1, prep_seconds]
		elif prep_seconds == 0 and bool(snap.get("task_blocks_next_wave", false)):
			next_wave_btn.text = "COMPLETE STAGE TASK · WAVE %d READY" % (wave + 1)
		else:
			next_wave_btn.text = "PREPARE FOR WAVE %d · %ds" % [wave + 1, prep_seconds]

	var in_bunker := bool(snap.get("in_bunker", false))
	shop_btn.modulate = Color("#22C55E") if in_bunker else Color("#F8FAFC")
	_refresh_inventory(snap.get("inventory", {}))

	var cooldowns: Dictionary = snap.get("skill_cooldowns", {})
	var charges: Dictionary = snap.get("skill_charges", {})
	var is_tut := (mode == "tutorial")
	_revive_targets = snap.get("revive_targets", [])
	for sid_v in _skill_buttons.keys():
		var sid := str(sid_v)
		var btn: Button = _skill_buttons[sid]
		var def: Dictionary = GameData.SKILLS[sid]
		var unlocked := GameRules.is_skill_unlocked_at_wave(sid, wave, is_tut)
		var cd := float(cooldowns.get(sid, 0.0))
		var chg := int(charges.get(sid, 0))
		if not unlocked:
			btn.text = "\n\n\nWave %d" % int(def["unlock_wave"])
			btn.disabled = true
		elif not is_tut and chg <= 0:
			btn.text = "\n\n\nShop"
			btn.disabled = true
		elif cd > 0.0:
			btn.text = "\n\n\n%.1fs · %d" % [cd, chg]
			btn.disabled = true
		else:
			btn.text = "\n\n\nx%s" % ("∞" if is_tut else str(chg))
			btn.disabled = false
		btn.queue_redraw()


func get_touch_move_vector() -> Vector2:
	return touch_controls.move_vector


func is_touch_firing() -> bool:
	return touch_controls.is_firing
