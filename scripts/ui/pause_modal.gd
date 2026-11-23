extends Control

signal resume_pressed
signal restart_pressed
signal settings_pressed
signal lobby_pressed

@onready var resume_btn: Button = $Center/Panel/Margin/VBox/ResumeBtn
@onready var restart_btn: Button = $Center/Panel/Margin/VBox/RestartBtn
@onready var settings_btn: Button = $Center/Panel/Margin/VBox/SettingsBtn
@onready var lobby_btn: Button = $Center/Panel/Margin/VBox/LobbyBtn
@onready var title_lbl: Label = $Center/Panel/Margin/VBox/Title
@onready var sub_lbl: Label = $Center/Panel/Margin/VBox/Sub

var _team_mode: bool = false


func configure_team_pause(team_mode: bool, owner_name: String = "") -> void:
	_team_mode = team_mode
	title_lbl.text = "SQUAD PAUSED" if team_mode else "GAME PAUSED"
	sub_lbl.text = "%s paused the squad. Anyone can resume." % owner_name if team_mode else "Hold the bunker line or adjust settings."
	resume_btn.text = "Resume Squad" if team_mode else "Resume Match"
	restart_btn.text = "Leave Squad Match" if team_mode else "Restart Stage"


func _ready() -> void:
	var r_sb := StyleBoxFlat.new()
	r_sb.bg_color = Color("#22C55E")
	r_sb.set_corner_radius_all(8)
	resume_btn.add_theme_stylebox_override("normal", r_sb)
	resume_btn.add_theme_color_override("font_color", Color("#0F172A"))

	resume_btn.pressed.connect(func() -> void:
		if not _team_mode:
			hide()
		resume_pressed.emit()
	)
	restart_btn.pressed.connect(func() -> void:
		hide()
		restart_pressed.emit()
	)
	settings_btn.pressed.connect(func() -> void:
		settings_pressed.emit()
	)
	lobby_btn.pressed.connect(func() -> void:
		hide()
		lobby_pressed.emit()
	)
