extends Control

signal entered

@onready var hero_preview: Control = $CenterBox/Card/VBox/HeroPreview
@onready var boot_bar: ProgressBar = $CenterBox/Card/VBox/BootBar
@onready var enter_btn: Button = $CenterBox/Card/VBox/EnterButton
@onready var status_label: Label = $CenterBox/Card/VBox/StatusLabel
@onready var card: PanelContainer = $CenterBox/Card

var _progress: float = 0.0
var _ready_to_enter: bool = false


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#131A24")
	sb.border_color = Color("#F59E0B")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", sb)

	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color("#D97706")
	btn_sb.set_corner_radius_all(10)
	enter_btn.add_theme_stylebox_override("normal", btn_sb)

	var save := SaveManager.save_data
	hero_preview.configure(str(save.get("hero_class", "ranger")), str(save.get("gender", "male")))

	enter_btn.pressed.connect(_on_enter_pressed)
	boot_bar.value = 0.0
	enter_btn.disabled = true


func _process(delta: float) -> void:
	if _progress < 100.0:
		_progress = minf(100.0, _progress + delta * 185.0)
		boot_bar.value = _progress
		if _progress >= 100.0:
			_ready_to_enter = true
			enter_btn.disabled = false
			status_label.text = "Armory & local bunker save ready · Tap or press Enter"


func _unhandled_input(event: InputEvent) -> void:
	if visible and _ready_to_enter and event is InputEventKey and event.pressed:
		var kev := event as InputEventKey
		if kev.keycode == KEY_ENTER or kev.keycode == KEY_KP_ENTER or kev.keycode == KEY_SPACE:
			_on_enter_pressed()


func _on_enter_pressed() -> void:
	AudioManager.play_pickup()
	entered.emit()
