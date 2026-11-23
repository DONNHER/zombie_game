extends Control

signal retry_pressed
signal next_pressed(next_stage_id: int)
signal menu_pressed

@onready var banner_label: Label = $Center/Panel/Margin/VBox/BannerLabel
@onready var stars_label: Label = $Center/Panel/Margin/VBox/StarsLabel
@onready var subtitle_label: Label = $Center/Panel/Margin/VBox/SubtitleLabel
@onready var wave_lbl: Label = $Center/Panel/Margin/VBox/StatsCard/StatsGrid/WaveLbl
@onready var time_lbl: Label = $Center/Panel/Margin/VBox/StatsCard/StatsGrid/TimeLbl
@onready var kills_lbl: Label = $Center/Panel/Margin/VBox/StatsCard/StatsGrid/KillsLbl
@onready var boss_lbl: Label = $Center/Panel/Margin/VBox/StatsCard/StatsGrid/BossLbl
@onready var points_lbl: Label = $Center/Panel/Margin/VBox/StatsCard/StatsGrid/PointsLbl
@onready var tokens_lbl: Label = $Center/Panel/Margin/VBox/StatsCard/StatsGrid/TokensLbl
@onready var save_notice: Label = $Center/Panel/Margin/VBox/SaveNotice
@onready var retry_btn: Button = $Center/Panel/Margin/VBox/Btns/RetryBtn
@onready var next_btn: Button = $Center/Panel/Margin/VBox/Btns/NextBtn
@onready var menu_btn: Button = $Center/Panel/Margin/VBox/Btns/MenuBtn

var _next_stage_id: int = 1


func _ready() -> void:
	var n_sb := StyleBoxFlat.new()
	n_sb.bg_color = Color("#22C55E")
	n_sb.set_corner_radius_all(8)
	next_btn.add_theme_stylebox_override("normal", n_sb)
	next_btn.add_theme_color_override("font_color", Color("#0F172A"))

	retry_btn.pressed.connect(func() -> void:
		hide()
		retry_pressed.emit()
	)
	next_btn.pressed.connect(func() -> void:
		hide()
		next_pressed.emit(_next_stage_id)
	)
	menu_btn.pressed.connect(func() -> void:
		hide()
		menu_pressed.emit()
	)


func open_result(summary: Dictionary) -> void:
	var victory := bool(summary.get("victory", false))
	var mode := str(summary.get("mode", "story"))
	var stage_id := int(summary.get("stage_id", 1))
	var stars := int(summary.get("stars_earned", 0))

	if mode == "tutorial":
		banner_label.text = "TRAINING COMPLETE!" if victory else "TRAINING ENDED"
		banner_label.add_theme_color_override("font_color", Color("#38BDF8"))
		stars_label.hide()
		subtitle_label.text = "Bunker basics mastered — deploy to Stage 1 when ready!"
	elif victory:
		banner_label.text = "STAGE %d CLEARED!" % stage_id if mode == "story" else "OPERATION COMPLETE!"
		banner_label.add_theme_color_override("font_color", Color("#22C55E"))
		if mode == "story":
			stars_label.show()
			var s_txt := ""
			for i in range(3):
				s_txt += "★ " if i < stars else "☆ "
			stars_label.text = s_txt.strip_edges()
		else:
			stars_label.hide()
		subtitle_label.text = "Sector secured! Rewards & star unlock saved."
	else:
		banner_label.text = "BUNKER OVERRUN — DEFEAT"
		banner_label.add_theme_color_override("font_color", Color("#EF4444"))
		stars_label.show()
		stars_label.text = "☆ ☆ ☆"
		subtitle_label.text = "Your squad fell before clearing all waves. Retry or upgrade in Armory!"

	wave_lbl.text = "Wave Reached: %d" % int(summary.get("wave_reached", 1))
	time_lbl.text = "Elapsed Time: %ds" % int(summary.get("elapsed_seconds", 0))
	kills_lbl.text = "Zombies Slain: %d" % int(summary.get("kills", 0))
	boss_lbl.text = "Bosses Defeated: %d" % int(summary.get("boss_defeats", 0))
	points_lbl.text = "Survival Points: +%d" % int(summary.get("points_earned", 0))
	tokens_lbl.text = "Boss Tokens: +%d" % int(summary.get("tokens_earned", 0))

	if NetworkManager.is_online and bool(summary.get("online", false)):
		save_notice.text = "Verified Online Match — score submitted to Nakama Leaderboard & synced."
	else:
		save_notice.text = "Offline Save — Stage unlocks, stars, and Survival Points persisted on device."

	next_btn.visible = victory and mode == "story" and stage_id < 5
	if next_btn.visible:
		_next_stage_id = stage_id + 1
		next_btn.text = "Next: Stage %d" % _next_stage_id
	show()
