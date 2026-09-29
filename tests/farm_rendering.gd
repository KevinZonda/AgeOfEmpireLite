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

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("RTS_RENDER_OUTPUT")
	if output.is_empty(): output = "res://docs/farm-preview.png"
	var cell_size := Vector2i(240, 220)
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
	var sheet := Image.create(cell_size.x * 3, cell_size.y * 2, false, Image.FORMAT_RGB8)
	for view in 2:
		context.view_mode_25d = view == 1
		var scale := 2.0
		viewport.canvas_transform = Transform2D(Vector2(scale, 0), Vector2(0, scale), Vector2(120, 110)) if view == 0 else Transform2D(Vector2(0.70710678, 0.35355339) * scale, Vector2(-0.70710678, 0.35355339) * scale, Vector2(120, 110))
		for state in 3:
			farm.farm_stage = "sowing" if state < 2 else "harvesting"
			farm.farm_stage_progress = 0.0 if state != 1 else RtsBuilding.FARM_SOW_WORK * 0.5
			farm.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var captured := viewport.get_texture().get_image()
			assert(captured != null and not captured.is_empty())
			captured.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(captured, Rect2i(Vector2i.ZERO, cell_size), Vector2i(state * cell_size.x, view * cell_size.y))
	assert(sheet.save_png(output) == OK)
	print("FARM_RENDERING_OK: %s" % output)
	quit()
