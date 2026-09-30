extends "res://tools/economy_building_refinement_preview.gd"

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var kind: String = arguments[0] if not arguments.is_empty() else "mining_camp"
	var index := KINDS.find(kind)
	assert(index >= 0, "Choose an economy building kind")
	RenderingServer.set_default_clear_color(Color("77876a"))
	viewport = SubViewport.new()
	viewport.size = Vector2i(360, 420)
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
	var sheet := Image.create(1080, 420, false, Image.FORMAT_RGB8)
	for column in 3:
		context.civilizations[0] = ["English", "French", "Chinese"][column]
		var building := _building(index)
		var zoom := 2.5 if kind == "town_center" else (3.0 if kind == "siege_workshop" else 4.0)
		_configure(zoom, Vector2(180, 310), building.position)
		title.text = context.civilizations[0] + " / " + LABELS[index]
		sheet.blit_rect(await _capture(), Rect2i(0, 0, 360, 420), Vector2i(column * 360, 0))
		building.free()
	var directory := "res://docs/economy-building-refinement"
	DirAccess.make_dir_recursive_absolute(directory)
	assert(sheet.save_png(directory.path_join(kind + "-refined.png")) == OK)
	print("ECONOMY_BUILDING_CLOSEUP_OK: ", kind)
	quit()
