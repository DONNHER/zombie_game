extends Node

var _canvas_layer: CanvasLayer
var _filter_rect: ColorRect
var _shader_mat: ShaderMaterial
var _app_theme: Theme


func _ready() -> void:
	_setup_colorblind_overlay()
	_setup_theme()
	_apply_settings(SaveManager.settings)
	SaveManager.settings_changed.connect(_apply_settings)


func _setup_colorblind_overlay() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 100
	add_child(_canvas_layer)

	_filter_rect = ColorRect.new()
	_filter_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter_rect.color = Color(1.0, 1.0, 1.0, 1.0)

	var shader := load("res://shaders/colorblind.gdshader") as Shader
	if shader:
		_shader_mat = ShaderMaterial.new()
		_shader_mat.shader = shader
		_shader_mat.set_shader_parameter("mode", 0)
		_filter_rect.material = _shader_mat

	_canvas_layer.add_child(_filter_rect)


func _setup_theme() -> void:
	_app_theme = Theme.new()
	_app_theme.default_font_size = 15

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color("#1E293B")
	btn_normal.border_color = Color("#334155")
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(8)
	btn_normal.content_margin_left = 12
	btn_normal.content_margin_right = 12
	btn_normal.content_margin_top = 8
	btn_normal.content_margin_bottom = 8

	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color("#283548")
	btn_hover.border_color = Color("#64748B")

	var btn_pressed := btn_normal.duplicate()
	btn_pressed.bg_color = Color("#0F172A")
	btn_pressed.border_color = Color("#F59E0B")

	var btn_disabled := btn_normal.duplicate()
	btn_disabled.bg_color = Color("#131A24")
	btn_disabled.border_color = Color("#1E293B")

	_app_theme.set_stylebox("normal", "Button", btn_normal)
	_app_theme.set_stylebox("hover", "Button", btn_hover)
	_app_theme.set_stylebox("pressed", "Button", btn_pressed)
	_app_theme.set_stylebox("disabled", "Button", btn_disabled)
	_app_theme.set_color("font_color", "Button", Color("#F1F5F9"))
	_app_theme.set_color("font_hover_color", "Button", Color("#FFFFFF"))
	_app_theme.set_color("font_disabled_color", "Button", Color("#64748B"))

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color("#1A222D")
	panel_sb.border_color = Color("#2B3748")
	panel_sb.set_border_width_all(1)
	panel_sb.set_corner_radius_all(10)
	_app_theme.set_stylebox("panel", "PanelContainer", panel_sb)

	var input_sb := StyleBoxFlat.new()
	input_sb.bg_color = Color("#0E141C")
	input_sb.border_color = Color("#334155")
	input_sb.set_border_width_all(1)
	input_sb.set_corner_radius_all(8)
	input_sb.content_margin_left = 10
	input_sb.content_margin_right = 10
	input_sb.content_margin_top = 6
	input_sb.content_margin_bottom = 6
	_app_theme.set_stylebox("normal", "LineEdit", input_sb)

	get_tree().root.theme = _app_theme


func _apply_settings(s: Dictionary) -> void:
	var mode_str := str(s.get("color_blind_mode", "normal"))
	var mode_idx := 0
	match mode_str:
		"deuteranopia":
			mode_idx = 1
		"protanopia":
			mode_idx = 2
		"tritanopia":
			mode_idx = 3
		_:
			mode_idx = 0

	if _shader_mat:
		_shader_mat.set_shader_parameter("mode", mode_idx)
	_filter_rect.visible = mode_idx > 0

	var size_str := str(s.get("text_size", "normal"))
	var font_sz := 15
	if size_str == "large":
		font_sz = 18
	elif size_str == "xlarge":
		font_sz = 21
	if _app_theme:
		_app_theme.default_font_size = font_sz
