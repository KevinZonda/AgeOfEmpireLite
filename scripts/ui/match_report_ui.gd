extends RefCounted

const REPORT_LAYOUT = preload("res://scenes/ui/report_layout.tscn")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const RtsUiTypography = preload("res://scripts/ui/typography.gd")
signal return_requested

var game: Node2D
var panel: PanelContainer

func _init(game_ref: Node2D) -> void:
	game = game_ref

func create_panel(parent: Control) -> void:
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 220)
	panel.offset_left = -200
	panel.offset_top = -110
	panel.offset_right = 200
	panel.offset_bottom = 110
	panel.add_theme_stylebox_override("panel", UiStyle._hud_panel_style(Color("30271c"), 18))
	panel.hide()
	parent.add_child(panel)

func clear() -> void:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()

func show_result(won: bool, reason: String) -> void:
	clear()
	panel.custom_minimum_size = Vector2(400, 220)
	panel.offset_left = -200
	panel.offset_top = -110
	panel.offset_right = 200
	panel.offset_bottom = 110
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	UiStyle.menu_label(box, "胜利！" if won else "战败", RtsUiTypography.PAGE_TITLE)
	var result_reason: String = {"landmarks": "城镇中心与地标全部摧毁", "sacred": "控制全部圣地", "wonder": "奇观守护成功"}.get(reason, reason)
	UiStyle.menu_label(box, result_reason, RtsUiTypography.BODY)
	var button := Button.new()
	button.text = "返回文明选择"
	button.pressed.connect(func() -> void: return_requested.emit())
	box.add_child(button)
	var report := Button.new()
	report.text = "查看战后统计与战局回看"
	report.pressed.connect(func() -> void: show_report(won, result_reason))
	box.add_child(report)
	panel.show()

func show_report(won: bool, result_reason: String) -> void:
	clear()
	panel.custom_minimum_size = Vector2(820, 620)
	panel.offset_left = -410
	panel.offset_top = -310
	panel.offset_right = 410
	panel.offset_bottom = 310
	var layout: VBoxContainer = REPORT_LAYOUT.instantiate()
	panel.add_child(layout)
	var title: Label = layout.get_node("Title")
	title.text = ("胜利" if won else "战败") + " · " + result_reason
	# Typography scaling reads explicit base sizes for dynamic and scene labels alike.
	title.add_theme_font_size_override("font_size", RtsUiTypography.PAGE_TITLE)
	var legend: HBoxContainer = layout.get_node("Legend")
	var colors: Array[Color] = []
	for owner_id in game.players.size():
		var color: Color = game.player_color(owner_id)
		colors.append(color)
		var caption := Label.new()
		caption.text = "%s  %s    " % ["●", game.civilizations[owner_id]]
		caption.add_theme_color_override("font_color", color)
		legend.add_child(caption)
	var tabs: TabContainer = layout.get_node("Tabs")
	var trend_tab := VBoxContainer.new()
	trend_tab.name = "数据走势"
	tabs.add_child(trend_tab)
	var metric_picker := OptionButton.new()
	for metric_name in ["资源库存", "累计收入", "人口", "军队", "科技", "地图控制率"]: metric_picker.add_item(metric_name)
	trend_tab.add_child(metric_picker)
	var chart := RtsStatisticsChart.new()
	chart.statistics = game.match_statistics
	chart.player_colors = colors
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trend_tab.add_child(chart)
	metric_picker.item_selected.connect(func(index: int) -> void:
		chart.show_metric(["stock", "income", "population", "military", "technology", "control"][index])
	)
	var last_sample: Dictionary = game.match_statistics.samples.back()
	var summary := Label.new()
	var details: Array[String] = []
	for owner_id in game.players.size():
		var row: Dictionary = last_sample["players"][owner_id]
		details.append("%s：人口 %d · 军队 %d · 科技 %d · 控图 %.0f%%" % [game.civilizations[owner_id], row["population"], row["military"], row["technology"], row["control"]])
	summary.text = "\n".join(details)
	trend_tab.add_child(summary)
	var replay_tab := VBoxContainer.new()
	replay_tab.name = "战局回看"
	tabs.add_child(replay_tab)
	var replay_map := RtsBattleReplayMap.new()
	replay_map.statistics = game.match_statistics
	replay_map.player_colors = colors
	replay_map.prepare(game.world_map)
	replay_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	replay_tab.add_child(replay_map)
	var replay_time := Label.new()
	replay_tab.add_child(replay_time)
	var timeline := HSlider.new()
	timeline.min_value = 0
	timeline.max_value = maxi(0, game.match_statistics.samples.size() - 1)
	timeline.step = 1
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_tab.add_child(timeline)
	var playback := Timer.new()
	playback.wait_time = 0.35
	playback.autostart = false
	replay_tab.add_child(playback)
	var controls := HBoxContainer.new()
	replay_tab.add_child(controls)
	var play_button := Button.new()
	play_button.text = "播放"
	controls.add_child(play_button)
	var event_picker := OptionButton.new()
	event_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_picker.add_item("跳到关键事件")
	for event in game.match_statistics.events:
		event_picker.add_item("%02d:%02d  %s · %s" % [int(event["time"]) / 60, int(event["time"]) % 60, game.civilizations[event["owner"]], event["label"]])
	controls.add_child(event_picker)
	timeline.value_changed.connect(func(value: float) -> void:
		replay_map.seek(roundi(value))
		var current: Dictionary = game.match_statistics.samples[replay_map.sample_index]
		replay_time.text = "战局时间 %02d:%02d · 单位 %d · 建筑 %d" % [int(current["time"]) / 60, int(current["time"]) % 60, current["units"].size(), current["buildings"].size()]
	)
	event_picker.item_selected.connect(func(index: int) -> void:
		if index > 0: timeline.value = game.match_statistics.nearest_sample_index(float(game.match_statistics.events[index - 1]["time"]))
	)
	play_button.pressed.connect(func() -> void:
		if playback.is_stopped():
			if timeline.value >= timeline.max_value: timeline.value = 0
			playback.start()
			play_button.text = "暂停"
		else:
			playback.stop()
			play_button.text = "播放"
	)
	playback.timeout.connect(func() -> void:
		if timeline.value < timeline.max_value: timeline.value += 1
		else:
			playback.stop()
			play_button.text = "播放"
	)
	timeline.value = timeline.max_value
	var back: Button = layout.get_node("Back")
	back.pressed.connect(func() -> void: return_requested.emit())
