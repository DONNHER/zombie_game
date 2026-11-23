extends RefCounted
## Draws arena actors in a three-quarter view with flat colors and inked edges.

const INK := Color("#171922")
const STEEL := Color("#526273")
const LIGHT_STEEL := Color("#A9C7C8")
const SHADOW := Color(0.045, 0.055, 0.085, 0.46)


static func draw_player(canvas: CanvasItem, actor: Dictionary, time_s: float, local: bool = false) -> void:
	var pos := _position(actor)
	var visual_scale := maxf(0.7, float(actor.get("visual_scale", 1.28)))
	var angle := float(actor.get("angle", 0.0))
	var facing := Vector2.RIGHT.rotated(angle)
	var flip := -1.0 if facing.x < 0.0 else 1.0
	var medic := str(actor.get("hero_class", "ranger")) == "medic"
	var female := str(actor.get("gender", "male")) == "female"
	var downed := bool(actor.get("downed", false))
	var moving := bool(actor.get("visual_moving", false)) and not downed
	var phase := time_s * (16.0 if moving else 4.0)
	var stride := sin(phase) * 4.0 if moving else 0.0
	var bob := -absf(cos(phase)) * 2.0 if moving else sin(phase) * 0.7
	var coat := Color("#35776F") if medic else Color("#415D4B")
	var light := Color("#CDEBE0") if medic else Color("#9AAA66")
	var accent := Color("#5EEAD4") if medic else Color("#EBC16A")
	var skin := Color("#CD9271")
	var hair := Color("#322832")
	if downed:
		coat = Color("#565B69")
		light = Color("#888D9D")
		accent = Color("#B7BBC7")

	canvas.draw_set_transform(pos, 0.0, Vector2.ONE * visual_scale)
	_shadow(canvas, 1.0)
	if local and not downed:
		canvas.draw_arc(Vector2(0, 9), 18.0, 0.45, 2.69, 16, Color(0.93, 0.8, 0.47, 0.68), 1.2, true)
	canvas.draw_set_transform(pos + Vector2(0, bob * visual_scale), -0.78 * flip if downed else 0.0, Vector2(flip, 0.78 if downed else 1.0) * visual_scale)
	_boots(canvas, stride, 1.0, coat.darkened(0.33))
	if medic:
		_shape(canvas, [Vector2(-9, -7), Vector2(-17, -5), Vector2(-18, 6),
			Vector2(-15, 10), Vector2(-7, 9)], coat.darkened(0.31))
		_line(canvas, Vector2(-14, -2), Vector2(-14, 5), light, 2.0)
		_line(canvas, Vector2(-17.5, 1.5), Vector2(-10.5, 1.5), light, 2.0)
	else:
		_shape(canvas, [Vector2(-9, -7), Vector2(-15, -3), Vector2(-14, 7), Vector2(-6, 9),
			Vector2(-5, -4)], coat.darkened(0.31))
		_line(canvas, Vector2(-12, -1), Vector2(-12, 5), light.darkened(0.35), 1.4)

	var shoulder := 9.5 if female else 11.0
	_shape(canvas, [Vector2(-shoulder, -7), Vector2(5, -8), Vector2(shoulder, -3),
		Vector2(6, 8), Vector2(-7, 8), Vector2(-shoulder, 2)], coat)
	_shape(canvas, [Vector2(-shoulder + 1, -6), Vector2(-5, -8), Vector2(3, -5),
		Vector2(-2, -1), Vector2(-shoulder + 2, -2)], light, 1.0)
	if medic:
		_line(canvas, Vector2(-4, -7), Vector2(4, 6), coat.darkened(0.38), 2.5)
		_line(canvas, Vector2(4, -4), Vector2(4, 1), light, 1.6)
		_line(canvas, Vector2(1.5, -1.5), Vector2(6.5, -1.5), light, 1.6)
	else:
		_line(canvas, Vector2(-4, -7), Vector2(4, 6), light.darkened(0.25), 2.6)
		_gear(canvas)
	_line(canvas, Vector2(-7, 5), Vector2(6, 5), INK, 2.4)
	_line(canvas, Vector2(-1, 5), Vector2(2, 5), accent, 1.5)

	var head := Vector2(1, -11)
	if female:
		_shape(canvas, [head + Vector2(-5, -4), head + Vector2(-9, 0),
			head + Vector2(-13 - stride * 0.5, 8), head + Vector2(-6, 5), head + Vector2(-1, 2)], hair)
	_face(canvas, head, skin, Color("#EAF9E4"), false)
	if medic:
		_shape(canvas, [head + Vector2(-7, -2), head + Vector2(-7, -6), head + Vector2(-4, -10),
			head + Vector2(3, -10), head + Vector2(7, -6), head + Vector2(8, -3),
			head + Vector2(0, -3), head + Vector2(-4, 1)], light)
		_line(canvas, head + Vector2(-3, -8), head + Vector2(-3, -4), coat, 1.35)
		_line(canvas, head + Vector2(-5, -6), head + Vector2(-1, -6), coat, 1.35)
	else:
		_shape(canvas, [head + Vector2(-6, 1), head + Vector2(-7, -4), head + Vector2(-4, -8),
			head + Vector2(3, -8), head + Vector2(6, -4), head + Vector2(9, -2),
			head + Vector2(0, -2), head + Vector2(-2, 2)], coat)
		_line(canvas, head + Vector2(-4, -6), head + Vector2(2, -6), light, 1.5)

	if not downed:
		var recoil := clampf(float(actor.get("visual_recoil", float(actor.get("fire_timer", 0.0)) * 3.0)), 0.0, 1.0)
		var weapon_id := str(actor.get("weapon_id", ""))
		var long_weapon := weapon_id.ends_with("_staff") if medic else float(actor.get("mg_timer", 0.0)) > 0.0
		var weapon: Dictionary = GameData.WEAPONS.get(weapon_id, {})
		var weapon_accent := Color.from_string(str(weapon.get("color", "")), accent)
		var weapon_pos := pos + Vector2(0, bob * visual_scale) - facing * recoil * 3.0 * visual_scale
		canvas.draw_set_transform(weapon_pos, angle, Vector2(1, flip) * visual_scale)
		_weapon(canvas, medic, long_weapon, coat, light, skin, weapon_accent.lightened(0.25))
	canvas.draw_set_transform(Vector2.ZERO)


static func draw_maya_ranger(canvas: CanvasItem, pos: Vector2, time_s: float, aim_direction: Vector2 = Vector2.RIGHT, recoil: float = 0.0) -> void:
	var direction := aim_direction.normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var flip := -1.0 if direction.x < 0.0 else 1.0
	var visual_scale := 1.28
	var uniform := Color("#577052")
	var trim := Color("#B7BF83")
	var scarf := Color("#C95C46")
	var skin := Color("#D99E79")
	var hair := Color("#552F31")
	var ties_sway := sin(time_s * 3.0)
	var body_pos := pos + Vector2(0, ties_sway * 0.65)

	canvas.draw_set_transform(pos, 0.0, Vector2.ONE * visual_scale)
	_shadow(canvas, 0.95)
	canvas.draw_set_transform(body_pos, 0.0, Vector2(flip, 1.0) * visual_scale)
	_boots(canvas, 0.0, 0.94, Color("#384344"))
	_shape(canvas, [Vector2(-7, -7), Vector2(-13, -5), Vector2(-14, 4),
		Vector2(-9, 8), Vector2(-4, 5)], Color("#76694C"))
	_line(canvas, Vector2(-12, -3), Vector2(-12, 3), Color("#BA9B66"), 1.4)
	_shape(canvas, [Vector2(-10, -7), Vector2(3, -8), Vector2(9, -3),
		Vector2(6, 8), Vector2(-7, 8), Vector2(-9, 1)], uniform)
	_line(canvas, Vector2(-8, -5), Vector2(-4, -6), trim, 2.4)
	_line(canvas, Vector2(-4, -6), Vector2(4, 6), Color("#A68855"), 2.0)
	_line(canvas, Vector2(-7, 5), Vector2(6, 5), INK, 2.4)
	_gear(canvas)

	# The scarf and swept ponytail identify Maya at gameplay scale.
	_shape(canvas, [Vector2(-3, -8), Vector2(-9, -7), Vector2(-15, -2 + ties_sway),
		Vector2(-11, -2 + ties_sway), Vector2(-13, 1 + ties_sway), Vector2(-5, -2)], scarf.darkened(0.2))
	var head := Vector2(1, -13)
	_shape(canvas, [head + Vector2(-3, -6), head + Vector2(-8, -4), head + Vector2(-10, 1),
		head + Vector2(-15, 5 + ties_sway), head + Vector2(-11, 6 + ties_sway),
		head + Vector2(-5, 3), head + Vector2(-3, 0)], hair)
	_line(canvas, head + Vector2(-7, -3), head + Vector2(-5, -2), scarf, 1.6)
	_face(canvas, head, skin, Color("#F6E3BF"), false)
	_shape(canvas, [head + Vector2(-7, 0), head + Vector2(-7, -5), head + Vector2(-3, -8),
		head + Vector2(4, -8), head + Vector2(7, -4), head + Vector2(11, -2),
		head + Vector2(4, -1), head + Vector2(-1, -2)], uniform.darkened(0.2))
	_line(canvas, head + Vector2(-4, -5), head + Vector2(4, -5), trim, 1.6)
	_shape(canvas, [Vector2(-5, -9), Vector2(2, -8), Vector2(6, -7),
		Vector2(3, -3), Vector2(-3, -4)], scarf, 1.3)

	var weapon_pos := body_pos - direction * clampf(recoil, 0.0, 1.0) * 3.0 * visual_scale
	canvas.draw_set_transform(weapon_pos, direction.angle(), Vector2(1.0, flip) * visual_scale)
	_weapon(canvas, false, true, uniform, trim, skin, Color("#E8C072"))
	_limb(canvas, Vector2(13, -6), Vector2(19, -6), STEEL, 2.4)
	_line(canvas, Vector2(17, -7), Vector2(19, -7), LIGHT_STEEL, 1.1)
	canvas.draw_set_transform(Vector2.ZERO)


static func draw_enemy(canvas: CanvasItem, enemy: Dictionary, time_s: float, target_pos: Vector2 = Vector2.ZERO) -> void:
	var pos := _position(enemy)
	var boss_id := str(enemy.get("boss_id", ""))
	var kind := str(enemy.get("type", ""))
	if kind.is_empty() and boss_id.is_empty():
		var enemy_name := str(enemy.get("name", ""))
		for enemy_type in GameData.ENEMIES:
			if GameData.ENEMIES[enemy_type]["name"] == enemy_name:
				kind = enemy_type
				break
	var is_boss := bool(enemy.get("is_boss", false))
	var appearance: Dictionary = GameData.BOSSES.get(boss_id, {}) if is_boss else GameData.ENEMIES.get(kind, {})
	var body := Color.from_string(str(enemy.get("color", appearance.get("color", "#4D7C0F"))), Color("#4D7C0F"))
	var accent := Color(str(appearance.get("accent_color", "#B4D66D")))
	var scale_factor := 1.18 * float(enemy.get("radius", 17.0)) / (21.0 if is_boss else 17.0)
	var flip := -1.0 if target_pos.x < pos.x else 1.0
	var frequency := 17.0 if kind == "fast" else (6.0 if kind == "tank" or is_boss else 10.0)
	var phase := time_s * frequency + float(enemy.get("id", 0)) * 2.39996
	var hover := kind == "spirit" or kind == "flying"
	var bob := -4.0 + sin(phase) * 2.0 if hover else -absf(cos(phase)) * 1.7
	var stride := sin(phase) * (4.8 if kind == "fast" else 3.0)

	canvas.draw_set_transform(pos, 0.0, Vector2.ONE * scale_factor)
	_shadow(canvas, 1.14 if is_boss or kind == "tank" else 1.0)
	canvas.draw_set_transform(pos + Vector2(0, bob * scale_factor), 0.0, Vector2(flip, 1) * scale_factor)
	if kind == "flying":
		_wings(canvas, sin(phase), body, accent)
	if kind == "spirit":
		_shape(canvas, [Vector2(-9, 0), Vector2(7, 2), Vector2(7, 10), Vector2(1, 12),
			Vector2(-6, 18), Vector2(-3, 9), Vector2(-11, 15), Vector2(-10, 7)], Color("#337B95"))
		_line(canvas, Vector2(-4, 7), Vector2(-7, 12), accent, 1.3)
	elif kind != "flying":
		_boots(canvas, stride, 1.25 if is_boss or kind == "tank" else 0.85, body.darkened(0.35))

	var maya := boss_id == "infected_maya"
	var bulk := 1.26 if (is_boss and not maya) or kind == "tank" else (0.82 if kind == "fast" else 1.0)
	_zombie_body(canvas, body, accent, bulk, stride, kind, maya)
	if is_boss and not maya:
		_boss_detail(canvas, boss_id, body, accent)
	if maya:
		var direction := (target_pos - pos).normalized()
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		canvas.draw_set_transform(pos + Vector2(0, bob * scale_factor), direction.angle(), Vector2(1, flip) * scale_factor)
		_weapon(canvas, false, true, body, accent.darkened(0.35), Color("#B6CD73"), accent)
	canvas.draw_set_transform(Vector2.ZERO)


static func draw_corpse(canvas: CanvasItem, corpse: Dictionary, pos: Vector2, drag_progress: float = 0.0) -> void:
	var boss := bool(corpse.get("boss", false))
	var kind := str(corpse.get("kind", "basic"))
	var boss_id := str(corpse.get("boss_id", ""))
	var appearance: Dictionary = GameData.BOSSES.get(boss_id, {}) if boss else GameData.ENEMIES.get(kind, {})
	var coat := Color.from_string(str(corpse.get("color", appearance.get("color", "#4D7C0F"))), Color("#4D7C0F"))
	var accent := Color.from_string(str(appearance.get("accent_color", "#B4D66D")), Color("#B4D66D"))
	var skin := coat.lerp(Color("#B9CA7B"), 0.62)
	var scale_factor := clampf(float(corpse.get("radius", 17.0)) / 17.0, 0.75, 2.85)
	var origin := Vector2(float(corpse.get("sx", 0.0)), float(corpse.get("sy", 0.0)))
	var edge := Vector2(float(corpse.get("ex", 0.0)), float(corpse.get("ey", 0.0)))
	var angle := (edge - origin).angle()
	var tremble := sin(drag_progress * TAU * 4.0) * 0.055 if drag_progress > 0.0 else 0.0
	canvas.draw_set_transform(pos, angle + tremble, Vector2.ONE * scale_factor)
	canvas.draw_circle(Vector2(0, 5), 22.0, Color(0.03, 0.04, 0.05, 0.34))
	_limb(canvas, Vector2(-9, -5), Vector2(-23, -11), coat.darkened(0.42), 5.0)
	_limb(canvas, Vector2(-9, 5), Vector2(-24, 10), coat.darkened(0.35), 5.0)
	_limb(canvas, Vector2(-1, -8), Vector2(3, -20), skin.darkened(0.22), 4.2)
	_limb(canvas, Vector2(1, 8), Vector2(-2, 21), skin, 4.2)
	_shape(canvas, [Vector2(-13, -9), Vector2(-2, -12), Vector2(13, -8),
		Vector2(15, 6), Vector2(5, 12), Vector2(-11, 9)], coat, 2.0)
	_shape(canvas, [Vector2(-9, -8), Vector2(-2, -10), Vector2(4, -6),
		Vector2(0, -2), Vector2(-11, -1)], coat.lightened(0.2), 0.0)
	_line(canvas, Vector2(-1, -8), Vector2(7, 8), coat.darkened(0.5), 2.3)
	_line(canvas, Vector2(7, -5), Vector2(2, -1), accent, 1.7)
	_face(canvas, Vector2(18, 0), skin, accent.lightened(0.35), true)
	if boss:
		_shape(canvas, [Vector2(8, -10), Vector2(14, -18), Vector2(20, -10),
			Vector2(25, -16), Vector2(24, -6)], accent.darkened(0.25), 1.5)
		_line(canvas, Vector2(-7, 7), Vector2(7, 9), accent.darkened(0.2), 2.4)
	if kind == "flying":
		_shape(canvas, [Vector2(-7, -9), Vector2(-19, -24), Vector2(-15, -7)], coat.darkened(0.12))
		_shape(canvas, [Vector2(-7, 9), Vector2(-20, 22), Vector2(-10, 11)], coat.darkened(0.15))
	elif kind == "spirit":
		_shape(canvas, [Vector2(-13, -9), Vector2(-24, -2), Vector2(-17, 12),
			Vector2(-4, 8)], Color(coat, 0.46), 0.0)
	canvas.draw_set_transform(Vector2.ZERO)


static func draw_human_tumbleweed(canvas: CanvasItem, pos: Vector2, time_s: float, radius: float, corpse_count: int, infected_maya: bool = false) -> void:
	var scale_factor := maxf(radius, 1.0) / 24.0
	var roll := time_s * 4.4
	var body_pos := pos + Vector2(0, -absf(sin(roll * 2.0)) * 1.5 * scale_factor)
	var limb_count := clampi(4 + corpse_count, 5, 10)
	var stitches := Color("#BDA474")
	var olive := Color("#58634A")
	var hide := Color("#9E9972")
	var eye := Color("#D5E69B")
	var scarf := Color("#C95C46")
	canvas.draw_set_transform(pos + Vector2(0, 9 * scale_factor), 0.0, Vector2.ONE * scale_factor)
	_shadow(canvas, 1.52)

	for i in range(limb_count):
		var wave := sin(time_s * 7.5 + i * 2.3)
		var joint := Vector2(17, 4 + wave * 2)
		var end := Vector2(23 + wave * 2, -1 - wave * 2)
		var worn_cloth := olive if i % 3 == 0 else Color("#6B594E")
		canvas.draw_set_transform(body_pos, roll + TAU * i / limb_count, Vector2.ONE * scale_factor)
		_limb(canvas, Vector2(5, -4), joint, worn_cloth, 6.0)
		if i % 2 == 0:
			_limb(canvas, joint, end, hide, 4.0)
			_shape(canvas, [end + Vector2(-2, 2), end + Vector2(1, 3), end + Vector2(5, 0),
				end + Vector2(3, -3), end + Vector2(1, -2), end + Vector2(-1, -3)], hide, 1.1)
			_line(canvas, end + Vector2(2, 0), end + Vector2(4, -1), INK, 0.9)
		else:
			_limb(canvas, joint, end, worn_cloth, 5.4)
			_limb(canvas, end, end + Vector2(1, -5), STEEL.darkened(0.38), 5.0)
			_line(canvas, end + Vector2(1, -2), end + Vector2(2, -4), STEEL, 1.35)
		_line(canvas, joint + Vector2(-4, -1), joint + Vector2(-2, 1), stitches, 1.1)

	canvas.draw_set_transform(body_pos, roll, Vector2.ONE * scale_factor)
	_shape(canvas, [Vector2(-17, -6), Vector2(-10, -15), Vector2(1, -16), Vector2(13, -11),
		Vector2(17, -2), Vector2(14, 11), Vector2(3, 16), Vector2(-11, 12), Vector2(-16, 4)], Color("#413F39"), 2.1)
	_shape(canvas, [Vector2(-12, -9), Vector2(-2, -13), Vector2(7, -8), Vector2(4, 0),
		Vector2(-8, 6), Vector2(-15, 0)], olive)
	_shape(canvas, [Vector2(4, -6), Vector2(15, -2), Vector2(12, 8), Vector2(4, 13),
		Vector2(-5, 11), Vector2(-5, 5)], Color("#7E6652"))
	_limb(canvas, Vector2(-10, -9), Vector2(8, 9), Color("#926E47"), 2.2)
	_line(canvas, Vector2(-2, -1), Vector2(1, 2), stitches, 1.3)
	_face(canvas, Vector2(5, 6), hide, eye, true)

	if infected_maya:
		var head := Vector2(-6, -8)
		_shape(canvas, [head + Vector2(-4, -4), head + Vector2(-8, -2), head + Vector2(-13, 5),
			head + Vector2(-9, 5), head + Vector2(-3, 1)], Color("#552F31"))
		_face(canvas, head, Color("#B6CD73"), eye, true)
		_shape(canvas, [head + Vector2(-7, -2), head + Vector2(-5, -8), head + Vector2(3, -8),
			head + Vector2(6, -4), head + Vector2(10, -2), head + Vector2(3, -1)], olive)
		_line(canvas, head + Vector2(-4, -5), head + Vector2(3, -5), stitches, 1.4)
		_shape(canvas, [Vector2(-11, -4), Vector2(-5, -3), Vector2(-1, 0), Vector2(-6, 2),
			Vector2(-12, 0), Vector2(-20, 3 + sin(time_s * 8.0)), Vector2(-17, -2)], scarf, 1.25)
		_limb(canvas, Vector2(6, -12), Vector2(24, -7), STEEL, 3.6)
		_limb(canvas, Vector2(6, -12), Vector2(12, -10), Color("#79654D"), 4.8)
		_limb(canvas, Vector2(13, -13), Vector2(17, -12), STEEL, 2.1)
		_line(canvas, Vector2(17, -10), Vector2(23, -8), LIGHT_STEEL, 1.05)
	else:
		_face(canvas, Vector2(-6, -7), hide.darkened(0.12), eye, true)
	canvas.draw_set_transform(Vector2.ZERO)


static func draw_clone(canvas: CanvasItem, clone: Dictionary, time_s: float, target_pos: Vector2 = Vector2.ZERO) -> void:
	var pos := _position(clone)
	canvas.draw_arc(pos + Vector2(0, 8), 16.0, 0, TAU, 26, Color("#4ADEB9"), 1.25, true)
	draw_player(canvas, {
		"x": pos.x, "y": pos.y, "angle": (target_pos - pos).angle(), "hero_class": "ranger",
	}, time_s + 0.8)
	canvas.draw_line(pos + Vector2(-10, -19), pos + Vector2(-6, -23), Color("#4ADEB9"), 2.0, true)


static func _position(actor: Dictionary) -> Vector2:
	return Vector2(float(actor.get("x", 0.0)), float(actor.get("y", 0.0)))


static func _shadow(canvas: CanvasItem, width: float) -> void:
	_shape(canvas, [Vector2(-15, 8) * width, Vector2(-11, 3) * width, Vector2(6, 3) * width,
		Vector2(15, 8) * width, Vector2(11, 14) * width, Vector2(-9, 15) * width], SHADOW, 0.0)


static func _shape(canvas: CanvasItem, vertices: Array[Vector2], color: Color, outline: float = 1.6) -> void:
	var points := PackedVector2Array(vertices)
	canvas.draw_colored_polygon(points, color)
	if outline > 0.0:
		points.append(points[0])
		canvas.draw_polyline(points, INK, outline, true)


static func _line(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, width: float) -> void:
	canvas.draw_line(start, end, color, width, true)


static func _limb(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, width: float) -> void:
	_line(canvas, start, end, INK, width + 2.4)
	_line(canvas, start, end, color, width)


static func _boots(canvas: CanvasItem, stride: float, weight: float, cloth: Color) -> void:
	for side in [-1.0, 1.0]:
		var hip := Vector2(side * 4.3 * weight, 5)
		var ankle := Vector2(side * 5.7 * weight + stride * side, 13.0 - maxf(0, stride * side) * 0.6)
		_limb(canvas, hip, ankle, cloth, 5.2 * weight)
		_limb(canvas, ankle, ankle + Vector2(3.5 * weight, 1), STEEL.darkened(0.42), 4.5 * weight)
		_line(canvas, ankle + Vector2(1, -1), ankle + Vector2(3, -0.2), STEEL, 1.2)


static func _gear(canvas: CanvasItem) -> void:
	_shape(canvas, [Vector2(-7, -1), Vector2(-3, -1), Vector2(-3, 4), Vector2(-7, 4)], Color("#6D7450"), 1.0)
	_line(canvas, Vector2(-6, 0), Vector2(-4, 0), Color("#D0B782"), 1.05)


static func _face(canvas: CanvasItem, center: Vector2, skin: Color, eye: Color, undead: bool) -> void:
	_shape(canvas, [center + Vector2(-5, -4), center + Vector2(2, -6), center + Vector2(5, -3),
		center + Vector2(6, 0), center + Vector2(4, 4), center + Vector2(1, 6), center + Vector2(-5, 3)], skin)
	_line(canvas, center + Vector2(-2, -3), center + Vector2(4, -2), INK, 2.4)
	_line(canvas, center + Vector2(0, -2), center + Vector2(4, -1.5), eye, 1.3)
	if undead:
		_line(canvas, center + Vector2(0, 3), center + Vector2(4, 2), INK, 2.5)
		_line(canvas, center + Vector2(1, 2.5), center + Vector2(3.5, 2), Color("#E9E7C4"), 1.1)


static func _weapon(canvas: CanvasItem, energy_weapon: bool, long_weapon: bool, sleeve: Color, cuff: Color, skin: Color, accent: Color) -> void:
	var support := Vector2(16, 0)
	var grip := Vector2(9, 3)
	_limb(canvas, Vector2(-2, 5), grip, sleeve, 5.6)
	_limb(canvas, Vector2(1, -3), support, sleeve.darkened(0.12), 4.8)
	_line(canvas, Vector2(9, -1.4), support, cuff, 1.9)
	if energy_weapon:
		var barrel := 30.0 if long_weapon else 24.0
		var receiver := 4.0 if long_weapon else 8.0
		_shape(canvas, [Vector2(receiver, -4), Vector2(barrel - 3, -5), Vector2(barrel, -2),
			Vector2(barrel, 2), Vector2(receiver + 5, 3), Vector2(receiver, 1)], STEEL)
		_line(canvas, Vector2(receiver + 3, -1), Vector2(barrel - 3, -2), accent, 1.6)
		canvas.draw_circle(Vector2(barrel + 1, 0), 4, Color(accent, 0.24), true, -1.0, true)
		_line(canvas, Vector2(barrel - 1, -1), Vector2(barrel - 1, 1), accent, 1.6)
	else:
		var barrel := 30.0 if long_weapon else 23.0
		if long_weapon:
			_shape(canvas, [Vector2(3, -3), Vector2(11, -3), Vector2(11, 2), Vector2(4, 3)], STEEL)
			_shape(canvas, [Vector2(12, 0), Vector2(17, 0), Vector2(17, 7), Vector2(13, 8)], STEEL)
		_shape(canvas, [Vector2(8, -4), Vector2(barrel, -4), Vector2(barrel, 0),
			Vector2(17, 1), Vector2(15, 4), Vector2(10, 4), Vector2(10, 0), Vector2(8, 0)], STEEL)
		_line(canvas, Vector2(10, -2.5), Vector2(barrel - 2, -2.5), LIGHT_STEEL, 1.2)
		_line(canvas, Vector2(barrel - 2, -3.5), Vector2(barrel - 2, 0), accent, 1.3)
	canvas.draw_circle(grip, 2.25, skin, true, -1.0, true)
	canvas.draw_circle(support + Vector2(0, 0.8), 2.0, skin, true, -1.0, true)


static func _zombie_body(canvas: CanvasItem, body: Color, accent: Color, bulk: float, stride: float, kind: String, maya: bool) -> void:
	var shoulder := 9.1 * bulk
	var lean := 3.0 if kind == "fast" else 0.0
	var skin := body.lerp(Color("#BAC877"), 0.62)
	var far_hand := Vector2(9 + lean, -2 + stride * 0.65)
	_limb(canvas, Vector2(shoulder * 0.64, -4), far_hand, skin.darkened(0.24), 4.3 * bulk)
	_shape(canvas, [Vector2(-shoulder, -5), Vector2(-3, -8), Vector2(shoulder, -5), Vector2(shoulder + 1, 0),
		Vector2(5 * bulk, 8), Vector2(1, 6), Vector2(-2, 9), Vector2(-7 * bulk, 6)], body)
	_line(canvas, Vector2(-shoulder + 3, -4), Vector2(2, -5), body.lightened(0.43), 2.2)
	_line(canvas, Vector2(-3, -1), Vector2(4, 4), body.darkened(0.45), 2.1)
	_line(canvas, Vector2(0, 1), Vector2(3, 0), accent, 1.2)
	var hand := Vector2(9 + lean, 4 - stride * 0.68)
	_limb(canvas, Vector2(-shoulder + 2, -1), Vector2(-4, 5), body.lightened(0.1), 5.5 * bulk)
	_limb(canvas, Vector2(-4, 5), hand, skin, 4.0 * bulk)
	for y in [-1.5, 1.1]:
		_line(canvas, hand + Vector2(0, y), hand + Vector2(2.5, y), INK, 1.0)

	var head := Vector2(2 + lean, -9)
	if maya:
		_shape(canvas, [head + Vector2(-5, -4), head + Vector2(-9, 0),
			head + Vector2(-14, 8), head + Vector2(-7, 6), head + Vector2(-2, 2)], Color("#372636"))
	_face(canvas, head, skin, accent.lightened(0.45), true)
	match kind:
		"elite":
			_shape(canvas, [Vector2(-10, -5), Vector2(-14, -9), Vector2(-10, -12),
				Vector2(-4, -7), Vector2(-6, -3)], accent.darkened(0.3))
			canvas.draw_circle(head + Vector2(3, 4), 2.6, accent, true, -1, true)
		"tank":
			_armor(canvas, Vector2(-10, -3), body.lightened(0.26), accent)
			_armor(canvas, Vector2(7, -3), body.lightened(0.2), accent)
		"fast":
			_line(canvas, head + Vector2(-4, -5), head + Vector2(3, -5), accent, 2.2)
		"spirit":
			_line(canvas, head + Vector2(-3, -6), head + Vector2(2, -8), accent, 1.7)
	if maya:
		_shape(canvas, [head + Vector2(-7, -2), head + Vector2(-6, -7), head + Vector2(2, -8),
			head + Vector2(6, -4), head + Vector2(9, -3), head + Vector2(1, -2)], Color("#415636"))
		_line(canvas, head + Vector2(-4, -5), head + Vector2(3, -5), accent, 1.5)


static func _wings(canvas: CanvasItem, flap: float, body: Color, accent: Color) -> void:
	for side in [-1.0, 1.0]:
		var tip := Vector2(side * (17 + flap * 2), -9 - flap * 5)
		var root := Vector2(side * 4, -6)
		_shape(canvas, [root, tip, Vector2(side * 15, 4), Vector2(side * 10, 1),
			Vector2(side * 9, 7), Vector2(side * 5, 2)], body.darkened(0.28))
		_line(canvas, root, tip.lerp(root, 0.26), accent.darkened(0.35), 1.6)


static func _armor(canvas: CanvasItem, pos: Vector2, plate: Color, accent: Color) -> void:
	_shape(canvas, [pos + Vector2(-4, -2), pos + Vector2(4, -3), pos + Vector2(5, 1),
		pos + Vector2(2, 4), pos + Vector2(-3, 3)], plate)
	canvas.draw_circle(pos + Vector2(-1, -0.5), 1.3, accent, true, -1, true)


static func _boss_detail(canvas: CanvasItem, boss_id: String, body: Color, accent: Color) -> void:
	match boss_id:
		"village_boss":
			_shape(canvas, [Vector2(-5, -11), Vector2(-7, -21), Vector2(-1, -17), Vector2(3, -22),
				Vector2(5, -17), Vector2(9, -18), Vector2(7, -12)], accent.darkened(0.19))
			_line(canvas, Vector2(-3, -14), Vector2(6, -14), accent.lightened(0.22), 1.5)
		"forest_boss":
			_shape(canvas, [Vector2(-11, 3), Vector2(-18, -5), Vector2(-14, -7), Vector2(-18, -13),
				Vector2(-8, -9), Vector2(-3, -6), Vector2(-4, 2)], body.lightened(0.16))
			_line(canvas, Vector2(-15, -10), Vector2(-9, -6), accent, 1.3)
			_line(canvas, Vector2(7, -7), Vector2(9, -3), Color("#E3EBBD"), 1.9)
		"city_boss":
			_armor(canvas, Vector2(-12, -5), STEEL.lightened(0.13), accent)
			_armor(canvas, Vector2(10, -5), STEEL.lightened(0.13), accent)
			_line(canvas, Vector2(-2, -12), Vector2(8, -12), INK, 4.7)
			_line(canvas, Vector2(0, -12), Vector2(8, -12), accent, 1.8)
		"laboratory_boss":
			_limb(canvas, Vector2(-11, -10), Vector2(-12, 3), accent.darkened(0.35), 4.8)
			_limb(canvas, Vector2(11, -9), Vector2(10, 2), accent.darkened(0.35), 4.8)
			_line(canvas, Vector2(-11, -8), Vector2(-12, -1), accent.lightened(0.34), 1.8)
			_line(canvas, Vector2(11, -7), Vector2(10, -2), accent.lightened(0.34), 1.8)
		"final_boss":
			for side in [-1.0, 1.0]:
				_shape(canvas, [Vector2(side * 6, -10), Vector2(side * 12, -14), Vector2(side * 13, -21),
					Vector2(side * 6, -18), Vector2(side * 3, -13)], accent.darkened(0.16))
			_armor(canvas, Vector2(-10, -3), body.lightened(0.22), accent)
			_armor(canvas, Vector2(9, -3), body.lightened(0.22), accent)
