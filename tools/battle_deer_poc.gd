extends SceneTree

class DemoGame extends "res://scripts/game.gd":
	func _load_settings() -> void:
		pass

var game: Node2D
var deer_frozen := false
var caption: Label
var deer_button: Button
var attack_button: Button
var attackers: Array[RtsUnit] = []
var forts: Array[RtsBuilding] = []
var frame_start := 0
var render_start := 0
var last_end := 0
var samples: Array[Dictionary] = []
var frame_index := 0
var benchmark_frames := int(OS.get_environment("RTS_POC_FRAMES"))
var benchmark_seconds := float(OS.get_environment("RTS_POC_SECONDS"))
var profile_started := 0
var warmed_up := false
var building_count := 6
var finished := false
var capture_frames := false
var focus_attack := OS.get_environment("RTS_POC_FOCUS") != "0"

func _initialize() -> void:
	call_deferred("_run")

func _create_game() -> Node2D:
	return DemoGame.new()

func _run() -> void:
	seed(4242)
	game = _create_game()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.ai_controllers.clear()
	game.edge_scroll_enabled = false
	game.show_fps = true
	game.fps_label.show()
	var center: Vector2 = game.world_size * 0.5
	if OS.get_environment("RTS_POC_BUILDINGS") == "1": building_count = 1
	var kinds := ["town_center", "barracks", "archery_range", "stable", "market", "blacksmith"]
	for i in building_count:
		var point := center + Vector2((i % 3 - 1) * 155, (i / 3 - 0.5) * 170) if building_count > 1 else center
		var fort: RtsBuilding = game.spawn_building(0, kinds[i], point)
		fort.max_hp = 1000000.0
		fort.hp = fort.max_hp
		forts.append(fort)
	for i in 80:
		var offset := Vector2.from_angle(TAU * (i % 16) / 16.0) * ((330.0 if building_count > 1 else 180.0) + (i / 16) * 27.0)
		var unit: RtsUnit = game.spawn_unit(1, "spearman", center + offset)
		unit.max_hp = 10000.0
		unit.hp = unit.max_hp
		unit.order_attack(forts[0] if focus_attack else forts[i % building_count])
		attackers.append(unit)
	for i in 8:
		var point: Vector2 = game.world_map.nearest_walkable_point(center + Vector2(220 + (i % 4) * 28, -145 + (i / 4) * 32))
		game.spawn_resource("food", point, 160, "deer")
	if game.view_mode_25d != (OS.get_environment("RTS_POC_PROJECTION") != "2d"): game._toggle_view_mode()
	game.camera.position = center + Vector2(110, 90)
	game.camera.zoom = Vector2(0.85, 0.425) if game.view_mode_25d else Vector2.ONE * 0.85
	game.camera.force_update_scroll()
	game.fog.active = false
	game.fog.hide()
	for resource in game.resources: resource.show()
	for unit in game.units: unit.show()
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 90)
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	caption = Label.new()
	caption.text = "围攻与鹿群 PoC  |  80 名长矛兵 · %d 座建筑 · 鹿群" % building_count
	caption.add_theme_font_override("font", load("res://assets/fonts/NotoSansSC-Regular.otf"))
	caption.add_theme_font_size_override("font_size", 18)
	row.add_child(caption)
	deer_button = Button.new()
	deer_button.text = "冻结鹿群（全地图）"
	deer_button.add_theme_font_override("font", load("res://assets/fonts/NotoSansSC-Regular.otf"))
	deer_button.pressed.connect(_toggle_deer)
	row.add_child(deer_button)
	attack_button = Button.new()
	attack_button.text = "改为分散攻击" if focus_attack else "改为集中围攻"
	attack_button.add_theme_font_override("font", load("res://assets/fonts/NotoSansSC-Regular.otf"))
	attack_button.pressed.connect(_toggle_attack)
	attack_button.disabled = building_count == 1
	row.add_child(attack_button)
	root.title = "实际战斗 PoC：80 人围攻 %d 座建筑 + 鹿群" % building_count
	if OS.get_environment("RTS_POC_VSYNC") == "0": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if OS.get_environment("RTS_POC_UNCAPPED") == "1": Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), benchmark_frames > 0 or benchmark_seconds > 0 or capture_frames)
	process_frame.connect(_frame_begin)
	RenderingServer.frame_pre_draw.connect(_render_begin)
	RenderingServer.frame_post_draw.connect(_render_end)
	print("LIVE_BATTLE_DEER_READY attackers=80 buildings=%d extra_deer=8 fog=false health_extended=true viewport=%s" % [building_count, root.size])

func _frame_begin() -> void:
	frame_start = Time.get_ticks_usec()

func _render_begin() -> void:
	render_start = Time.get_ticks_usec()

func _render_end() -> void:
	if finished: return
	var now := Time.get_ticks_usec()
	if profile_started == 0: profile_started = now
	frame_index += 1
	var warmup_finished := now - profile_started >= 2000000 if benchmark_seconds > 0 else frame_index >= 60
	if warmed_up and last_end > 0 and (benchmark_frames > 0 or benchmark_seconds > 0 or capture_frames):
		samples.append({"frame_ms": (now - last_end) / 1000.0, "scene_ms": (render_start - frame_start) / 1000.0, "render_ms": (now - render_start) / 1000.0, "between_ms": (frame_start - last_end) / 1000.0, "viewport_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()), "viewport_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	last_end = now
	if warmup_finished and not warmed_up:
		warmed_up = true
		if OS.get_environment("RTS_POC_FREEZE") == "1": game.process_mode = Node.PROCESS_MODE_DISABLED
		if OS.get_environment("RTS_POC_HIDE") == "1": root.canvas_cull_mask = 0
		if OS.get_environment("RTS_POC_HIDE_MAP") == "1": game.world_map.hide()
		if OS.get_environment("RTS_POC_HIDE_ENTITIES") == "1":
			for entity in game.units + game.resources + game.buildings: entity.hide()
		game.navigation.reset_profile()
	if frame_index % 120 == 0: print("LIVE_PROGRESS frames=%d fps=%d" % [frame_index, Engine.get_frames_per_second()])
	var timed_out := benchmark_seconds > 0 and now - profile_started >= (2.0 + benchmark_seconds) * 1000000.0
	if timed_out or (benchmark_seconds <= 0 and benchmark_frames > 0 and samples.size() >= benchmark_frames):
		finished = true
		var summary := {}
		for key in samples[0]:
			var values: Array = samples.map(func(s: Dictionary): return s[key])
			values.sort()
			summary[key] = {"mean": values.reduce(func(a, b): return a + b, 0.0) / values.size(), "p50": values[values.size() / 2], "p95": values[ceili(values.size() * 0.95) - 1], "max": values[-1]}
		var damage := 0.0
		for fort in forts: damage += fort.max_hp - fort.hp
		print("LIVE_PROFILE ", JSON.stringify({"buildings": building_count, "focus_attack": focus_attack, "samples": samples.size(), "viewport": str(root.size), "damage": damage, "timings": summary, "navigation": game.navigation.profile_snapshot(), "async_navigation": game.navigation.background_jobs.metrics, "async_enabled": game.navigation.background_recovery_enabled}))
		quit()

func _toggle_deer() -> void:
	deer_frozen = not deer_frozen
	for resource in game.resources:
		if resource.appearance == "deer": resource.set_process(not deer_frozen)
	deer_button.text = "恢复鹿群活动" if deer_frozen else "冻结鹿群（全地图）"
	caption.text = "围攻与鹿群 PoC  |  80 名长矛兵 · %d 座建筑 · %s" % [building_count, "鹿群已冻结" if deer_frozen else "鹿群正常活动"]

func _toggle_attack() -> void:
	focus_attack = not focus_attack
	for i in attackers.size():
		if is_instance_valid(attackers[i]): attackers[i].order_attack(forts[0] if focus_attack else forts[i % building_count])
	attack_button.text = "改为分散攻击" if focus_attack else "改为集中围攻"
