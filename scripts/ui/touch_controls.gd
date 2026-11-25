extends Control

@onready var joystick_pad: Control = $JoystickPad
@onready var fire_btn: Button = $ActionCluster/FireBtn

var move_vector: Vector2 = Vector2.ZERO
var is_firing: bool:
	get:
		return _fire_touch_idx >= 0 or _fire_mouse_down

var _joy_touch_idx: int = -1
var _joy_knob: Vector2 = Vector2.ZERO
var _fire_touch_idx: int = -1
var _fire_mouse_down: bool = false
const JOY_RADIUS := 58.0
const MOUSE_POINTER := -2


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

	fire_btn.gui_input.connect(_on_fire_input)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_clear_controls()
	)


func _draw_joystick() -> void:
	var c := joystick_pad.size * 0.5
	joystick_pad.draw_circle(c, JOY_RADIUS + 8.0, Color(0.08, 0.12, 0.18, 0.55))
	joystick_pad.draw_arc(c, JOY_RADIUS + 8.0, 0.0, TAU, 32, Color(0.96, 0.62, 0.04, 0.65), 2.5)
	joystick_pad.draw_circle(c + _joy_knob, 24.0, Color(0.96, 0.62, 0.04, 0.85))
	joystick_pad.draw_arc(c + _joy_knob, 24.0, 0.0, TAU, 24, Color("#FEF3C7"), 2.0)


func _on_joy_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var center := joystick_pad.size * 0.5
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and not st.canceled and _joy_touch_idx == -1:
			_joy_touch_idx = st.index
			_update_knob(st.position - center)
		elif (not st.pressed or st.canceled) and st.index == _joy_touch_idx:
			_reset_knob()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _joy_touch_idx:
			_update_knob(sd.position - center)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _joy_touch_idx == -1:
				_joy_touch_idx = MOUSE_POINTER
				_update_knob(mb.position - center)
			elif not mb.pressed and _joy_touch_idx == MOUSE_POINTER:
				_reset_knob()
	elif event is InputEventMouseMotion and _joy_touch_idx == MOUSE_POINTER:
		var mm := event as InputEventMouseMotion
		_update_knob(mm.position - center)


func _on_fire_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION or fire_btn.disabled:
		return
	if event is InputEventScreenTouch and event.pressed and not event.canceled and _fire_touch_idx < 0:
		_fire_touch_idx = event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_fire_mouse_down = true


func _input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch and (not event.pressed or event.canceled):
		if event.index == _fire_touch_idx:
			_fire_touch_idx = -1
		if event.index == _joy_touch_idx:
			_reset_knob()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_fire_mouse_down = false
		if _joy_touch_idx == MOUSE_POINTER:
			_reset_knob()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_node_ready():
		_clear_controls()


func _clear_controls() -> void:
	_fire_touch_idx = -1
	_fire_mouse_down = false
	_reset_knob()


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
