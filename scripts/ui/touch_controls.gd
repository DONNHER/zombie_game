extends Control

@onready var joystick_pad: Control = $JoystickPad
@onready var fire_btn: Button = $ActionCluster/FireBtn

var move_vector: Vector2 = Vector2.ZERO
var is_firing: bool = false

var _joy_touch_idx: int = -1
var _joy_knob: Vector2 = Vector2.ZERO
const JOY_RADIUS := 58.0


func _ready() -> void:
	joystick_pad.draw.connect(_draw_joystick)
	joystick_pad.gui_input.connect(_on_joy_input)

	var f_sb := StyleBoxFlat.new()
	f_sb.bg_color = Color("#DC2626")
	f_sb.border_color = Color("#FCA5A5")
	f_sb.set_border_width_all(2)
	f_sb.set_corner_radius_all(46)
	fire_btn.add_theme_stylebox_override("normal", f_sb)

	var f_press := f_sb.duplicate()
	f_press.bg_color = Color("#991B1B")
	fire_btn.add_theme_stylebox_override("pressed", f_press)

	fire_btn.button_down.connect(func() -> void: is_firing = true)
	fire_btn.button_up.connect(func() -> void: is_firing = false)


func _draw_joystick() -> void:
	var c := joystick_pad.size * 0.5
	joystick_pad.draw_circle(c, JOY_RADIUS + 8.0, Color(0.08, 0.12, 0.18, 0.55))
	joystick_pad.draw_arc(c, JOY_RADIUS + 8.0, 0.0, TAU, 32, Color(0.96, 0.62, 0.04, 0.65), 2.5)
	joystick_pad.draw_circle(c + _joy_knob, 24.0, Color(0.96, 0.62, 0.04, 0.85))
	joystick_pad.draw_arc(c + _joy_knob, 24.0, 0.0, TAU, 24, Color("#FEF3C7"), 2.0)


func _on_joy_input(event: InputEvent) -> void:
	var center := joystick_pad.size * 0.5
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _joy_touch_idx == -1:
			_joy_touch_idx = st.index
			_update_knob(st.position - center)
		elif not st.pressed and st.index == _joy_touch_idx:
			_reset_knob()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _joy_touch_idx:
			_update_knob(sd.position - center)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_joy_touch_idx = 999
				_update_knob(mb.position - center)
			else:
				_reset_knob()
	elif event is InputEventMouseMotion and _joy_touch_idx == 999:
		var mm := event as InputEventMouseMotion
		_update_knob(mm.position - center)


func _update_knob(offset: Vector2) -> void:
	var clamped := offset.limit_length(JOY_RADIUS)
	_joy_knob = clamped
	move_vector = clamped / JOY_RADIUS if clamped.length() > 6.0 else Vector2.ZERO
	joystick_pad.queue_redraw()


func _reset_knob() -> void:
	_joy_touch_idx = -1
	_joy_knob = Vector2.ZERO
	move_vector = Vector2.ZERO
	joystick_pad.queue_redraw()
