extends Control

const ComicActorDraw = preload("res://scripts/game/comic_actor_draw.gd")

@export var hero_class: String = "ranger":
	set(v):
		hero_class = v
		queue_redraw()

@export var gender: String = "male":
	set(v):
		gender = v
		queue_redraw()

@export var weapon_color: Color = Color("#F59E0B"):
	set(v):
		weapon_color = v
		queue_redraw()

var _weapon_id: String = "basic_pistol"
var _pulse: float = 0.0


func configure(p_class: String, p_gender: String, p_weapon_id: String = "") -> void:
	hero_class = p_class
	gender = p_gender
	_weapon_id = p_weapon_id if p_weapon_id != "" and GameData.WEAPONS.has(p_weapon_id) else ("basic_wand" if p_class == "medic" else "basic_pistol")
	weapon_color = Color(str(GameData.WEAPONS[_weapon_id]["color"]))
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var scale := clampf(minf(size.x, size.y) / 96.0 * 2.15, 1.0, 3.0)
	var aura := Color("#34D399") if hero_class == "medic" else Color("#F59E0B")
	draw_circle(center + Vector2(0, 18), 32.0, Color(aura, 0.13))
	ComicActorDraw.draw_player(self, {
		"x": center.x - 10.0, "y": center.y + 8.0,
		"angle": -0.12, "hero_class": hero_class, "gender": gender,
		"weapon_id": _weapon_id, "visual_scale": scale, "visual_moving": true,
	}, _pulse, true)
