extends SceneTree

# Two compact armies actually approach and congest, unlike the paired melee
# microbenchmark. Fixed simulation time keeps headless/windowed runs comparable.
class BattleGame extends "res://scripts/game.gd":
	func _load_settings() -> void:
		# A saved macOS fullscreen preference starts an asynchronous transition
		# that can override a later resize. Keep the benchmark independent of it.
		pass

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	seed(4242)
	var game: Node2D = BattleGame.new()
	root.add_child(game)
	await process_frame
	# Stored fullscreen/scale preferences otherwise override command-line size.
	game._apply_window_resolution(Vector2i(1280, 720), false)
	game.ui_scale = 1.0
	game.text_scale = 1.0
	game.show_building_icons = true
	game.show_building_names = true
	game.health_bar_mode = "damaged"
	game._apply_ui_scales()
	game.start_game("English", 4242)
	game.ai_controllers.clear()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var flat := OS.get_environment("RTS_BATTLE_MAP") != "generated"
	if flat:
		for entity in game.units + game.resources + game.buildings: entity.free()
		game.units.clear()
		game.resources.clear()
		game.buildings.clear()
		game.selected.clear()
		game.world_map.cells.fill(RtsWorldMap.Terrain.GRASS)
		game.world_map.elevation_vertices.fill(0.0)
		game.world_map.queue_redraw()
		game.navigation.refresh()
	var count := maxi(1, int(OS.get_environment("RTS_BATTLE_SIDE")))
	if count == 1: count = 40
	var steps := maxi(1, int(OS.get_environment("RTS_BENCH_STEPS")))
	if steps == 1: steps = 300
	var center: Vector2 = game.world_size * 0.5
	var siege := OS.get_environment("RTS_BATTLE_SIEGE") == "1"
	var fortress: RtsBuilding
	if siege:
		fortress = game.spawn_building(0, "town_center", center)
		fortress.max_hp = 100000.0
		fortress.hp = fortress.max_hp
	for side in (1 if siege else 2):
		for i in count:
			var offset := Vector2((60.0 + (i / 8) * 27.0) * (-1 if side == 0 else 1), (i % 8 - 3.5) * 27.0)
			if siege: offset = Vector2.from_angle(TAU * (i % 16) / 16.0) * (180.0 + (i / 16) * 27.0)
			var unit: RtsUnit = game.spawn_unit(1 if siege else side, "spearman", center + offset)
			if siege: unit.order_attack(fortress)
			else: unit.issue_command("attack_move", center + Vector2(250 if side == 0 else -250, 0))
	if game.view_mode_25d != (OS.get_environment("RTS_BENCH_PROJECTION") != "2d"): game._toggle_view_mode()
	game.camera.position = center
	game.camera.zoom = Vector2.ONE
	game.camera.force_update_scroll()
	game.edge_scroll_enabled = false
	game.fog.update_visibility()
	if OS.get_environment("RTS_BENCH_NO_FOG") == "1":
		game.fog.active = false
		game.fog.hide()
	game.navigation.reset_profile()
	var timings: Array[float] = []
	var frames: Array[float] = []
	var other_times: Array[float] = []
	var initial_hp := 0.0
	for unit in game.units: initial_hp += unit.hp
	if siege: initial_hp += fortress.hp
	var previous := Time.get_ticks_usec()
	for step in steps:
		var started := Time.get_ticks_usec()
		game.step(1.0 / 30.0)
		timings.append((Time.get_ticks_usec() - started) / 1000.0)
		started = Time.get_ticks_usec()
		game._tick_presentation(1.0 / 30.0)
		other_times.append((Time.get_ticks_usec() - started) / 1000.0)
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - previous) / 1000.0)
		previous = now
		if step % 60 == 59: print("BATTLE_PROGRESS step=%d simulation_ms=%.2f frame_ms=%.2f" % [step + 1, timings[-1], frames[-1]])
	var remaining_hp := 0.0
	for unit in game.units: remaining_hp += maxf(0.0, unit.hp)
	if siege: remaining_hp += maxf(0.0, fortress.hp)
	print("BATTLE_POC ", JSON.stringify({"side": count, "siege": siege, "steps": steps, "flat": flat, "headless": DisplayServer.get_name() == "headless", "viewport": str(root.size), "projection_25d": game.view_mode_25d, "simulation": _summary(timings), "other_cpu": _summary(other_times), "hp_lost": initial_hp - remaining_hp, "frame": _summary(frames), "survivors": game.units.size(), "navigation": game.navigation.profile_snapshot()}))
	game.free()
	if remaining_hp < initial_hp: print("BATTLE_POC_OK")
	quit(0 if remaining_hp < initial_hp else 1)

func _summary(values: Array[float]) -> Dictionary:
	values.sort()
	return {"mean_ms": values.reduce(func(a, b): return a + b, 0.0) / values.size(), "p50_ms": values[values.size() / 2], "p95_ms": values[ceili(values.size() * 0.95) - 1], "max_ms": values[-1]}
