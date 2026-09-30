extends SceneTree

var button_signal_count := 0
var independent_calls := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.set_process(false)
	game.ai_controllers.clear()
	var worker: RtsUnit = game.units[0]
	_select(game, worker)
	var house: RtsCommandButton = _button(game, "house")
	assert(house != null and not house.disabled)
	house.pressed.connect(func() -> void: button_signal_count += 1)
	var house_id: String = house.get_meta("action_id")
	game.hotkey_buttons.clear()
	# Keyboard executes a game action without any UI lookup or button signal.
	_key(game, KEY_1)
	assert(game.build_mode == "house" and button_signal_count == 0)
	assert(game.player_input.mode == game.player_input.Mode.BUILD)
	game.build_mode = ""
	house.pressed.emit()
	assert(game.build_mode == "house" and button_signal_count == 1)

	# Availability is checked at execution time, even if the displayed tile is stale.
	game.build_mode = ""
	game.players[0]["wood"] = 0
	assert(not house.disabled, "fixture must expose the stale displayed availability")
	assert(not game.execute_player_action(house_id) and game.build_mode.is_empty())
	_key(game, KEY_1)
	assert(game.build_mode.is_empty())
	game.players[0]["wood"] = 5000
	assert(game.execute_player_action(house_id) and game.build_mode == "house")

	# Changing selections invalidates callbacks before the next HUD rebuild.
	game.build_mode = ""
	var soldier: RtsUnit = game.spawn_unit(0, "spearman", worker.position + Vector2(80, 0))
	game.selected.assign([soldier])
	assert(not game.execute_player_action(house_id))
	game._rebuild_actions()
	assert(not game.execute_player_action(house_id), "expired IDs cannot execute after rebuild")

	# HUD lifetime and button signal subscribers are not required for registry actions.
	game.player_actions.clear()
	var independent_id: String = game.player_actions.register("order", "probe", KEY_9, func() -> void: independent_calls += 1)
	assert(game.execute_player_action(independent_id))
	_key(game, KEY_9)
	assert(independent_calls == 2)
	game.player_actions.set_active(independent_id, false)
	_key(game, KEY_9)
	assert(independent_calls == 2, "hidden page actions must not execute")
	game.player_actions.set_active(independent_id, true)

	# Input overlays have priority over actions and control groups.
	game.control_groups[KEY_5] = [worker]
	game.tech_tree_overlay = ColorRect.new()
	game.add_child(game.tech_tree_overlay)
	_key(game, KEY_5)
	_key(game, KEY_9)
	assert(game.selected == [soldier] and independent_calls == 2)
	game.tech_tree_overlay.queue_free()
	game.tech_tree_overlay = null
	game.paused = true
	assert(not game.execute_player_action(independent_id))
	game.paused = false
	_key(game, KEY_5)
	assert(game.selected == [worker] and game.player_selection.selected == [worker])

	# Entering a build/target mode ends the old drag and keeps one active mode.
	game._begin_selection_candidate(Vector2(500, 250))
	game.build_mode = "palisade_wall"
	assert(not game.dragging and game.player_input.mode == game.player_input.Mode.BUILD)
	game.wall_dragging = true
	game.pending_landmark_id = "test"
	game.order_mode = "patrol"
	assert(game.build_mode.is_empty() and not game.wall_dragging and game.pending_landmark_id.is_empty())
	assert(game.player_input.mode == game.player_input.Mode.TARGET)
	game.build_mode = "house"
	assert(game.order_mode.is_empty())
	game.build_mode = ""
	assert(game.player_input.mode == game.player_input.Mode.SELECT)

	# Recall filters invalid/dead and garrisoned members without corrupting groups.
	var deleted: RtsUnit = game.spawn_unit(0, "scout", worker.position + Vector2(100, 100))
	game.control_groups[KEY_6] = [worker, deleted]
	deleted.queue_free()
	_key(game, KEY_6)
	assert(game.selected == [worker] and game.control_groups[KEY_6] == [worker])
	print("PLAYER_INPUT_ACTIONS_REGRESSION_OK")
	game.queue_free()
	await process_frame
	quit()

func _select(game: Node, unit: Node2D) -> void:
	game.selected.assign([unit])
	game._rebuild_actions()
	game._update_hud()

func _button(game: Node, kind: String) -> RtsCommandButton:
	for button in game.command_buttons:
		if button.icon_kind == kind: return button
	return null

func _key(game: Node, keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	game._unhandled_input(event)
