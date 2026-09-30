extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	var worker: RtsUnit = game.units[0]
	var center: RtsBuilding = game._player_center(0)
	var blacksmith: RtsBuilding = game.spawn_building(0, "blacksmith", center.position + Vector2(180, 0))
	for scales in [Vector2(1, 1), Vector2(1, 2), Vector2(1.5, 1.75)]:
		game.ui_scale = scales.x
		game.text_scale = scales.y
		game._apply_ui_scales()
		_select(game, worker)
		game.build_page = 0
		game._rebuild_actions()
		await _settle()
		await _check_stable_pages(game, 4)
		_select(game, center)
		await _settle()
		assert(game.hud_ui.command_page_buttons.is_empty(), "single-page buildings must have no arrow buttons")
		assert(game.action_bar.get_child(14).get_child_count() == 0, "the navigation slot must be empty on single-page buildings")
		_select(game, blacksmith)
		await _settle()
		assert(game.command_buttons.size() > 12, "the blacksmith must exercise building pagination")
		await _check_stable_pages(game, 4)
	game.civilizations[0] = "Chinese"
	_select(game, worker)
	game.build_page = 0
	game._rebuild_actions()
	await _settle()
	await _check_stable_pages(game, 6)
	var soldier: RtsUnit = game.spawn_unit(0, "spearman", center.position + Vector2(0, 100))
	_select(game, soldier)
	await _settle()
	assert(game.hud_ui.command_page_buttons.is_empty(), "military units must not expose arrows")
	var page_count := ceili(float(game.command_buttons.size() - 1) / 12.0)
	var seen_commands := 0
	for page in page_count:
		seen_commands += game.command_buttons.filter(func(button: RtsCommandButton) -> bool: return button.visible and button.icon_kind != "stop").size()
		assert(game.command_buttons.back().visible, "stop must stay visible on every command page")
		if page_count > 1:
			game.hud_ui.command_side_buttons[0].pressed.emit()
			await _settle()
	assert(seen_commands == game.command_buttons.size() - 1, "the more button must keep every military command accessible")
	print("HUD_COMMAND_PAGES_OK")
	quit()

func _select(game: Node, item: Node2D) -> void:
	game.selected.clear()
	game.selected.append(item)
	game._rebuild_actions()
	game._update_hud()

func _settle() -> void:
	for frame in 4: await process_frame

func _check_stable_pages(game: Node, switches: int) -> void:
	var expected := _rects(game)
	for switch in switches:
		assert(game.hud_ui.command_page_buttons.size() == 2, "multi-page villagers and buildings must show two arrows")
		for index in 2:
			var arrow: Button = game.hud_ui.command_page_buttons[index]
			assert(game.action_bar.get_child(9 + index * 5) == arrow, "arrows must stack in the lower two right-column slots")
			assert(arrow.size == game.hud_ui.command_tile_size, "arrows must use the same full-size tiles as commands")
		game.hud_ui.command_page_buttons[1 if switch < switches / 2 else 0].pressed.emit()
		for frame in 4:
			await process_frame
			assert(_rects(game) == expected, "page changes must not move panels or any grid slot, even during the first frame")

func _rects(game: Node) -> Array[Rect2]:
	var rects: Array[Rect2] = [game.hud_bottom.get_global_rect(), game.hud_ui.command_panel.get_global_rect(), game.hud_ui.selection_panel.get_global_rect(), game.action_bar.get_global_rect()]
	for child in game.action_bar.get_children():
		if child.visible: rects.append(child.get_global_rect())
	return rects
