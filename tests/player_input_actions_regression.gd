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
	_key(game, KEY_Q)
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
	_key(game, KEY_Q)
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
	var independent_id: String = game.player_actions.register("order", "probe", KEY_Q, func() -> void: independent_calls += 1)
	assert(game.execute_player_action(independent_id))
	_key(game, KEY_Q)
	assert(independent_calls == 2)
	game.player_actions.set_active(independent_id, false)
	_key(game, KEY_Q)
	assert(independent_calls == 2, "hidden page actions must not execute")
	game.player_actions.set_active(independent_id, true)

	# Input overlays have priority over actions and control groups.
	game.control_groups[KEY_5] = [worker]
	game.tech_tree_overlay = ColorRect.new()
	game.add_child(game.tech_tree_overlay)
	_key(game, KEY_5)
	_key(game, KEY_Q)
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
	# Numeric groups and the grid coexist, and old global letters reach commands.
	_select(game, worker)
	game.players[0].merge({"food": 5000, "wood": 5000, "gold": 5000, "stone": 5000}, true)
	game.build_page = 0
	game._rebuild_actions()
	game.control_groups[KEY_1] = [soldier]
	_key(game, KEY_1)
	assert(game.selected == [soldier] and game.build_mode.is_empty())
	_select(game, worker)
	_key(game, KEY_Q)
	assert(game.build_mode == "house" and game.selected == [worker])
	game.build_mode = ""
	var queue_before: bool = game.global_queue_panel.visible
	_key(game, KEY_R, true)
	assert(game.build_mode == "mill", "R must execute its grid command")
	game.build_mode = ""
	_key(game, KEY_F, true)
	assert(game.age_choice_overlay != null and game.global_queue_panel.visible == queue_before, "F must open age choice without toggling the queue")
	game._close_age_choice()
	_key(game, KEY_TAB, true)
	assert(game.global_queue_panel.visible != queue_before)
	_key(game, KEY_TAB, true)
	assert(game.global_queue_panel.visible == queue_before)
	game.players[0]["age"] = 2
	game._rebuild_actions()
	_key(game, KEY_B)
	assert(game.build_page == 1)
	_key(game, KEY_Z)
	assert(game.build_mode == "palisade_wall")
	var orientation_before: bool = game.wall_vertical
	_key(game, KEY_SPACE, true)
	assert(game.wall_vertical != orientation_before, "space must rotate walls without stealing R")
	game.build_mode = ""
	_key(game, KEY_G)
	assert(game.build_page == 0)
	game.players[0]["age"] = 4
	game._rebuild_actions()
	var view_before: bool = game.view_mode_25d
	_key(game, KEY_V, true)
	assert(game.build_mode == "wonder" and game.view_mode_25d == view_before, "V must build rather than change projection")
	game.build_mode = ""
	_key(game, KEY_F3, true)
	assert(game.view_mode_25d != view_before)
	_key(game, KEY_F3, true)
	assert(game.view_mode_25d == view_before)
	worker.issue_command("move", worker.position + Vector2(100, 0))
	_key(game, KEY_T)
	assert(worker.order == "idle", "the fixed stop key must also work for villagers")
	# Command letters must not pan the camera even while physically held.
	game.edge_scroll_enabled = false
	game.camera.position = game.world_size * 0.5
	var camera_before: Vector2 = game.camera.position
	for keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_hold_key(keycode, true)
		game._pan_camera(0.1)
		_hold_key(keycode, false)
		assert(game.camera.position == camera_before)
	_hold_key(KEY_RIGHT, true)
	game._pan_camera(0.1)
	_hold_key(KEY_RIGHT, false)
	assert(game.camera.position != camera_before, "arrow keys must still pan the camera")
	for button in game.command_buttons:
		if not button.visible: continue
		assert(not button.shortcut_label.is_empty())
		assert(button.get_node("ShortcutBadge").get_child(0).text == button.shortcut_label, "visible badges must match tooltip shortcuts")
	for button in game.hud_ui.command_side_buttons:
		assert(button.has_node("ShortcutBadge"))
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

func _key(game: Node, keycode: int, through_input := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	if through_input:
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		var release := event.duplicate()
		release.pressed = false
		Input.parse_input_event(release)
		Input.flush_buffered_events()
	else:
		game._unhandled_input(event)

func _hold_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
