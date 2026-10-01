extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.edge_scroll_enabled = false
	game.start_game("English", 4242)
	# Drive presentation explicitly so simulation, camera and effects cannot
	# accidentally request redraws and hide a throttled selection ring.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.hit_lines.clear()
	game.order_markers.clear()
	game.world_effects.clear()
	game.build_mode = ""
	var unit: RtsUnit = game.units[0]
	game.selected.clear()
	game.selected.append(unit)
	var draws := {"count": 0}
	game.draw.connect(func() -> void: draws["count"] += 1)
	for iso in [false, true]:
		if game.view_mode_25d != iso: game._toggle_view_mode()
		await process_frame
		await process_frame
		game._effects_redraw_timer = 0.1
		for frame in 12:
			var before: int = draws["count"]
			# Reproduce translation on flat ground, without slope redraws.
			game._tick_presentation(1.0 / 120.0)
			unit.position += Vector2(1.0, 0.0)
			await process_frame
			await process_frame
			assert(draws["count"] == before + 1, "selection ring must redraw each frame in %s view" % ("2.5D" if iso else "2D"))
	# Unselected effects should retain their existing redraw budget.
	game.selected.clear()
	game.hit_lines.append({"from": unit.position, "to": unit.position + Vector2(10, 0), "owner": 0, "time": 0.24})
	game.queue_redraw()
	await process_frame
	await process_frame
	game._effects_redraw_timer = 0.1
	var before: int = draws["count"]
	game._tick_presentation(1.0 / 120.0)
	await process_frame
	await process_frame
	assert(draws["count"] == before, "unselected effects should remain throttled")
	print("SELECTION_RING_FOLLOW_OK")
	quit()
