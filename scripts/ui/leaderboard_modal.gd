extends Control

signal closed

@onready var close_btn: Button = $Center/Panel/Margin/VBox/Header/CloseBtn
@onready var all_tab: Button = $Center/Panel/Margin/VBox/Tabs/AllTab
@onready var weekly_tab: Button = $Center/Panel/Margin/VBox/Tabs/WeeklyTab
@onready var refresh_btn: Button = $Center/Panel/Margin/VBox/Tabs/RefreshBtn
@onready var status_label: Label = $Center/Panel/Margin/VBox/StatusLabel
@onready var rows_box: VBoxContainer = $Center/Panel/Margin/VBox/Scroll/Rows

var _tab: String = "total_points"


func _ready() -> void:
	close_btn.pressed.connect(func() -> void:
		hide()
		closed.emit()
	)
	all_tab.pressed.connect(func() -> void:
		_tab = "total_points"
		_refresh()
	)
	weekly_tab.pressed.connect(func() -> void:
		_tab = "weekly_points"
		_refresh()
	)
	refresh_btn.pressed.connect(_refresh)
	NetworkManager.leaderboard_updated.connect(func(tab: String, entries: Array) -> void:
		if visible and tab == _tab:
			_render_entries(entries)
	)


func open_modal() -> void:
	show()
	_refresh()


func _refresh() -> void:
	all_tab.modulate = Color("#FFFFFF") if _tab == "total_points" else Color("#94A3B8")
	weekly_tab.modulate = Color("#FFFFFF") if _tab == "weekly_points" else Color("#94A3B8")
	if not NetworkManager.is_online:
		status_label.text = "Offline mode — showing your local device high score. Connect to Nakama Online for global rankings."
		_render_local_fallback()
		return
	status_label.text = "Fetching live Nakama leaderboard..."
	var entries := await NetworkManager.fetch_leaderboard(_tab)
	status_label.text = "Global Nakama Rankings · Top 25 Survivors"
	_render_entries(entries)


func _render_local_fallback() -> void:
	var save := SaveManager.save_data
	var stats: Dictionary = save.get("statistics", {})
	var local_entry := {
		"rank": 1,
		"username": str(save.get("username", "Ranger")) + " (This Device)",
		"score": int(stats.get("total_points_earned", 0)),
		"level": int(save.get("level", 1)),
		"highest_wave": int(stats.get("highest_wave", 0)),
		"boss_defeats": int(stats.get("boss_defeats", 0)),
	}
	_render_entries([local_entry])


func _render_entries(entries: Array) -> void:
	for c in rows_box.get_children():
		c.queue_free()
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "No leaderboard records yet — finish an online match to post your score!"
		empty.add_theme_color_override("font_color", Color("#64748B"))
		rows_box.add_child(empty)
		return

	for e in entries:
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		var rank := int(e.get("rank", 1))
		sb.bg_color = Color("#182230") if rank <= 3 else Color("#141B24")
		sb.border_color = Color("#F59E0B") if rank == 1 else Color("#283446")
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", sb)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)

		var r_lbl := Label.new()
		r_lbl.custom_minimum_size = Vector2(44, 0)
		r_lbl.text = "#%d" % rank
		r_lbl.add_theme_color_override("font_color", Color("#F59E0B") if rank <= 3 else Color("#94A3B8"))
		row.add_child(r_lbl)

		var u_lbl := Label.new()
		u_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		u_lbl.text = "%s · Lv.%d" % [str(e.get("username", "Ranger")), int(e.get("level", 1))]
		row.add_child(u_lbl)

		var w_lbl := Label.new()
		w_lbl.text = "Wave %d · %d Bosses" % [int(e.get("highest_wave", 0)), int(e.get("boss_defeats", 0))]
		w_lbl.add_theme_color_override("font_color", Color("#38BDF8"))
		row.add_child(w_lbl)

		var s_lbl := Label.new()
		s_lbl.custom_minimum_size = Vector2(110, 0)
		s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		s_lbl.text = "%d pts" % int(e.get("score", 0))
		s_lbl.add_theme_color_override("font_color", Color("#22C55E"))
		row.add_child(s_lbl)

		rows_box.add_child(card)
