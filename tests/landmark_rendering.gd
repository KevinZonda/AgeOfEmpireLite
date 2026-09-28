extends SceneTree

# Run with a real rendering driver; saves every landmark and a contact sheet.
class PreviewContext extends Node2D:
	var view_mode_25d := true
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
	if output.is_empty(): output = "res://.godot/landmark-rendering"
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(420, 400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	RenderingServer.set_default_clear_color(Color("77876a"))
	var context := PreviewContext.new()
	viewport.add_child(context)
	context.camera.enabled = false
	context.add_child(context.camera)
	var scale := 1.8
	context.camera.zoom = Vector2(scale, scale * 0.5)
	viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339) * scale, Vector2(-0.70710678, 0.35355339) * scale, Vector2(210, 288))
	var ids: Array = RtsLandmarkCatalog.LANDMARKS.keys()
	ids.append_array(["wonder_English", "wonder_French", "wonder_Chinese"])
	var sheet := Image.create(420 * 3, 400 * 7, false, Image.FORMAT_RGB8)
	for i in ids.size():
		var id: String = ids[i]
		var wonder := id.begins_with("wonder_")
		context.civilizations[0] = id.trim_prefix("wonder_") if wonder else RtsLandmarkCatalog.LANDMARKS[id]["civilization"]
		var building := RtsBuilding.new()
		context.add_child(building)
		building.setup(context, 0, "wonder" if wonder else "landmark", false, "" if wonder else id)
		building.set_process(false)
		await process_frame
		await RenderingServer.frame_post_draw
		var captured := viewport.get_texture().get_image()
		assert(captured != null and not captured.is_empty())
		captured.convert(Image.FORMAT_RGB8)
		assert(captured.save_png(output.path_join(id + ".png")) == OK)
		sheet.blit_rect(captured, Rect2i(Vector2i.ZERO, viewport.size), Vector2i(i % 3 * 420, i / 3 * 400))
		building.free()
	assert(sheet.save_png(output.path_join("all.png")) == OK)
	print("LANDMARK_RENDERING_OK 18 landmarks + 3 wonders: ", output)
	quit()
