extends SceneTree

const Figure = preload("res://scripts/entities/visuals/unit_figure_visual.gd")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Portrait bounds require a rendering driver")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(102, 142)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var portrait := RtsSelectionPortrait.new()
	viewport.add_child(portrait)
	portrait.size = Vector2(102, 142)
	portrait.show_subject(null)
	await process_frame
	RenderingServer.force_draw()
	var frame := viewport.get_texture().get_image()
	var count := 0
	var atlas := Image.create(510, 568, false, Image.FORMAT_RGBA8)
	for kind in GameData.UNITS:
		if not Figure.handles(kind): continue
		var unit := RtsUnit.new()
		unit.kind = kind
		unit.stats = GameData.UNITS[kind].duplicate(true)
		portrait.show_subject(unit, Color("4e9bea"))
		await process_frame
		RenderingServer.force_draw()
		var picture := viewport.get_texture().get_image()
		for y in 142:
			for x in 102:
				if x < 12 or x >= 90 or y < 12 or y >= 130:
					assert(picture.get_pixel(x, y) == frame.get_pixel(x, y), "%s escapes the portrait frame at (%d,%d)" % [kind, x, y])
		atlas.blit_rect(picture, Rect2i(0, 0, 102, 142), Vector2i((count % 5) * 102, (count / 5) * 142))
		unit.free()
		count += 1
	assert(count == 19)
	DirAccess.make_dir_recursive_absolute("res://tmp/character-preview")
	assert(atlas.save_png("res://tmp/character-preview/portraits.png") == OK)
	print("CHARACTER_PORTRAITS_OK count=%d" % count)
	quit()
