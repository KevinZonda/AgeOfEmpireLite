extends SceneTree

const Visual = preload("res://scripts/entities/visuals/unit_visual.gd")
const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")

class Actor extends Node2D:
	var state
	var renderer = Visual.new()
	func _draw() -> void:
		renderer.draw(self, state)

func _initialize() -> void:
	call_deferred("_run")

func _bounds(picture: Image) -> Rect2i:
	var low := picture.get_size()
	var high := Vector2i.ZERO
	for y in picture.get_height():
		for x in picture.get_width():
			if picture.get_pixel(x, y).a < 0.1: continue
			low = low.min(Vector2i(x, y))
			high = high.max(Vector2i(x, y))
	assert(high.x >= low.x and high.y >= low.y, "the figure must render")
	return Rect2i(low, high - low + Vector2i.ONE)

func _capture(viewport: SubViewport, actor: Actor, scale_factor: float) -> Image:
	actor.state.visual_scale = scale_factor
	actor.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	return viewport.get_texture().get_image()

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "This test requires a rendering driver")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 320)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var actor := Actor.new()
	viewport.add_child(actor)
	var samples := 0
	for kind in ["villager", "longbow", "royal_knight"]:
		for iso in [false, true]:
			for zoom in [1.0, 1.6]:
				actor.state = State.preview(kind, GameData.UNITS[kind], Color.BLUE)
				actor.state.view_mode_25d = iso
				actor.state.zoom = zoom
				actor.state.ground_height = 26.0
				viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, Vector2(180, 220)) if iso else Transform2D(0.0, Vector2.ONE * zoom, 0.0, Vector2(180, 220))
				var before := _bounds(await _capture(viewport, actor, 1.0))
				var after := _bounds(await _capture(viewport, actor, GameData.unit_visual_scale(kind)))
				assert(absf(after.size.x - before.size.x * 0.8) <= 3.0 and absf(after.size.y - before.size.y * 0.8) <= 3.0, "figure and shadow must shrink together: %s iso=%s zoom=%s" % [kind, iso, zoom])
				assert(absf(after.end.y - before.end.y) <= 4.0, "scaling must keep feet on the same elevated ground")
				samples += 1
	viewport.free()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.fog.active = false
	var unit: RtsUnit = game.units[0]
	var original_stats := unit.stats.duplicate(true)
	var original_position := unit.position
	var original_radius := unit.radius()
	unit.visual_scale = 1.25
	var snapshot = State.capture(unit)
	assert(is_equal_approx(snapshot.visual_scale, 1.0), "an instance can override its default display size")
	unit.visual_scale = 1.0
	assert(is_equal_approx(snapshot.visual_scale, 1.0), "captured visuals must preserve their scale")
	assert(unit.stats == original_stats and unit.radius() == original_radius and unit.position == original_position, "visual scaling must not change the simulation")
	for iso in [false, true]:
		if game.view_mode_25d != iso: game._toggle_view_mode()
		game.camera.force_update_scroll()
		var canvas: Transform2D = game.get_viewport().get_canvas_transform()
		var body_point := unit.position
		if iso:
			body_point += RtsIsoProjection.ground_lift(game, unit.position) + RtsIsoProjection.world_delta(canvas, Vector2(0, -20.0 * unit.display_scale() * game.camera.zoom.x))
		assert(game._entity_at(body_point) == unit, "scaled units must remain clickable in both projections")
	assert(GameData.unit_visual_scale("mangonel") == 1.0 and GameData.unit_visual_scale("warship") == 1.0)
	game.free()
	print("UNIT_VISUAL_SCALE_OK rendered_cases=%d, ground anchors, clicks and simulation dimensions" % samples)
	quit()
