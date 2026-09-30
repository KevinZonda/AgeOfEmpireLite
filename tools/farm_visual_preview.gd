extends SceneTree

# Run with a rendering driver to preview both farm views and sowing states.
class PreviewContext extends Node2D:
	var view_mode_25d := false
	var show_building_icons := false
	var show_building_names := false
	var world_map: Node2D
	var camera := Camera2D.new()
	var civilizations := ["English"]
	var players := [{"landmarks": []}]
	var world_size := Vector2(2000, 2000)
	var started := false
	func spawn_point_for(_owner: int) -> Vector2: return Vector2.ZERO
	func player_color(_owner: int) -> Color: return Color("4e9bea")
	func should_show_health_bar(_current_hp: float, _maximum_hp: float, _change_timer: float) -> bool: return false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://docs/civic-building-redraw/farm-cycle.png"
	var cell_size := Vector2i(280, 260)
	var viewport := SubViewport.new()
	viewport.size = cell_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	RenderingServer.set_default_clear_color(Color("77876a"))
	var context := PreviewContext.new()
	viewport.add_child(context)
	context.add_child(context.camera)
	context.camera.enabled = false
	var farm := RtsBuilding.new()
	context.add_child(farm)
	farm.setup(context, 0, "farm")
	farm.set_process(false)
	var overlay := CanvasLayer.new()
	viewport.add_child(overlay)
	var label := Label.new()
	label.position = Vector2(10, 12)
	label.add_theme_font_size_override("font_size", 13)
	overlay.add_child(label)
	var sheet := Image.create(cell_size.x * 5, cell_size.y * 4, false, Image.FORMAT_RGB8)
	for view in 4:
		context.civilizations[0] = "English" if view < 2 else "Chinese"
		context.view_mode_25d = view % 2 == 0
		var scale := 2.0
		context.camera.zoom = Vector2(scale, scale * 0.5 if context.view_mode_25d else scale)
		viewport.canvas_transform = Transform2D(Vector2(scale, 0), Vector2(0, scale), Vector2(140, 155)) if not context.view_mode_25d else Transform2D(Vector2(0.70710678, 0.35355339) * scale, Vector2(-0.70710678, 0.35355339) * scale, Vector2(140, 155))
		for state in 5:
			farm.farm_stage = "sowing" if state < 3 else "harvesting"
			farm.farm_stage_progress = [0.0, 0.5, 1.0, 0.5, 0.96][state] * (farm.FARM_SOW_WORK if state < 3 else farm.FARM_HARVEST_WORK)
			label.text = "%s / %s\n%s" % [context.civilizations[0], "2.5D" if context.view_mode_25d else "2D", ["Bare soil", "Half sown", "Ripe crop", "Half harvested", "Stubble"][state]]
			farm.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var captured := viewport.get_texture().get_image()
			assert(captured != null and not captured.is_empty())
			captured.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(captured, Rect2i(Vector2i.ZERO, cell_size), Vector2i(state * cell_size.x, view * cell_size.y))
	assert(sheet.save_png(output) == OK)
	print("FARM_VISUAL_PREVIEW_OK: %s" % output)
	quit()
