extends SceneTree

# Run with a real rendering driver; saves landmarks or regular buildings and a contact sheet.
class PreviewContext extends Node2D:
	var view_mode_25d := true
	var show_building_icons := true
	var show_building_names := true
	var world_map: Node2D
	var camera := Camera2D.new()
	var civilizations := ["English"]
	var players := [{"landmarks": []}]
	var world_size := Vector2(2000, 2000)
	var started := false
	func spawn_point_for(_owner: int) -> Vector2: return Vector2.ZERO
	func player_color(_owner: int) -> Color: return Color("4e9bea")
	func should_show_health_bar(_current_hp: float, _maximum_hp: float, _change_timer: float) -> bool: return true

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("RTS_RENDER_OUTPUT")
	if not OS.get_cmdline_user_args().is_empty(): output = OS.get_cmdline_user_args()[0]
	if output.is_empty(): output = "res://.godot/landmark-rendering"
	DirAccess.make_dir_recursive_absolute(output)
	var focus_buildings := OS.get_cmdline_user_args().has("--focus-buildings")
	var regular_buildings := focus_buildings or OS.get_cmdline_user_args().has("--buildings")
	var topdown := OS.get_cmdline_user_args().has("--topdown")
	var regular_civ := "English"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--civilization="):
			regular_civ = argument.trim_prefix("--civilization=")
	assert(GameData.CIVILIZATIONS.has(regular_civ))
	var cell_size := Vector2i(360, 360) if focus_buildings else Vector2i(280, 300) if regular_buildings else Vector2i(420, 480)
	var columns := 3 if focus_buildings else 4 if regular_buildings else 3
	var viewport := SubViewport.new()
	viewport.size = cell_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	RenderingServer.set_default_clear_color(Color("77876a"))
	var context := PreviewContext.new()
	viewport.add_child(context)
	context.camera.enabled = false
	context.add_child(context.camera)
	context.view_mode_25d = not topdown
	var scale := 2.25 if focus_buildings else 2.0 if regular_buildings else 1.65
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scale="): scale = clampf(argument.trim_prefix("--scale=").to_float(), 0.5, 3.0)
	context.camera.zoom = Vector2(scale, scale if topdown else scale * 0.5)
	var center := Vector2(180, 200) if topdown and focus_buildings else Vector2(180, 260) if focus_buildings else Vector2(140, 180) if topdown and regular_buildings else Vector2(140, 220) if regular_buildings else Vector2(210, 290) if topdown else Vector2(210, 355)
	viewport.canvas_transform = Transform2D(Vector2(scale, 0), Vector2(0, scale), center) if topdown else Transform2D(Vector2(0.70710678, 0.35355339) * scale, Vector2(-0.70710678, 0.35355339) * scale, center)
	var ids: Array = RtsLandmarkCatalog.LANDMARKS.keys()
	ids.append_array(["wonder_English", "wonder_French", "wonder_Chinese"])
	if regular_buildings:
		ids = GameData.BUILDINGS.keys().filter(func(id: String) -> bool: return id not in ["landmark", "wonder"])
	if focus_buildings:
		ids = ["town_center", "lumber_camp", "mining_camp", "mill", "blacksmith", "siege_workshop"]
	if OS.get_cmdline_user_args().has("--fortifications"):
		ids = ["keep", "outpost", "palisade_wall", "palisade_gate", "stone_wall", "stone_gate", "palisade_wall_vertical", "palisade_gate_vertical", "stone_wall_vertical", "stone_gate_vertical"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ids="): ids = Array(argument.trim_prefix("--ids=").split(",", false))
	var sheet := Image.create(cell_size.x * columns, cell_size.y * ceili(ids.size() / float(columns)), false, Image.FORMAT_RGB8)
	sheet.fill(Color("77876a"))
	for i in ids.size():
		var id: String = ids[i]
		var wonder := id.begins_with("wonder_")
		var regular := GameData.BUILDINGS.has(id.trim_suffix("_vertical"))
		context.civilizations[0] = regular_civ if regular else id.trim_prefix("wonder_") if wonder else RtsLandmarkCatalog.LANDMARKS[id]["civilization"]
		var building := RtsBuilding.new()
		context.add_child(building)
		building.wall_vertical = id.ends_with("_vertical")
		building.setup(context, 0, id.trim_suffix("_vertical") if regular else "wonder" if wonder else "landmark", false, "" if wonder or regular else id)
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--construction="):
				building.build_remaining = building.build_total * (1.0 - clampf(argument.trim_prefix("--construction=").to_float(), 0.0, 1.0))
		if building.kind == "farm":
			var crop := 0.75
			for argument in OS.get_cmdline_user_args():
				if argument.begins_with("--crop="): crop = clampf(argument.trim_prefix("--crop=").to_float(), 0.0, 1.0)
				if argument.begins_with("--farm-stage="): building.farm_stage = argument.trim_prefix("--farm-stage=")
			building.farm_stage_progress = (1.0 - crop) * building.FARM_HARVEST_WORK if building.farm_stage == "harvesting" else crop * building.FARM_SOW_WORK
		building.set_process(false)
		await process_frame
		await RenderingServer.frame_post_draw
		var captured := viewport.get_texture().get_image()
		assert(captured != null and not captured.is_empty())
		captured.convert(Image.FORMAT_RGB8)
		assert(captured.save_png(output.path_join(id + ".png")) == OK)
		sheet.blit_rect(captured, Rect2i(Vector2i.ZERO, viewport.size), Vector2i(i % columns * cell_size.x, i / columns * cell_size.y))
		building.free()
	assert(sheet.save_png(output.path_join("all.png")) == OK)
	print("%s_RENDERING_OK appearances=%d: %s" % ["BUILDING" if regular_buildings else "LANDMARK", ids.size(), output])
	quit()
