extends Control

signal closed

@onready var title_label: Label = $Center/Panel/Margin/Scroll/VBox/Header/Title
@onready var close_btn: Button = $Center/Panel/Margin/Scroll/VBox/Header/CloseBtn
@onready var mute_check: CheckButton = $Center/Panel/Margin/Scroll/VBox/MuteCheck
@onready var vol_slider: HSlider = $Center/Panel/Margin/Scroll/VBox/VolRow/VolSlider
@onready var vol_val: Label = $Center/Panel/Margin/Scroll/VBox/VolRow/VolVal
@onready var vibration_check: CheckButton = $Center/Panel/Margin/Scroll/VBox/VibrationCheck
@onready var shake_check: CheckButton = $Center/Panel/Margin/Scroll/VBox/ShakeCheck
@onready var day_night_check: CheckButton = $Center/Panel/Margin/Scroll/VBox/DayNightCheck
@onready var dmg_check: CheckButton = $Center/Panel/Margin/Scroll/VBox/DmgCheck
@onready var lang_option: OptionButton = $Center/Panel/Margin/Scroll/VBox/LangRow/LangOption
@onready var cb_option: OptionButton = $Center/Panel/Margin/Scroll/VBox/CbRow/CbOption
@onready var text_option: OptionButton = $Center/Panel/Margin/Scroll/VBox/TextRow/TextOption
@onready var reset_btn: Button = $Center/Panel/Margin/Scroll/VBox/ResetRow/ResetBtn
@onready var confirm_reset_btn: Button = $Center/Panel/Margin/Scroll/VBox/ResetRow/ConfirmResetBtn

var _lang_keys: Array[String] = ["en", "es", "fil"]
var _cb_keys: Array[String] = ["normal", "deuteranopia", "protanopia", "tritanopia"]
var _text_keys: Array[String] = ["normal", "large", "xlarge"]


func _ready() -> void:
	lang_option.clear()
	lang_option.add_item("English")
	lang_option.add_item("Español")
	lang_option.add_item("Filipino")

	cb_option.clear()
	cb_option.add_item("Standard")
	cb_option.add_item("Deuteranopia (Red-Green)")
	cb_option.add_item("Protanopia (Red-Weak)")
	cb_option.add_item("Tritanopia (Blue-Yellow)")

	text_option.clear()
	text_option.add_item("Normal")
	text_option.add_item("Large (+20%)")
	text_option.add_item("Extra Large (+40%)")

	close_btn.pressed.connect(func() -> void:
		confirm_reset_btn.hide()
		hide()
		closed.emit()
	)
	mute_check.toggled.connect(func(v: bool) -> void: SaveManager.write_settings({"muted": v}))
	vol_slider.value_changed.connect(func(v: float) -> void:
		vol_val.text = "%d%%" % int(round(v))
		SaveManager.write_settings({"volume": clampf(v / 100.0, 0.0, 1.0)})
	)
	vibration_check.toggled.connect(func(v: bool) -> void:
		SaveManager.write_settings({"vibration": v})
		if v:
			AudioManager.trigger_haptic(35)
	)
	shake_check.toggled.connect(func(v: bool) -> void: SaveManager.write_settings({"screen_shake": v}))
	day_night_check.toggled.connect(func(v: bool) -> void: SaveManager.write_settings({"day_night_effects": v}))
	dmg_check.toggled.connect(func(v: bool) -> void: SaveManager.write_settings({"show_damage_numbers": v}))
	lang_option.item_selected.connect(func(idx: int) -> void:
		SaveManager.write_settings({"language": _lang_keys[idx]})
		_sync_ui()
	)
	cb_option.item_selected.connect(func(idx: int) -> void:
		SaveManager.write_settings({"color_blind_mode": _cb_keys[idx]})
	)
	text_option.item_selected.connect(func(idx: int) -> void:
		SaveManager.write_settings({"text_size": _text_keys[idx]})
	)
	reset_btn.pressed.connect(func() -> void:
		confirm_reset_btn.visible = not confirm_reset_btn.visible
	)
	confirm_reset_btn.pressed.connect(func() -> void:
		SaveManager.reset_local_save()
		confirm_reset_btn.hide()
		AudioManager.play_pickup()
	)
	_sync_ui()


func open_modal() -> void:
	confirm_reset_btn.hide()
	_sync_ui()
	show()


func _sync_ui() -> void:
	var s := SaveManager.settings
	var lang := str(s.get("language", "en"))
	title_label.text = GameData.t(lang, "settings") + " · Accessibility"
	mute_check.set_pressed_no_signal(bool(s.get("muted", false)))
	var vol_pct := int(round(float(s.get("volume", 0.55)) * 100.0))
	vol_slider.set_value_no_signal(float(vol_pct))
	vol_val.text = "%d%%" % vol_pct
	vibration_check.set_pressed_no_signal(bool(s.get("vibration", true)))
	shake_check.set_pressed_no_signal(bool(s.get("screen_shake", true)))
	day_night_check.set_pressed_no_signal(bool(s.get("day_night_effects", true)))
	dmg_check.set_pressed_no_signal(bool(s.get("show_damage_numbers", true)))
	lang_option.select(maxi(0, _lang_keys.find(lang)))
	cb_option.select(maxi(0, _cb_keys.find(str(s.get("color_blind_mode", "normal")))))
	text_option.select(maxi(0, _text_keys.find(str(s.get("text_size", "normal")))))
