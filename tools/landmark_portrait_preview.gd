extends "res://tools/defense_building_refinement_preview.gd"

func _run() -> void:
	var output := "res://docs/defense-building-refinement"
	DirAccess.make_dir_recursive_absolute(output)
	var old_portrait := OS.get_environment("RTS_BUILDING_BASELINE_PORTRAIT")
	if not old_portrait.is_empty(): portrait_script = load(old_portrait)
	RenderingServer.set_default_clear_color(Color("77876a"))
	viewport = SubViewport.new()
	viewport.size = Vector2i(320, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	context = Context.new()
	viewport.add_child(context)
	context.camera.enabled = false
	context.add_child(context.camera)
	overlay = CanvasLayer.new()
	viewport.add_child(overlay)
	title = Label.new()
	title.position = Vector2(12, 12)
	title.add_theme_font_size_override("font_size", 13)
	overlay.add_child(title)
	var sheet := Image.create(1920, 1080, false, Image.FORMAT_RGB8)
	var ids: Array = RtsLandmarkCatalog.LANDMARKS.keys()
	for i in ids.size():
		var id: String = ids[i]
		context.civilizations[0] = RtsLandmarkCatalog.LANDMARKS[id]["civilization"]
		var building := RtsBuilding.new()
		context.add_child(building)
		building.setup(context, 0, "landmark", false, id)
		building.set_process(false)
		building.hide()
		var portrait: Control = portrait_script.new()
		overlay.add_child(portrait)
		portrait.position = Vector2(95, 94)
		portrait.size = Vector2(130, 170)
		portrait.subject = building
		title.text = id
		sheet.blit_rect(await _capture(), Rect2i(0, 0, 320, 360), Vector2i(i % 6 * 320, i / 6 * 360))
		portrait.free()
		building.free()
	var path := output.path_join(("before-" if not old_portrait.is_empty() else "") + "landmark-portraits.png")
	assert(sheet.save_png(path) == OK)
	print("LANDMARK_PORTRAIT_PREVIEW_OK: ", path)
	quit()
