extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.camera.position = game.world_size * 0.5
	game._toggle_view_mode()
	game.camera.force_update_scroll()
	assert(game.world_map.isometric_view)
	var canvas: Transform2D = root.get_canvas_transform()
	var ground_x := canvas.basis_xform(Vector2.RIGHT)
	var ground_y := canvas.basis_xform(Vector2.DOWN)
	assert(is_equal_approx(absf(ground_x.x / ground_x.y), 2.0), "ground tiles should have 2:1 diamond edges")
	assert(is_equal_approx(ground_x.y, ground_y.y) and is_equal_approx(ground_x.x, -ground_y.x))
	var upright: Transform2D = RtsIsoProjection.upright(canvas, Vector2.ZERO)
	assert((canvas.basis_xform(upright.basis_xform(Vector2.RIGHT)) - Vector2.RIGHT).length() < 0.001)
	assert((canvas.basis_xform(upright.basis_xform(Vector2.DOWN)) - Vector2.DOWN).length() < 0.001)
	var high_ground := Vector2.INF
	var mountain_height := 0.0
	for y in game.world_map.grid_size.y:
		for x in game.world_map.grid_size.x:
			var point: Vector2 = game.world_map.cell_center(Vector2i(x, y))
			if game.world_map.terrain_at(point) == RtsWorldMap.Terrain.MOUNTAIN:
				mountain_height = game.world_map.elevation_at(point)
			elif game.world_map.is_high_ground(point) and high_ground == Vector2.INF:
				high_ground = point
	assert(high_ground != Vector2.INF and mountain_height > game.world_map.elevation_at(high_ground) and game.world_map.elevation_at(high_ground) > 0.0)
	var high_unit: RtsUnit = game.spawn_unit(0, "spearman", high_ground)
	var ground_lift := RtsIsoProjection.ground_lift(game, high_unit.position)
	assert(canvas.basis_xform(ground_lift).y < -5.0)
	assert(game._entity_at(high_unit.position + ground_lift) == high_unit, "raised units must remain clickable")
	var center := Vector2(1100, 700)
	var first: RtsUnit = game.spawn_unit(0, "spearman", center)
	var second: RtsUnit = game.spawn_unit(0, "spearman", center + RtsIsoProjection.world_delta(canvas, Vector2(0, 20)))
	var unit_head := first.position + RtsIsoProjection.world_delta(canvas, Vector2(0, -23 * game.camera.zoom.x))
	assert(game._entity_at(unit_head) == first, "an upright unit should be clickable above its ground anchor")
	var tower: RtsBuilding = game.spawn_building(0, "outpost", center + Vector2(250, 0))
	var roof_center := tower.position + RtsIsoProjection.world_delta(canvas, Vector2(0, -tower.isometric_height() * game.camera.zoom.x))
	assert(game._entity_at(roof_center) == tower, "an elevated roof should be clickable")
	var from := center + RtsIsoProjection.world_delta(canvas, Vector2(-50, -30))
	var to := center + RtsIsoProjection.world_delta(canvas, Vector2(50, 30))
	assert(absf(second.position.y - center.y) > absf(to.y - center.y), "test needs a unit outside the old world-space drag box")
	game._select_area(from, to, false)
	assert(game.selected.has(first) and game.selected.has(second), "drag selection must follow the visible screen rectangle")
	# Panning while the mouse is held must not move the screen-space anchor.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(500, 300)
	game._unhandled_input(press)
	game._move_camera_screen_delta(Vector2(-200, 0))
	game.camera.force_update_scroll()
	var drag_target: RtsUnit = game.spawn_unit(0, "spearman", root.get_canvas_transform().affine_inverse() * Vector2(600, 440))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = Vector2(850, 540)
	game._unhandled_input(release)
	assert(game.selected.has(drag_target), "camera panning during a drag must preserve the starting screen corner")
	game._update_iso_depths()
	assert(second.z_index > first.z_index, "nearer objects should draw above farther objects")
	game._toggle_view_mode()
	assert(first.z_index == 0 and second.z_index == 0, "top-down mode should restore its draw order")
	print("ISOMETRIC_VIEW_OK")
	quit()
