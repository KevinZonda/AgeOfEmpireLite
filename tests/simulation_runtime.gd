extends SceneTree

class TrackedUnit extends RtsUnit:
	var ticks := 0
	var total_delta := 0.0
	var on_tick: Callable
	func _draw() -> void: pass
	func _process(delta: float) -> void:
		ticks += 1
		total_delta += delta
		if on_tick.is_valid(): on_tick.call()

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.set_process(false)
	game.ai_controllers.clear()
	var actor := TrackedUnit.new()
	game.add_child(actor)
	var engine_frame := Engine.get_process_frames()
	assert(not actor.is_processing(), "registered actors must not also receive automatic callbacks")
	assert(game.step(0.1) and game.step(0.2))
	assert(Engine.get_process_frames() == engine_frame and game.simulation.clock.tick_id == 2, "multiple simulation steps must not require renderer frames")
	assert(actor.ticks == 2 and is_equal_approx(actor.total_delta, 0.3))
	assert(is_equal_approx(game.simulation.clock.elapsed, 0.3) and is_equal_approx(game.match_statistics.elapsed, 0.3))
	game.simulation.set_actor_enabled(actor, false)
	game.step(0.1)
	assert(actor.ticks == 2, "simulation suspension is explicit and leaves direct test callbacks available")
	game.simulation.set_actor_enabled(actor, true)
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	game.step(0.1)
	assert(actor.ticks == 2, "disabled actor process mode must be honored")
	actor.process_mode = Node.PROCESS_MODE_INHERIT
	var nested_results: Array[bool] = []
	actor.on_tick = func() -> void: nested_results.append(game.step(0.5))
	game.step(0.1)
	assert(nested_results == [false] and game.simulation.clock.tick_id == 5, "reentrant steps must be rejected without advancing time")
	actor.on_tick = Callable()
	var newborns: Array[TrackedUnit] = []
	actor.on_tick = func() -> void:
		var born := TrackedUnit.new()
		game.add_child(born)
		newborns.append(born)
	game.step(0.1)
	actor.on_tick = Callable()
	assert(newborns.size() == 1 and newborns[0].ticks == 0, "actors born during a step start at the next boundary")
	game.step(0.1)
	assert(newborns[0].ticks == 1)
	actor.on_tick = func() -> void: newborns[0].queue_free()
	game.step(0.1)
	actor.on_tick = Callable()
	assert(newborns[0].ticks == 1, "actors queued for deletion must be skipped even inside a captured actor list")
	# Spatial snapshots must rebuild across simulation ticks even when a renderer
	# frame has not advanced and a target was moved without a movement callback.
	var probe: RtsUnit = game.spawn_unit(0, "scout", Vector2(700, 700))
	game.simulation.set_actor_enabled(probe, false)
	var observed: Array[bool] = []
	actor.on_tick = func() -> void: observed.append(game.navigation.nearby_units(probe.position, 1.0).has(probe))
	game.step(0.01)
	probe.position += Vector2(200, 0)
	game.step(0.01)
	actor.on_tick = Callable()
	assert(observed == [true, true], "same-render-frame steps must update spatial index epochs")
	var group_probe: RtsUnit = game.spawn_unit(0, "spearman", Vector2(800, 700))
	game.simulation.set_actor_enabled(group_probe, false)
	var squad: Array[RtsUnit] = [group_probe]
	var group := RtsMovementGroup.new(game, squad, Vector2(900, 700))
	var epochs: Array[int] = []
	actor.on_tick = func() -> void:
		group._tick()
		epochs.append(group.last_frame)
	game.step(0.01)
	game.step(0.01)
	actor.on_tick = Callable()
	assert(epochs[0] != epochs[1] and epochs[0] < -1 and epochs[1] < -1, "movement groups must tick per simulation step rather than engine frame")
	assert(game.navigation.simulation_frame == game.simulation.clock.tick_id, "presentation must retain the completed simulation epoch")
	var clock_before: int = game.simulation.clock.tick_id
	var elapsed_before: float = game.simulation.clock.elapsed
	game.paused = true
	assert(not game.step(1.0) and game.simulation.clock.tick_id == clock_before)
	assert(game.navigation.simulation_frame == clock_before, "pause must retain unchanged simulation caches")
	game.paused = false
	assert(not game.step(0.0) and not game.step(-1.0) and not game.step(INF))
	assert(game.simulation.clock.elapsed == elapsed_before)
	var arrow := RtsProjectile.new()
	arrow.setup_point(game, 0, Vector2(500, 500), Vector2(1800, 1500), 50.0, 100.0, 20.0, {}, {})
	game.add_child(arrow)
	game.game_over = true
	assert(not game.step(1.0) and game.simulation.clock.tick_id == clock_before)
	assert(arrow.is_queued_for_deletion() and not game.simulation.actors.has(arrow.get_instance_id()), "game-over cleanup must retire in-flight fixed-target projectiles")
	game.game_over = false
	var stale_arrow := RtsProjectile.new()
	stale_arrow.setup_point(game, 0, Vector2(500, 500), Vector2(1800, 1500), 50.0, 100.0, 20.0, {}, {})
	game.add_child(stale_arrow)
	game.start_game("French", 431)
	game.ai_controllers.clear()
	assert(stale_arrow.is_queued_for_deletion() and not game.simulation.actors.has(stale_arrow.get_instance_id()), "restart must not carry old splash projectiles into the new match")
	assert(game.simulation.clock.tick_id == 0 and game.simulation.clock.elapsed == 0.0, "restart must reset match time")
	assert(game.navigation.simulation_frame == -1, "restart restores standalone navigation until the first step")
	await process_frame
	assert(not is_instance_valid(newborns[0]), "deferred disposal remains a SceneTree responsibility")
	assert(game.step(0.1) and game.simulation.clock.tick_id == 1)
	game.free()
	print("SIMULATION_RUNTIME_OK")
	quit()
