extends Control

signal deploy_requested
signal cancelled
signal sequence_completed

@onready var badge_label: Label = $Margin/VBox/Header/HeaderInfo/BadgeLabel
@onready var title_label: Label = $Margin/VBox/Header/HeaderInfo/TitleLabel
@onready var sub_label: Label = $Margin/VBox/Header/HeaderInfo/SubLabel
@onready var skip_btn: Button = $Margin/VBox/Header/SkipBtn
@onready var manga_frame: PanelContainer = $Margin/VBox/MangaFrame
@onready var manga_canvas: Control = $Margin/VBox/MangaFrame/MangaCanvas
@onready var panels_row: HBoxContainer = $Margin/VBox/PanelsRow
@onready var intel_row: HBoxContainer = $Margin/VBox/IntelRow
@onready var threat_card: PanelContainer = $Margin/VBox/IntelRow/ThreatCard
@onready var threat_body: Label = $Margin/VBox/IntelRow/ThreatCard/ThreatVBox/ThreatBody
@onready var boss_card: PanelContainer = $Margin/VBox/IntelRow/BossCard
@onready var boss_body: Label = $Margin/VBox/IntelRow/BossCard/BossVBox/BossBody
@onready var prev_btn: Button = $Margin/VBox/Footer/PrevBtn
@onready var next_btn: Button = $Margin/VBox/Footer/NextBtn
@onready var deploy_btn: Button = $Margin/VBox/Footer/DeployBtn
@onready var hint_label: Label = $Margin/VBox/Footer/HintLabel

var _panels: Array = []
var _active_panel_idx: int = 0
var _anim_t: float = 0.0
var _chapter_accent: Color = Color("#F59E0B")
var _waiting_for_squad: bool = false
var _playing_sequence: bool = false
var _sequence_kind: String = ""
var _briefing_boss_id: String = ""

const ART_INK := Color("#080C10")


func _ready() -> void:
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = Color("#0F172A")
	frame_sb.border_color = Color("#F8FAFC")
	frame_sb.set_border_width_all(3)
	frame_sb.set_corner_radius_all(6)
	manga_frame.add_theme_stylebox_override("panel", frame_sb)

	var t_sb := StyleBoxFlat.new()
	t_sb.bg_color = Color("#0D1C28")
	t_sb.border_color = Color("#0EA5E9")
	t_sb.set_border_width_all(1)
	t_sb.set_corner_radius_all(8)
	t_sb.set_content_margin_all(12)
	threat_card.add_theme_stylebox_override("panel", t_sb)

	var b_sb := StyleBoxFlat.new()
	b_sb.bg_color = Color("#241215")
	b_sb.border_color = Color("#EF4444")
	b_sb.set_border_width_all(1)
	b_sb.set_corner_radius_all(8)
	b_sb.set_content_margin_all(12)
	boss_card.add_theme_stylebox_override("panel", b_sb)

	var d_sb := StyleBoxFlat.new()
	d_sb.bg_color = Color("#F59E0B")
	d_sb.set_corner_radius_all(8)
	deploy_btn.add_theme_stylebox_override("normal", d_sb)
	deploy_btn.add_theme_color_override("font_color", Color("#0F172A"))

	manga_canvas.draw.connect(_draw_manga_comic_page)
	skip_btn.pressed.connect(_skip)
	deploy_btn.pressed.connect(_confirm)
	prev_btn.pressed.connect(func() -> void: _step_panel(-1))
	next_btn.pressed.connect(func() -> void: _step_panel(1))


func open_briefing(mode: String, stage_id: int, portal_realm: int = 1) -> void:
	_playing_sequence = false
	_sequence_kind = ""
	intel_row.show()
	hint_label.text = "Tap a manga panel to focus or press Deploy Squad immediately."
	skip_btn.text = "Skip Intro"
	var brief := GameData.get_story_briefing(mode, stage_id, portal_realm)
	_briefing_boss_id = str(brief.get("boss_id", "village_boss"))
	threat_body.text = str(brief.get("threat_note", ""))
	boss_body.text = str(brief.get("boss_summary", ""))
	_open_panels(brief)


func open_maya_infection_story() -> void:
	_playing_sequence = true
	_sequence_kind = "maya"
	intel_row.hide()
	hint_label.text = "Read each panel or skip to the fight."
	skip_btn.text = "Skip Story"
	_open_panels(GameData.get_maya_infection_story())


func open_home_intro() -> void:
	_playing_sequence = true
	_sequence_kind = "home"
	intel_row.hide()
	hint_label.text = "Read the origin story, then enter the command hub."
	skip_btn.text = "Skip Story"
	_open_panels(GameData.get_home_intro_story())


func open_maya_antidote_finale(finisher_name: String, finisher_class: String, squad: Array) -> void:
	_playing_sequence = true
	_sequence_kind = "maya_finale"
	intel_row.hide()
	hint_label.text = "Read the remaining panels or skip the ending."
	skip_btn.text = "Skip Ending"
	_open_panels(GameData.get_maya_antidote_finale(finisher_name, finisher_class, squad))


func _open_panels(story: Dictionary) -> void:
	_waiting_for_squad = false
	deploy_btn.disabled = false
	skip_btn.disabled = false
	_chapter_accent = Color(str(story.get("accent_color", "#F59E0B")))
	badge_label.text = str(story.get("badge", "MISSION BRIEF"))
	badge_label.add_theme_color_override("font_color", _chapter_accent)
	title_label.text = str(story.get("title", "Mission"))
	sub_label.text = str(story.get("subtitle", ""))
	sub_label.visible = not sub_label.text.is_empty()

	_panels = story.get("manga_panels", [])
	_active_panel_idx = 0
	_anim_t = 0.0
	_build_panel_strip()
	manga_canvas.queue_redraw()
	show()


func _confirm() -> void:
	if _waiting_for_squad:
		return
	if _playing_sequence:
		if _active_panel_idx < _panels.size() - 1:
			_step_panel(1)
		else:
			_complete_sequence()
	else:
		AudioManager.play_pickup()
		deploy_requested.emit()


func _skip() -> void:
	if _waiting_for_squad:
		return
	if _playing_sequence:
		_complete_sequence()
	else:
		deploy_requested.emit()


func _complete_sequence() -> void:
	if not visible or _waiting_for_squad:
		return
	hide()
	sequence_completed.emit()


func set_waiting_for_squad(ready_count: int, total: int) -> void:
	_waiting_for_squad = true
	deploy_btn.disabled = true
	skip_btn.disabled = true
	deploy_btn.text = "WAITING FOR SQUAD" if ready_count < 0 else "WAITING FOR SQUAD (%d/%d)" % [ready_count, maxi(1, total)]


func _process(delta: float) -> void:
	if visible:
		_anim_t += delta
		manga_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		match k:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_confirm()
			KEY_ESCAPE:
				if _playing_sequence:
					_complete_sequence()
				else:
					hide()
					cancelled.emit()
			KEY_RIGHT:
				_step_panel(1)
			KEY_LEFT:
				_step_panel(-1)
			_:
				return
		get_viewport().set_input_as_handled()


func _step_panel(direction: int) -> void:
	if _panels.is_empty() or _waiting_for_squad:
		return
	var index := _active_panel_idx + direction
	if _playing_sequence:
		_select_panel(clampi(index, 0, _panels.size() - 1))
	else:
		_select_panel(posmod(index, _panels.size()))


func _select_panel(index: int) -> void:
	if index == _active_panel_idx or _waiting_for_squad:
		return
	_active_panel_idx = index
	if _playing_sequence:
		_anim_t = 0.0
	_refresh_panel_buttons()
	manga_canvas.queue_redraw()


func _build_panel_strip() -> void:
	for c in panels_row.get_children():
		panels_row.remove_child(c)
		c.queue_free()
	for i in range(_panels.size()):
		var p: Dictionary = _panels[i]
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 48)
		if _playing_sequence:
			btn.text = "Panel %d" % (i + 1)
		else:
			btn.text = "Panel %d · %s" % [i + 1, str(p.get("speaker", ""))]
		var idx := i
		btn.pressed.connect(func() -> void: _select_panel(idx))
		panels_row.add_child(btn)
	_refresh_panel_buttons()


func _refresh_panel_buttons() -> void:
	var at_last_panel := _active_panel_idx >= _panels.size() - 1
	prev_btn.disabled = _playing_sequence and _active_panel_idx == 0
	next_btn.disabled = _playing_sequence and at_last_panel
	if _playing_sequence and not _waiting_for_squad:
		deploy_btn.text = "CONTINUE"
		if at_last_panel:
			match _sequence_kind:
				"home":
					deploy_btn.text = "ENTER COMMAND HUB"
				"maya_finale":
					deploy_btn.text = "FINISH STORY"
				_:
					deploy_btn.text = "TO BATTLE"
	elif not _waiting_for_squad:
		deploy_btn.text = "DEPLOY SQUAD"
	for i in range(panels_row.get_child_count()):
		var btn := panels_row.get_child(i) as Button
		if btn:
			var panel_accent := _chapter_accent if _playing_sequence else Color("#F59E0B")
			btn.modulate = panel_accent if i == _active_panel_idx else Color("#94A3B8")


func _draw_manga_comic_page() -> void:
	if _panels.is_empty():
		return
	var w := manga_canvas.size.x
	var h := manga_canvas.size.y
	if w < 10.0 or h < 10.0:
		return

	var p: Dictionary = _panels[_active_panel_idx]
	var mood := Color(str(p.get("mood_color", "#F59E0B")))
	var scene_kind := str(p.get("scene_kind", "crash"))
	var font := ThemeDB.fallback_font

	# Offset halftone dots sit behind the figures and dialogue.
	manga_canvas.draw_rect(Rect2(0, 0, w, h), Color("#0B111A"))
	for gy in range(10, int(h), 15):
		for gx in range(9 + (gy / 15 % 2) * 7, int(w), 15):
			var radius := 1.0 + float((gx + gy) % 3) * 0.45
			manga_canvas.draw_circle(Vector2(gx, gy), radius, Color(mood, 0.14))

	# Radial manga action speedlines
	var focal := Vector2(w * 0.62, h * 0.48)
	for i in range(28):
		var ang := float(i) * (TAU / 28.0) + sin(_anim_t * 1.5) * 0.04
		var inner_r := 115.0 + fmod(float(i * 19), 30.0)
		var outer_r := maxf(w, h)
		manga_canvas.draw_line(
			focal + Vector2(cos(ang), sin(ang)) * inner_r,
			focal + Vector2(cos(ang), sin(ang)) * outer_r,
			Color(mood.r, mood.g, mood.b, 0.16),
			2.0
		)

	var stage_art := Vector2(w * 0.74, h * 0.51)
	var stage_scale := minf(w / 840.0, h / 232.0)
	var sx := stage_art.x
	var sy := stage_art.y
	match scene_kind:
		"crash":
			# Tilted wrecked convoy + smoke plumes
			manga_canvas.draw_rect(Rect2(sx - 90, sy - 10, 170, 56), Color("#475569"))
			manga_canvas.draw_rect(Rect2(sx - 80, sy - 34, 80, 32), Color("#64748B"))
			var f_r := 26.0 + sin(_anim_t * 6.0) * 4.0
			manga_canvas.draw_circle(Vector2(sx + 40, sy - 24), f_r, Color("#F97316"))
			manga_canvas.draw_circle(Vector2(sx + 40, sy - 24), f_r * 0.55, Color("#FDE047"))
		"barricade":
			_draw_masonry(stage_art + Vector2(48, 0) * stage_scale, stage_scale, false)
			_draw_comic_ranger(stage_art + Vector2(-79, 8) * stage_scale, Vector2.ONE * stage_scale * 0.92, 0.08, Color("#516E57"), Color("#DBB48D"), mood, false, true)
			_draw_comic_zombie(stage_art + Vector2(132, 19) * stage_scale, stage_scale * 0.67, "basic", -1.0)
		"phasing":
			var wing_panel := _briefing_boss_id == "forest_boss"
			_draw_masonry(stage_art - Vector2(34, 0) * stage_scale, stage_scale, true)
			_draw_comic_zombie(stage_art + Vector2(-75, 14) * stage_scale, stage_scale * 0.65, "spirit")
			_draw_comic_zombie(stage_art + Vector2(60 + sin(_anim_t * 2.0) * 22, -2) * stage_scale, stage_scale, "flying" if wing_panel else "spirit", -1.0)
			if _briefing_boss_id == "final_boss":
				_draw_comic_zombie(stage_art + Vector2(137, 0) * stage_scale, stage_scale * 0.62, "flying", -1.0)
		"boss":
			var pulse := 1.0 + sin(_anim_t * 4.0) * 0.05
			manga_canvas.draw_circle(stage_art, 92.0 * pulse * stage_scale, Color(mood, 0.22))
			_draw_comic_zombie(stage_art + Vector2(-112, 24) * stage_scale, stage_scale * 0.63, "fast")
			_draw_comic_zombie(stage_art + Vector2(113, 23) * stage_scale, stage_scale * 0.67, "elite", -1.0)
			_draw_comic_zombie(stage_art + Vector2(5, 9) * stage_scale, stage_scale * 1.3, "tank", 1.0, _briefing_boss_id)
		"portal":
			# Swirling dimensional vortex
			for r_i in range(4):
				var rad := 24.0 + float(r_i) * 20.0 + sin(_anim_t * 4.0 + float(r_i)) * 4.0
				manga_canvas.draw_arc(Vector2(sx, sy - 8), rad, 0.0, TAU, 32, mood, 4.0)
		"maya_snipe":
			var deck := stage_art + Vector2(-26, 29) * stage_scale
			for side in [-1.0, 1.0]:
				_draw_ink_line(deck + Vector2(46 * side, 0) * stage_scale, deck + Vector2(72 * side, 71) * stage_scale, Color("#82654E"), 9.0 * stage_scale)
			_draw_ink_line(deck + Vector2(-52, 0) * stage_scale, deck + Vector2(52, 0) * stage_scale, Color("#B98C61"), 10.0 * stage_scale)
			_draw_comic_ranger(deck - Vector2(0, 50) * stage_scale, Vector2.ONE * stage_scale * 0.76, 0.06, Color("#657747"), Color("#DBB48D"), Color("#CF6955"), false, true, true, "maya")
			manga_canvas.draw_set_transform(Vector2.ZERO)
			manga_canvas.draw_line(deck + Vector2(58, -57) * stage_scale, deck + Vector2(155, -20) * stage_scale, Color(mood, 0.68), 1.6, true)
		"maya_cover", "maya_wounded", "maya_turning", "maya_infected":
			_draw_maya_scene(scene_kind, Vector2(w * 0.75, h * 0.51), minf(w / 620.0, h / 255.0), mood)
		"maya_antidote_approach", "maya_antidote_injection", "maya_antidote_recovery":
			_draw_maya_finale(p, scene_kind, Vector2(w * 0.75, h * 0.51), minf(w / 620.0, h / 310.0), mood)
		"origin_well", "origin_forest", "origin_city", "origin_lab", "origin_rift", "hero_fight", "antidote_pickup", "supply_run", "antidote_delivery":
			_draw_origin_scene(scene_kind, Vector2(w * 0.75, h * 0.52), mood)
		_:
			_draw_comic_ranger(stage_art + Vector2(-68, 12) * stage_scale, Vector2.ONE * stage_scale * 0.93, -0.07, Color("#516E57"), Color("#DBB48D"), mood, false, true)
			_draw_comic_ranger(stage_art + Vector2(60, 17) * stage_scale, Vector2.ONE * stage_scale * 0.96, 0.10, Color("#298B85"), Color("#C79578"), Color("#A7F3D0"), false, true, true, "medic")
	manga_canvas.draw_set_transform(Vector2.ZERO)

	# SFX Burst Box (Top-Right comic lettering)
	var sfx_txt := str(p.get("sfx", "BAM!!"))
	manga_canvas.draw_rect(Rect2(w - 230, 18, 210, 44), Color("#0F172A"))
	manga_canvas.draw_rect(Rect2(w - 230, 18, 210, 44), mood, false, 2.5)
	manga_canvas.draw_string(font, Vector2(w - 216, 48), sfx_txt, HORIZONTAL_ALIGNMENT_LEFT, 186, 22, mood)

	# Panel Number Badge
	manga_canvas.draw_rect(Rect2(18, 18, 128, 30), mood)
	manga_canvas.draw_string(font, Vector2(28, 39), "PANEL %d / %d" % [_active_panel_idx + 1, _panels.size()], HORIZONTAL_ALIGNMENT_LEFT, 115, 13, Color("#0F172A"))

	# Comic Speech Bubble on Left
	var bubble := Rect2(24, 68, minf(490.0, w * 0.50), 126)
	manga_canvas.draw_rect(bubble, Color("#F8FAFC"))
	manga_canvas.draw_rect(bubble, Color("#0F172A"), false, 4.0)
	manga_canvas.draw_rect(Rect2(bubble.position.x + 12, bubble.position.y - 14, 190, 26), Color("#0F172A"))
	manga_canvas.draw_string(font, Vector2(bubble.position.x + 22, bubble.position.y + 4), str(p.get("speaker", "RANGER")), HORIZONTAL_ALIGNMENT_LEFT, 175, 13, mood)

	# Wrapped Dialogue text inside white speech bubble
	var dlg := str(p.get("dialogue", ""))
	manga_canvas.draw_multiline_string(font, Vector2(bubble.position.x + 18, bubble.position.y + 38), dlg, HORIZONTAL_ALIGNMENT_LEFT, bubble.size.x - 36, 17, 4, Color("#0F172A"))

	# Bottom Narration Bar
	var nar_rect := Rect2(18, h - 54, w - 36, 40)
	manga_canvas.draw_rect(nar_rect, Color("#090E17"))
	manga_canvas.draw_rect(nar_rect, Color("#334155"), false, 1.5)
	manga_canvas.draw_string(font, Vector2(32, h - 28), str(p.get("narration", "")), HORIZONTAL_ALIGNMENT_LEFT, w - 64, 14, Color("#CBD5E1"))


func _draw_origin_scene(scene_kind: String, center: Vector2, mood: Color) -> void:
	var ink := Color("#080C10")
	var drift := sin(_anim_t * 3.0)
	var left := center.x - 160.0
	var top := center.y - 100.0
	manga_canvas.draw_line(Vector2(left, center.y + 80), Vector2(center.x + 205, center.y + 80), mood.darkened(0.55), 5.0)
	match scene_kind:
		"origin_well":
			for x in [left + 30.0, left + 130.0, left + 240.0]:
				manga_canvas.draw_rect(Rect2(x, top + 24, 74, 99), Color("#43515A"))
				manga_canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, top + 24), Vector2(x + 37, top - 6), Vector2(x + 82, top + 24)]), ink)
			manga_canvas.draw_circle(center + Vector2(38, 38), 42, Color("#616C67"))
			manga_canvas.draw_circle(center + Vector2(38, 38), 29, Color("#173E42"))
			manga_canvas.draw_circle(center + Vector2(38 + drift * 5, 34), 11, Color(mood, 0.48))
			_draw_story_person(center + Vector2(-100, 39), false, mood)
		"origin_forest":
			for x in [left + 15.0, left + 105.0, left + 230.0, left + 310.0]:
				manga_canvas.draw_rect(Rect2(x, top + 55, 12, 130), Color("#4B3526"))
				manga_canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 33, top + 83), Vector2(x + 6, top - 13), Vector2(x + 45, top + 83)]), Color("#264F37"))
			manga_canvas.draw_line(center + Vector2(-50, 51), center + Vector2(70, 15), Color("#8D9BA1"), 13.0)
			manga_canvas.draw_circle(center + Vector2(17, 40), 18, Color("#67757B"))
			for i in range(14):
				var spore := Vector2(left + float(i * 27), top + 10 + fposmod(_anim_t * (12 + i) + i * 17, 135))
				manga_canvas.draw_circle(spore, 3.0 + float(i % 3), Color(mood, 0.35))
		"origin_city":
			for i in range(5):
				var tower_x := left + i * 75.0
				manga_canvas.draw_rect(Rect2(tower_x, top + 8 + (i % 2) * 24, 67, 165), Color("#3F4B58"))
				for row in range(3):
					manga_canvas.draw_rect(Rect2(tower_x + 14, top + 37 + row * 35, 17, 21), Color("#A5B6B5"))
			manga_canvas.draw_rect(Rect2(center.x + 37, top + 22, 26, 70), Color("#E2E8F0"))
			manga_canvas.draw_rect(Rect2(center.x + 13, top + 44, 74, 25), Color("#E2E8F0"))
			_draw_story_person(center + Vector2(-80, 38), true, mood, "tank")
		"origin_lab":
			for i in range(3):
				var vat_x := left + 25 + i * 112
				manga_canvas.draw_rect(Rect2(vat_x, top + 12, 78, 150), Color("#134E4A"))
				manga_canvas.draw_rect(Rect2(vat_x, top + 12, 78, 150), Color("#67E8F9"), false, 4.0)
				manga_canvas.draw_circle(Vector2(vat_x + 39, top + 68 + drift * 3), 20, Color(mood, 0.45))
			manga_canvas.draw_line(center + Vector2(73, -76), center + Vector2(24, 32), Color("#F8FAFC"), 3.0)
			manga_canvas.draw_line(center + Vector2(38, -42), center + Vector2(89, 37), Color("#F8FAFC"), 3.0)
		"origin_rift":
			for i in range(5):
				var radius := 35.0 + i * 24.0 + drift * 3.0
				manga_canvas.draw_arc(center + Vector2(45, -12), radius, 0, TAU, 40, Color(mood, 0.35 + i * 0.1), 3.0)
			_draw_story_person(center + Vector2(-90, 48), true, mood, "elite")
		"hero_fight":
			_draw_comic_ranger(center + Vector2(-12, -55), Vector2.ONE * 0.48, -0.06, Color("#657747"), Color("#DBB48D"), Color("#FBBF24"), false, true, true, "maya")
			manga_canvas.draw_set_transform(Vector2.ZERO)
			_draw_comic_ranger(center + Vector2(-115, 13), Vector2.ONE * 0.82, -0.08, Color("#415D4B"), Color("#D9AE8B"), mood, false, true)
			manga_canvas.draw_set_transform(Vector2.ZERO)
			_draw_comic_ranger(center + Vector2(55, 18), Vector2.ONE * 0.72, 0.06, Color("#298B85"), Color("#C79578"), Color("#A7F3D0"), false, true, true, "medic")
			manga_canvas.draw_set_transform(Vector2.ZERO)
			_draw_story_person(center + Vector2(155, 54), true, Color("#A3E635"), "fast")
		"antidote_pickup", "antidote_delivery":
			manga_canvas.draw_rect(Rect2(center.x - 90, center.y + 24, 205, 25), Color("#64748B"))
			manga_canvas.draw_rect(Rect2(center.x + 18, center.y - 40, 47, 65), Color("#1E3A5F"))
			manga_canvas.draw_rect(Rect2(center.x + 26, center.y - 33, 31, 50), Color("#67E8F9"))
			manga_canvas.draw_rect(Rect2(center.x + 33, center.y - 49, 17, 10), Color("#E2E8F0"))
			manga_canvas.draw_circle(center + Vector2(41, -8), 54 + drift * 3, Color(0.26, 0.83, 0.95, 0.17))
			_draw_comic_ranger(center + Vector2(-105, 19), Vector2.ONE * 0.68, 0.04, Color("#415D4B"), Color("#D9AE8B"), mood, false, false)
			manga_canvas.draw_set_transform(Vector2.ZERO)
		"supply_run":
			manga_canvas.draw_rect(Rect2(center.x + 75, center.y - 68, 99, 139), Color("#4B3E38"))
			manga_canvas.draw_rect(Rect2(center.x + 75, center.y - 68, 99, 139), mood, false, 3.0)
			_draw_comic_ranger(center + Vector2(-86 + drift * 5, 18), Vector2.ONE * 0.75, 0.06, Color("#415D4B"), Color("#D9AE8B"), mood, false, false)
			manga_canvas.draw_set_transform(Vector2.ZERO)
			manga_canvas.draw_rect(Rect2(center.x - 28 + drift * 5, center.y + 5, 37, 30), Color("#9A6B3B"))
	manga_canvas.draw_set_transform(Vector2.ZERO)


func _draw_ink_shape(vertices: Array[Vector2], color: Color, width: float = 2.5) -> void:
	var points := PackedVector2Array(vertices)
	manga_canvas.draw_colored_polygon(points, color)
	if width > 0.0:
		points.append(points[0])
		manga_canvas.draw_polyline(points, ART_INK, width, true)


func _draw_ink_line(start: Vector2, end: Vector2, color: Color, width: float) -> void:
	manga_canvas.draw_line(start, end, ART_INK, width + 3.0, true)
	manga_canvas.draw_line(start, end, color, width, true)


func _draw_masonry(origin: Vector2, art_scale: float, broken_wall: bool) -> void:
	manga_canvas.draw_set_transform(origin, 0.0, Vector2.ONE * art_scale)
	for row in range(5):
		for col in range(2 + int(row > 1 and broken_wall)):
			if broken_wall and row == 0 and col == 1:
				continue
			var pos := Vector2(-28.0 + col * 33 - (row % 2) * 11, -61.0 + row * 23)
			var stone := Color("#5F6B75").darkened(float((row * 3 + col) % 4) * 0.10)
			_draw_ink_shape([pos, pos + Vector2(33, -2), pos + Vector2(32, 20), pos + Vector2(-1, 21)], stone)
			manga_canvas.draw_line(pos + Vector2(3, 3), pos + Vector2(27, 1), stone.lightened(0.22), 1.2, true)
			manga_canvas.draw_line(pos + Vector2(7, 20), pos + Vector2(15, 13), stone.darkened(0.36), 1.4, true)
	manga_canvas.draw_set_transform(Vector2.ZERO)


func _draw_story_person(pos: Vector2, infected: bool, accent: Color, kind: String = "basic") -> void:
	if infected:
		_draw_comic_zombie(pos + Vector2(0, -12), 0.83, kind, -1.0)
	else:
		_draw_comic_ranger(pos + Vector2(0, -10), Vector2.ONE * 0.74, 0.12, Color("#657789"), Color("#D8B49B"), accent, false, false, false, "civilian")
		manga_canvas.draw_set_transform(Vector2.ZERO)


func _draw_comic_zombie(origin: Vector2, art_scale: float, kind: String, facing: float = 1.0, boss_id: String = "") -> void:
	var palette: Dictionary = GameData.ENEMIES[kind] if boss_id.is_empty() else GameData.BOSSES.get(boss_id, GameData.BOSSES["village_boss"])
	var cloth := Color(str(palette["color"])).lerp(Color("#554F45"), 0.28)
	var accent := Color(str(palette["accent_color"]))
	var skin := Color("#A8BD76")
	var dark_skin := Color("#586F45")
	var light_skin := Color("#CFD89D")
	var spirit := kind == "spirit"
	var flying := kind == "flying"
	var bulk := 1.35 if kind == "tank" else (0.79 if kind == "fast" else 1.0)
	var lean := 0.23 if kind == "fast" else 0.08
	if spirit:
		skin = skin.lerp(accent, 0.36)
		dark_skin = dark_skin.lerp(accent, 0.3)
		light_skin = light_skin.lerp(accent, 0.4)
	manga_canvas.draw_set_transform(origin, lean * facing, Vector2(art_scale * facing, art_scale))
	if spirit:
		manga_canvas.draw_circle(Vector2(0, -13), 62.0, Color(accent, 0.12), true, -1, true)
		for i in range(3):
			var tail_shift := sin(_anim_t * 4 + i) * 9.0
			var tail := PackedVector2Array([Vector2(18 - i * 18, 7), Vector2(23 - i * 18, 30), Vector2(8 - i * 18 + tail_shift, 60), Vector2(-15 - i * 14, 67)])
			manga_canvas.draw_polyline(tail, Color(accent, 0.43 - i * 0.09), 13.0 - i * 3, true)
	elif flying:
		var flap := sin(_anim_t * 5) * 9.0
		for side in [-1.0, 1.0]:
			var wing_tip := Vector2(side * 78, -58 + flap)
			var wing_root := Vector2(side * 12, -15)
			_draw_ink_shape([wing_root, wing_tip, Vector2(side * 71, -4), Vector2(side * 53, -11),
				Vector2(side * 48, 10), Vector2(side * 37, 1), Vector2(side * 19, 15)], cloth)
			manga_canvas.draw_line(wing_root, wing_tip, accent.darkened(0.35), 2.0, true)
			manga_canvas.draw_line(wing_root, Vector2(side * 53, -11), accent.darkened(0.48), 2.0, true)
	else:
		var stride := sin(_anim_t * (8.0 if kind == "fast" else 3.0)) * (12.0 if kind == "fast" else 5.0)
		_draw_ink_shape([Vector2(-41, 60), Vector2(-20, 52), Vector2(24, 53), Vector2(43, 62), Vector2(24, 67), Vector2(-29, 67)], Color(ART_INK, 0.65), 0.0)
		for side in [-1.0, 1.0]:
			var hip := Vector2(side * 12 * bulk, 10)
			var knee := Vector2(side * 16 * bulk + stride * side, 36)
			var foot := Vector2(side * 21 * bulk + stride * side, 57 - maxf(0, stride * side * 0.42))
			_draw_ink_line(knee, foot, dark_skin, 11 * bulk)
			_draw_ink_shape([hip + Vector2(-9, 0), hip + Vector2(9, 2), knee + Vector2(8, 2), knee + Vector2(2, -2),
				knee + Vector2(0, 7), knee + Vector2(-5, 2), knee + Vector2(-8, 5)], cloth.darkened(0.32))
			_draw_ink_shape([foot + Vector2(-6, -6), foot + Vector2(5, -5), foot + Vector2(13, 1), foot + Vector2(11, 6), foot + Vector2(-8, 5)], Color("#414249"))

	var far_hand := Vector2(45 * bulk, -13 if kind == "fast" else -28)
	_draw_zombie_arm(Vector2(18 * bulk, -29), Vector2(32 * bulk, -17), far_hand, cloth.darkened(0.30), dark_skin, bulk)
	_draw_ink_shape([Vector2(-25 * bulk, -26), Vector2(-9, -35), Vector2(11, -35), Vector2(25 * bulk, -24),
		Vector2(21 * bulk, 15), Vector2(11, 10), Vector2(7, 22), Vector2(-1, 15), Vector2(-10, 19), Vector2(-20 * bulk, 13)], cloth, 3.1)
	_draw_ink_shape([Vector2(-9, -34), Vector2(11, -34), Vector2(6, -10), Vector2(0, -20), Vector2(-6, -16)], dark_skin)
	_draw_ink_shape([Vector2(11, -9), Vector2(23 * bulk, -11), Vector2(20 * bulk, 2), Vector2(14, 0), Vector2(9, 7)], dark_skin, 1.4)
	for i in range(3):
		var stitch := Vector2(12 + i * 4, -5 + i)
		manga_canvas.draw_line(stitch, stitch + Vector2(3, -4), light_skin, 1.4, true)
	manga_canvas.draw_line(Vector2(-9, -28), Vector2(-4, 10), cloth.lightened(0.35), 2.0, true)
	manga_canvas.draw_line(Vector2(-1, 10), Vector2(10, 8), ART_INK, 1.6, true)
	_draw_zombie_arm(Vector2(-23 * bulk, -23), Vector2(-15 * bulk, 4), Vector2(25 * bulk, -3), cloth, skin, bulk)

	var head := Vector2(5 + (6 if kind == "fast" else 0), -44)
	_draw_ink_shape([head + Vector2(-14, -12), head + Vector2(-6, -20), head + Vector2(9, -19), head + Vector2(16, -11),
		head + Vector2(14, -4), head + Vector2(20, 1), head + Vector2(15, 6), head + Vector2(14, 14),
		head + Vector2(3, 18), head + Vector2(-9, 13), head + Vector2(-15, 4)], skin, 2.9)
	_draw_ink_shape([head + Vector2(-12, -7), head + Vector2(-6, -10), head + Vector2(-5, -2), head + Vector2(4, 9),
		head + Vector2(2, 15), head + Vector2(-9, 11), head + Vector2(-13, 2)], dark_skin, 0.0)
	_draw_ink_shape([head + Vector2(-13, -11), head + Vector2(-13, -17), head + Vector2(-8, -16), head + Vector2(-5, -22),
		head + Vector2(0, -18), head + Vector2(5, -21), head + Vector2(12, -17), head + Vector2(15, -11), head + Vector2(2, -14)], cloth.darkened(0.57))
	manga_canvas.draw_line(head + Vector2(1, -9), head + Vector2(13, -6), ART_INK, 6, true)
	manga_canvas.draw_line(head + Vector2(5, -7), head + Vector2(13, -5), accent.lightened(0.57), 2.9, true)
	manga_canvas.draw_line(head + Vector2(2, 1), head + Vector2(7, 4), dark_skin, 2.3, true)
	_draw_ink_shape([head + Vector2(3, 8), head + Vector2(15, 5), head + Vector2(13, 11), head + Vector2(5, 13)], ART_INK, 0.0)
	for tooth in range(3):
		var point := head + Vector2(6 + tooth * 3, 8 - tooth * 0.7)
		manga_canvas.draw_line(point, point + Vector2(0, 2.4), Color("#E2DEB8"), 1.5, true)
	_draw_zombie_variant(kind, boss_id, head, cloth, accent)
	manga_canvas.draw_set_transform(Vector2.ZERO)


func _draw_zombie_arm(shoulder: Vector2, elbow: Vector2, hand: Vector2, cloth: Color, skin: Color, bulk: float) -> void:
	_draw_ink_line(elbow, hand, skin, 10.0 * bulk)
	var edge := (elbow - shoulder).normalized().orthogonal() * 8 * bulk
	_draw_ink_shape([shoulder - edge, shoulder + edge, elbow + edge * 0.81, elbow + edge * 0.20,
		elbow + Vector2(5, 3), elbow - edge * 0.24, elbow - edge], cloth)
	var reach := (hand - elbow).normalized()
	var across := reach.orthogonal()
	for i in range(3):
		var finger := hand + across * (i - 1) * 3.0
		_draw_ink_line(finger, finger + reach * (6.0 - i) + across * 2.0, skin.lightened(0.08), 2.6)


func _draw_zombie_variant(kind: String, boss_id: String, head: Vector2, cloth: Color, accent: Color) -> void:
	if kind == "tank":
		for side in [-1.0, 1.0]:
			var plate := Vector2(side * 29, -25)
			_draw_ink_shape([plate + Vector2(-11, -7), plate + Vector2(7, -10), plate + Vector2(13, 1),
				plate + Vector2(8, 10), plate + Vector2(-7, 9)], cloth.lightened(0.28))
			manga_canvas.draw_circle(plate + Vector2(-4, 0), 2.8, accent, true, -1, true)
			manga_canvas.draw_line(plate + Vector2(-6, -4), plate + Vector2(7, -5), cloth.lightened(0.5), 1.8, true)
	elif kind == "elite":
		manga_canvas.draw_circle(head + Vector2(9, 10), 7.0, Color(accent, 0.38), true, -1, true)
		manga_canvas.draw_line(head + Vector2(13, 11), head + Vector2(14, 19), accent.lightened(0.25), 2.0, true)
	elif kind == "fast":
		manga_canvas.draw_line(head + Vector2(-10, -14), head + Vector2(10, -14), accent, 3.0, true)
	match boss_id:
		"village_boss":
			_draw_ink_shape([head + Vector2(-14, -13), head + Vector2(-21, -32), head + Vector2(-11, -28),
				head + Vector2(-4, -39), head + Vector2(5, -28), head + Vector2(15, -35), head + Vector2(15, -14)], accent.darkened(0.16))
		"forest_boss", "final_boss":
			for side in [-1.0, 1.0]:
				var tip := head + Vector2(side * (26 if boss_id == "final_boss" else 22), -38)
				_draw_ink_shape([head + Vector2(side * 7, -13), head + Vector2(side * 20, -21), tip,
					head + Vector2(side * 10, -28), head + Vector2(side * 2, -19)], accent.darkened(0.34))
		"city_boss":
			_draw_ink_shape([head + Vector2(-16, -14), head + Vector2(12, -18), head + Vector2(18, -5),
				head + Vector2(10, 1), head + Vector2(-12, -2)], cloth.lightened(0.34))
			manga_canvas.draw_line(head + Vector2(-8, -8), head + Vector2(12, -7), ART_INK, 6, true)
			manga_canvas.draw_line(head + Vector2(-5, -8), head + Vector2(12, -7), accent, 2, true)
		"laboratory_boss":
			for side in [-1.0, 1.0]:
				var start := head + Vector2(side * 13, -17)
				var end := Vector2(side * 29, -7)
				var tube := PackedVector2Array([start, start + Vector2(side * 17, 0), end + Vector2(side * 10, -14), end])
				manga_canvas.draw_polyline(tube, ART_INK, 9.0, true)
				manga_canvas.draw_polyline(tube, accent.darkened(0.14), 5.0, true)


func _draw_maya_scene(scene_kind: String, center: Vector2, available_scale: float, mood: Color) -> void:
	var posing_scale := minf(available_scale, 1.7)
	var art_scale := Vector2.ONE * posing_scale
	var beat := 0.5 + 0.5 * sin(_anim_t * 6.0)
	var infected := scene_kind == "maya_infected"
	var turning := scene_kind == "maya_turning"
	var wounded := scene_kind == "maya_wounded"
	var haze := Color(mood, 0.14 + beat * 0.10)
	manga_canvas.draw_set_transform(center, 0.0, art_scale)
	manga_canvas.draw_circle(Vector2(0, -12), 92.0 if infected else 73.0, haze)
	manga_canvas.draw_line(Vector2(-148, 64), Vector2(129, 58), Color(mood, 0.46), 2, true)
	for i in range(12):
		var drift := fposmod(_anim_t * (17.0 + i), 133.0)
		var ember := Vector2(-137.0 + i * 25, 65 - drift)
		manga_canvas.draw_line(ember, ember + Vector2(4, -7), Color(mood, 0.45), 1.5, true)

	match scene_kind:
		"maya_cover":
			_draw_comic_ranger(center + Vector2(79, 29) * art_scale, art_scale * 0.9, -1.4, Color("#655C54"), Color("#9CA687"), Color("#77865F"), false, false, false)
			_draw_comic_ranger(center, art_scale, 0.10, Color("#657747"), Color("#DBB48D"), mood, false, true, true, "maya")
		"maya_wounded":
			_draw_comic_ranger(center + Vector2(85, 30) * art_scale, art_scale * 0.9, -1.4, Color("#655C54"), Color("#9CA687"), Color("#77865F"), false, false, false)
			_draw_comic_ranger(center + Vector2(0, 9) * art_scale, art_scale, 0.22 + beat * 0.05, Color("#657747"), Color("#DBB48D"), Color("#FBBF24"), false, false, false, "maya")
			manga_canvas.draw_set_transform(center, 0.0, art_scale)
			manga_canvas.draw_line(Vector2(75, 3), Vector2(30, 13), Color("#9CA687"), 8, true)
			for i in range(3):
				var slash := Vector2(16 + i * 8, -11 + i * 11)
				manga_canvas.draw_line(slash, slash + Vector2(25 + beat * 7, -17), Color(mood, 0.60 + beat * 0.4), 3.0, true)
		"maya_turning":
			for i in range(3):
				var fallen_offset := Vector2(60 + i * 22, 33 - i * 11) * art_scale
				_draw_comic_ranger(center + fallen_offset, art_scale * 0.63, -1.3 + i * 0.53, Color("#586146"), Color("#9CA687"), mood, false, false, false)
			_draw_comic_ranger(center + Vector2(0, 15) * art_scale, art_scale, 0.28 + beat * 0.07, Color("#586146"), Color("#A2AD71"), Color("#FBBF24"), true, false, false, "maya")
			manga_canvas.draw_set_transform(center, 0.0, art_scale)
			manga_canvas.draw_arc(Vector2(14, 0), 24.0 + beat * 12.0, 0.0, TAU, 24, Color(mood, 0.40 + beat * 0.30), 2.5, true)
			manga_canvas.draw_polyline(PackedVector2Array([Vector2(18, 20), Vector2(13, 10), Vector2(15, 0), Vector2(10, -8), Vector2(12, -17)]), mood, 3.0, true)
		"maya_infected":
			var rolling := minf(_anim_t * 0.7, 0.8)
			for i in range(6):
				var angle := float(i) * TAU / 6.0 + rolling
				var offset := Vector2.from_angle(angle) * 42.0 * art_scale
				_draw_comic_ranger(center + offset, art_scale * 0.63, angle + PI * 0.5, Color("#586146"), Color("#A5A97E"), mood, true, false, false)
			_draw_comic_ranger(center, art_scale * 0.87, 0.14, Color("#516B30"), Color("#A8BD76"), mood, true, false, false, "maya")
			manga_canvas.draw_set_transform(center, 0.0, art_scale)
			for i in range(3):
				var dust := Vector2(67 + i * 16, 56 - i * 9)
				manga_canvas.draw_line(dust, dust + Vector2(28, -4), Color(mood, 0.35 + beat * 0.3), 2.0, true)
	manga_canvas.draw_set_transform(Vector2.ZERO)


func _draw_maya_finale(panel: Dictionary, scene_kind: String, center: Vector2, available_scale: float, mood: Color) -> void:
	var approach := scene_kind == "maya_antidote_approach"
	var recovery := scene_kind == "maya_antidote_recovery"
	var pullback := smoothstep(0.1, 1.8, _anim_t) if recovery else 0.0
	var art_scale := Vector2.ONE * minf(available_scale, 1.7) * lerpf(1.0, 0.64, pullback)
	var teammate_list: Array = panel.get("squad", [])
	var finisher_coat := _finale_uniform(str(panel.get("finisher_class", "")))
	var maya_skin := Color("#A8BD76").lerp(Color("#DBB48D"), pullback if recovery else 0.0)
	var ink := Color("#080C10")
	manga_canvas.draw_set_transform(center, 0.0, art_scale)
	manga_canvas.draw_circle(Vector2(2, -8), 92.0, Color(mood, 0.13))
	manga_canvas.draw_line(Vector2(-155, 61), Vector2(151, 61), Color(mood, 0.38), 2.0, true)
	for i in range(8):
		var rubble := Vector2(-144.0 + i * 40, 48 + i % 3 * 6)
		manga_canvas.draw_colored_polygon(PackedVector2Array([rubble, rubble + Vector2(12, -8), rubble + Vector2(25, 0)]), Color("#364138"))

	if recovery:
		var spacing := minf(60.0, 268.0 / float(maxi(1, teammate_list.size() - 1)))
		for i in range(teammate_list.size()):
			var teammate: Variant = teammate_list[i]
			var teammate_class := str(teammate.get("class", teammate.get("class_id", ""))) if teammate is Dictionary else ""
			var background_tone := _finale_uniform(teammate_class).lerp(Color("#141B26"), 1.0 - pullback * 0.70)
			var offset_x := (float(i) - float(teammate_list.size() - 1) * 0.5) * spacing
			var offset_y := -43.0 - float(i % 2) * 12.0
			_draw_comic_ranger(center + Vector2(offset_x, offset_y) * art_scale, art_scale * 0.79, 0.0, background_tone, background_tone.lightened(pullback * 0.42), background_tone.lightened(0.1), false, false, false, teammate_class.to_lower())

	var maya_tilt := lerpf(-1.02, -0.35, pullback)
	var maya_origin := Vector2(42, 22)
	var finisher_origin := Vector2(-68, -8) if approach else Vector2(-57, 16)
	_draw_comic_ranger(center + maya_origin * art_scale, art_scale * 0.93, maya_tilt, Color("#657747"), maya_skin, Color("#FBBF24"), not recovery, false, false, "maya")
	_draw_comic_ranger(center + finisher_origin * art_scale, art_scale * 0.91, 0.22, finisher_coat, Color("#CBA98D"), finisher_coat.lightened(0.44), false, false, false, str(panel.get("finisher_class", "")).to_lower())

	if scene_kind == "maya_antidote_injection":
		manga_canvas.draw_set_transform(center, 0.0, art_scale)
		var neck := maya_origin + Vector2(0, -32).rotated(maya_tilt) * 0.93
		var tip := neck + Vector2(-17.0 * (1.0 - smoothstep(0.1, 0.65, _anim_t)), 0)
		var hand := tip - Vector2(27, 3)
		var shoulder := finisher_origin + Vector2(14, -17)
		var elbow := shoulder + Vector2(12, 11)
		var arm := PackedVector2Array([shoulder, elbow, hand])
		manga_canvas.draw_polyline(arm, ink, 14, true)
		manga_canvas.draw_polyline(arm, finisher_coat.lightened(0.18), 8, true)
		manga_canvas.draw_circle(hand, 6, Color("#CBA98D"))
		manga_canvas.draw_line(hand + Vector2(-5, 0), tip - Vector2(7, 0), ink, 10, true)
		manga_canvas.draw_line(hand + Vector2(-3, 0), tip - Vector2(7, 0), Color("#67E8F9"), 6, true)
		manga_canvas.draw_line(tip - Vector2(7, 0), tip, Color("#F1F5F9"), 1.8, true)
	manga_canvas.draw_set_transform(Vector2.ZERO)


func _finale_uniform(player_class: String) -> Color:
	return Color("#298B85") if player_class.to_lower() == "medic" else Color("#526E91")


func _draw_comic_ranger(origin: Vector2, figure_scale: Vector2, lean: float, jacket: Color, skin: Color, accent: Color, infected: bool, aiming: bool, armed: bool = true, role: String = "ranger") -> void:
	manga_canvas.draw_set_transform(origin, lean, figure_scale)
	var ink := Color("#080C10")
	var left_boot := Vector2(-28, 63)
	var right_boot := Vector2(27, 62)
	var left_hip := Vector2(-10, 19)
	var right_hip := Vector2(12, 19)
	manga_canvas.draw_line(left_hip, left_boot, ink, 23, true)
	manga_canvas.draw_line(right_hip, right_boot, ink, 23, true)
	manga_canvas.draw_line(left_hip, left_boot, jacket.darkened(0.27), 14, true)
	manga_canvas.draw_line(right_hip, right_boot, jacket.darkened(0.18), 14, true)
	manga_canvas.draw_line(left_boot, left_boot + Vector2(-12, 1), ink, 8, true)
	manga_canvas.draw_line(right_boot, right_boot + Vector2(12, 1), ink, 8, true)
	for boot in [left_boot, right_boot]:
		manga_canvas.draw_line(boot + Vector2(-4, -5), boot + Vector2(5, -6), jacket.lightened(0.20), 2.0, true)

	var coat: Array[Vector2] = [Vector2(-21, -28), Vector2(13, -29), Vector2(27, -17), Vector2(15, 22)]
	if infected:
		coat.append_array([Vector2(7, 18), Vector2(1, 25), Vector2(-4, 20), Vector2(-10, 23)])
	coat.append_array([Vector2(-15, 21), Vector2(-28, -12)])
	_draw_ink_shape(coat, jacket, 3.4)
	_draw_ink_shape([Vector2(-20, -26), Vector2(-7, -24), Vector2(-1, 16), Vector2(-15, 16), Vector2(-25, -12)], jacket.darkened(0.23), 0.0)
	manga_canvas.draw_line(Vector2(-15, -21), Vector2(9, 14), jacket.lightened(0.38), 3.0, true)
	manga_canvas.draw_line(Vector2(-20, 17), Vector2(16, 17), ink, 6, true)
	_draw_ink_shape([Vector2(-5, 14), Vector2(4, 14), Vector2(5, 20), Vector2(-5, 20)], Color("#B99A6B"), 1.6)
	for side in [-1.0, 1.0]:
		var pocket := Vector2(side * 10, 4)
		_draw_ink_shape([pocket + Vector2(-4, -5), pocket + Vector2(5, -5), pocket + Vector2(4, 4), pocket + Vector2(-3, 5)], jacket.lightened(0.1), 1.4)
	if infected:
		_draw_ink_shape([Vector2(5, -9), Vector2(16, -15), Vector2(13, -6), Vector2(18, -1), Vector2(5, 4)], skin.darkened(0.34), 1.7)
		manga_canvas.draw_line(Vector2(9, -6), Vector2(13, -9), skin.lightened(0.20), 1.5, true)

	var hair := Color("#503135") if role == "maya" else Color("#433635")
	if role == "maya":
		var sway := sin(_anim_t * 7.0) * 3.0
		_draw_ink_shape([Vector2(-7, -55), Vector2(-17, -52), Vector2(-21, -38), Vector2(-33, -25 + sway),
			Vector2(-22, -27 + sway), Vector2(-14, -32), Vector2(-7, -39)], hair)
		manga_canvas.draw_line(Vector2(-17, -47), Vector2(-20, -44), Color("#CC654F"), 2, true)
	_draw_ink_shape([Vector2(-11, -49), Vector2(-7, -57), Vector2(9, -60), Vector2(17, -53),
		Vector2(18, -46), Vector2(22, -41), Vector2(17, -38), Vector2(16, -33), Vector2(6, -28),
		Vector2(-3, -31), Vector2(-10, -39)], skin, 3.0)
	_draw_ink_shape([Vector2(-9, -48), Vector2(-2, -49), Vector2(2, -37), Vector2(10, -30),
		Vector2(5, -28), Vector2(-3, -31), Vector2(-10, -40)], skin.darkened(0.27), 0.0)
	match role:
		"medic":
			_draw_ink_shape([Vector2(-12, -38), Vector2(-22, -55), Vector2(-13, -65), Vector2(1, -72), Vector2(13, -64),
				Vector2(20, -54), Vector2(13, -56), Vector2(-2, -52), Vector2(-7, -39)], jacket.lightened(0.15))
			manga_canvas.draw_line(Vector2(-16, -55), Vector2(1, -66), accent, 2.0, true)
		"civilian":
			_draw_ink_shape([Vector2(-11, -44), Vector2(-17, -52), Vector2(-10, -61), Vector2(0, -63), Vector2(14, -60),
				Vector2(18, -54), Vector2(4, -56), Vector2(-2, -50), Vector2(-6, -43)], hair)
		_:
			_draw_ink_shape([Vector2(-13, -44), Vector2(-17, -53), Vector2(-10, -63), Vector2(7, -65),
				Vector2(17, -59), Vector2(19, -53), Vector2(27, -49), Vector2(13, -47), Vector2(-1, -51), Vector2(-9, -47)], jacket.lightened(0.18))
			manga_canvas.draw_line(Vector2(-10, -57), Vector2(12, -58), jacket.lightened(0.45), 1.9, true)
	if role == "maya":
		var scarf := Color("#BB5848")
		_draw_ink_shape([Vector2(-14, -33), Vector2(12, -31), Vector2(16, -27), Vector2(3, -22),
			Vector2(-9, -26), Vector2(-21, -21), Vector2(-28, -20), Vector2(-22, -30)], scarf)
		manga_canvas.draw_line(Vector2(-9, -30), Vector2(8, -28), scarf.lightened(0.27), 1.5, true)
	if infected:
		manga_canvas.draw_circle(Vector2(13, -44), 9.0 + sin(_anim_t * 7.0) * 2.0, Color("#D5F38A", 0.23))
	manga_canvas.draw_line(Vector2(8, -46), Vector2(17, -43), ink, 4.5, true)
	manga_canvas.draw_line(Vector2(11, -44), Vector2(16, -43), Color("#E0F89D") if infected else Color("#FFF0D9"), 1.7, true)
	manga_canvas.draw_line(Vector2(9, -35), Vector2(15, -36), ink, 2.2, true)
	if infected:
		manga_canvas.draw_line(Vector2(11, -35), Vector2(14, -36), Color("#E1DEB5"), 1.1, true)

	if not armed:
		manga_canvas.draw_line(Vector2(-20, -18), Vector2(-30, 12), ink, 14, true)
		manga_canvas.draw_line(Vector2(-20, -18), Vector2(-30, 12), jacket.lightened(0.10), 8, true)
		manga_canvas.draw_circle(Vector2(-30, 12), 5, skin)
		return

	var stock := Vector2(0, -15) if aiming else Vector2(-15, 4)
	var grip := Vector2(30, -11) if aiming else Vector2(15, 16)
	var muzzle := Vector2(80, -11) if aiming else Vector2(60, 34)
	var forearm := Vector2(47, -9) if aiming else Vector2(32, 21)
	if role == "medic":
		_draw_ink_line(Vector2(11, -16), forearm, jacket.lightened(0.13), 10.0)
		_draw_ink_line(grip - Vector2(7, -39), muzzle, Color("#9877AD"), 5.5)
		manga_canvas.draw_circle(muzzle, 18.0 + sin(_anim_t * 6.0) * 2.0, Color(accent, 0.22), true, -1, true)
		_draw_ink_shape([muzzle + Vector2(-9, 1), muzzle + Vector2(-2, -13), muzzle + Vector2(9, -4), muzzle + Vector2(6, 10)], accent)
		manga_canvas.draw_line(muzzle + Vector2(-3, 2), muzzle + Vector2(-2, -7), Color("#FFF4FF"), 1.8, true)
		manga_canvas.draw_circle(forearm, 4.3, skin, true, -1, true)
		return
	manga_canvas.draw_line(Vector2(13, -20), forearm, ink, 16, true)
	manga_canvas.draw_line(Vector2(13, -20), forearm, jacket.lightened(0.14), 10, true)
	manga_canvas.draw_line(stock, muzzle, ink, 10, true)
	manga_canvas.draw_line(stock, grip + Vector2(7, 0), Color("#566473"), 6, true)
	manga_canvas.draw_line(grip + Vector2(10, 0), muzzle, Color("#93A2AE"), 3, true)
	manga_canvas.draw_line(grip, grip + Vector2(-3, 10), ink, 5, true)
	manga_canvas.draw_line(Vector2(-14, -13), Vector2(9, 4), ink, 15, true)
	manga_canvas.draw_line(Vector2(-14, -13), Vector2(9, 4), jacket.lightened(0.09), 9, true)
	manga_canvas.draw_line(Vector2(9, 4), grip, skin, 7, true)
