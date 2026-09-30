extends SceneTree

var game: Variant
var scout: RtsUnit
var screen := Vector2.ZERO
var rows := []
var delivery := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var file := FileAccess.open(OS.get_environment("AOE_RIGHT_CLICK_CASES"), FileAccess.READ)
	assert(file != null)
	var config: Dictionary = JSON.parse_string(file.get_as_text())
	game = load("res://poc/input-poc/right_click_fixture.gd").new()
	root.add_child(game)
	await process_frame
	game.start_game("English", int(config["map_seed"]))
	game.set_process(false)
	game.fog.active = false
	game.camera.force_update_scroll()
	for entity in game.units + game.resources + game.buildings: entity.set_process(false)
	for unit in game.units:
		if unit.kind == "scout" and unit.owner_id == 0: scout = unit
	assert(scout != null)
	for y in range(130, 440, 40):
		for x in range(200, 1000, 40):
			var point := Vector2(x, y)
			var world: Vector2 = root.get_canvas_transform().affine_inverse() * point
			if game.world_map.is_walkable(world) and game._entity_at(world) == null and game._resource_at(world) == null and not game._selection_point_over_hud(point):
				screen = point
				break
		if screen != Vector2.ZERO: break
	assert(screen != Vector2.ZERO)
	for variant in ["production", "event_owned_poll"]:
		game.event_owned_poll = variant == "event_owned_poll"
		for driver in ["direct", "engine_immediate", "engine_buffered"]:
			delivery = driver
			Input.use_accumulated_input = driver == "engine_buffered"
			for trial in range(int(config["repeats"])):
				for scenario in config["cases"]:
					_run_case(scenario, variant, trial)
	var out := FileAccess.open(OS.get_environment("AOE_RIGHT_CLICK_MATRIX"), FileAccess.WRITE)
	assert(out != null)
	out.store_line(JSON.stringify({"synthetic": true, "map_seed": config["map_seed"], "repeats": config["repeats"], "case_count": config["cases"].size(), "rows": rows}))
	print("RIGHT_CLICK_MATRIX_OK cases=%d runs=%d seed=%d" % [config["cases"].size(), rows.size(), config["map_seed"]])
	game.queue_free()
	await process_frame
	quit()

func _reset() -> void:
	Input.flush_buffered_events()
	for index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var release := InputEventMouseButton.new()
		release.button_index = index
		release.position = screen
		release.global_position = screen
		Input.parse_input_event(release)
	Input.flush_buffered_events()
	game.replay_left = false
	game.replay_native_mask = 0
	game.replay_point = screen
	game._cancel_selection_drag()
	game._reset_selection_pointer()
	game.owned_left = false
	game.selected.assign([scout])
	scout.order_stop()
	game.begin_count = 0
	game.complete_count = 0
	game.order_count = 0

func _run_case(scenario: Dictionary, variant: String, trial: int) -> void:
	_reset()
	var transitions := []
	var last := _state()
	for step in scenario["steps"]:
		match step["op"]:
			"native":
				game.replay_native_mask = int(step["mask"])
				game.replay_left = (int(step["mask"]) & MOUSE_BUTTON_MASK_LEFT) != 0
			"poll": game._poll_selection_pointer()
			"flush": Input.flush_buffered_events()
			"button":
				var event := InputEventMouseButton.new()
				event.button_index = int(step["button"])
				event.pressed = step["pressed"]
				event.position = screen
				event.global_position = screen
				event.button_mask = int(step.get("mask", game.replay_native_mask))
				event.ctrl_pressed = step.get("ctrl", false)
				event.double_click = step.get("double", false)
				if delivery == "direct":
					game._input(event)
					game._unhandled_input(event)
				else: Input.parse_input_event(event)
		var current := _state()
		if current != last:
			transitions.append({"step": step, "state": current})
			last = current
	Input.flush_buffered_events()
	game.replay_left = false
	game.replay_native_mask = 0
	game._poll_selection_pointer()
	var final := _state()
	rows.append({"case": scenario["id"], "family": scenario["family"], "variant": variant, "driver": delivery, "trial": trial, "selection_lost": not game.selected.has(scout), "final": final, "transitions": transitions})

func _state() -> Dictionary:
	return {"selected": game.selected.size(), "dragging": game.dragging, "phase": game.selection_drag_phase, "previous_left": game.selection_previous_left_down, "begins": game.begin_count, "completes": game.complete_count, "orders": game.order_count, "order": scout.order}
