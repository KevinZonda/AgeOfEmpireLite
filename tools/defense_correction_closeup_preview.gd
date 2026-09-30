extends "res://tools/defense_building_refinement_preview.gd"

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var kind: String = arguments[0] if not arguments.is_empty() else "keep"
	var index := KINDS.find(kind)
	assert(index >= 0, "Choose an defense building kind")
	RenderingServer.set_default_clear_color(Color("77876a"))
	viewport = SubViewport.new()
	viewport.size = Vector2i(620, 640)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	context = Context.new()
	viewport.add_child(context)
	context.camera.enabled = false
	context.add_child(context.camera)
	overlay = CanvasLayer.new()
	viewport.add_child(overlay)
	title = Label.new()
	title.position = Vector2(16, 16)
	title.add_theme_font_size_override("font_size", 17)
	overlay.add_child(title)
	var sheet := Image.create(1860, 640, false, Image.FORMAT_RGB8)
	for column in 3:
		context.civilizations[0] = ["English", "French", "Chinese"][column]
		var building := _building(index)
		var zoom := 4.0 if kind == "keep" else 6.0
		_configure(zoom, Vector2(310, 460), building.position)
		title.text = context.civilizations[0] + " / " + LABELS[index]
		sheet.blit_rect(await _capture(), Rect2i(0, 0, 620, 640), Vector2i(column * 620, 0))
		building.free()
	var directory := "res://docs/defense-corrections"
	DirAccess.make_dir_recursive_absolute(directory)
	assert(sheet.save_png(directory.path_join(("before-" if arguments.has("--before") else "") + kind + ".png")) == OK)
	print("DEFENSE_CORRECTION_CLOSEUP_OK: ", kind)
	quit()
