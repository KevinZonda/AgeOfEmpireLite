extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	var center: RtsBuilding = game._player_center(0)
	assert(game.selected.size() == 1 and game.selected[0] == center)
	game.ui_scale = 1.0
	for text_scale in [1.0, 1.25, 1.5, 2.0]:
		game.text_scale = text_scale
		game._apply_ui_scales()
		game._update_hud()
		for frame in 3: await process_frame
		var before := _panel_rects(game)
		assert(game.hud_ui.queue_scroll.visible, "a production building should reserve queue space before training")
		assert(game.train_unit(center, "villager"), "the town center should train a villager")
		for frame in 3: await process_frame
		assert(_panel_rects(game) == before, "training must not move the bottom HUD or its panels at %s text scale" % text_scale)
		assert(game.queue_controls.get_child_count() == 1 and game.queue_controls.get_child(0) is Button, "the queued villager should appear")
		assert(game.cancel_production_job(center), "the queued villager should be cancellable")
		for frame in 3: await process_frame
		assert(_panel_rects(game) == before, "cancelling training must not move the bottom HUD or its panels at %s text scale" % text_scale)
		assert(game.queue_controls.get_child_count() == 1 and game.queue_controls.get_child(0) is Label, "the empty queue should have a placeholder")
	print("HUD_QUEUE_LAYOUT_OK")
	quit()

func _panel_rects(game: Node) -> Array[Rect2]:
	var dock: Control = game.hud_bottom.get_child(0)
	return [
		game.hud_bottom.get_global_rect(),
		dock.get_child(0).get_global_rect(),
		dock.get_child(1).get_global_rect(),
		game.hud_ui.queue_scroll.get_global_rect(),
	]
