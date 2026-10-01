extends "res://tools/civic_building_preview.gd"

const CIVS = ["English", "French", "Chinese"]
const CIV_NAMES = ["英格兰", "法兰西", "中国"]
const GROUPS = {
	"01-economy": ["town_center", "mill", "lumber_camp", "mining_camp", "market", "blacksmith"],
	"02-houses-farms": ["house:0", "house:1", "house:2", "farm:0", "farm:1", "farm:2"],
	"03-military": ["barracks", "archery_range", "stable", "siege_workshop", "scout_camp"],
	"04-civic": ["university", "monastery", "dock", "wonder"],
	"05-defense": ["keep", "outpost", "stone_wall", "stone_gate", "palisade_wall", "palisade_gate"],
}

func _run() -> void:
	var output := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output.path_join("individual"))
	RenderingServer.set_default_clear_color(Color("77876a"))
	viewport = SubViewport.new()
	viewport.size = Vector2i(320, 380)
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
	title.add_theme_font_override("font", load("res://assets/fonts/NotoSansSC-Regular.otf"))
	title.add_theme_font_size_override("font_size", 18)
	overlay.add_child(title)
	var covered := {}
	for group in GROUPS:
		if not OS.get_environment("GALLERY_GROUP").is_empty() and group != OS.get_environment("GALLERY_GROUP"): continue
		var entries: Array = GROUPS[group]
		var sheet := Image.create(320 * entries.size(), 1140, false, Image.FORMAT_RGB8)
		for row in 3:
			context.civilizations[0] = CIVS[row]
			for col in entries.size():
				var entry: String = entries[col]
				var kind: String = entry.split(":")[0]
				covered[kind] = true
				var building := RtsBuilding.new()
				if kind == "house":
					var variation := int(entry.split(":")[1])
					for i in 100:
						var point := Vector2(i * 43 + 7, i * 19 + 11)
						if absi(hash(point)) % 3 == variation:
							building.position = point
							break
				context.add_child(building)
				building.setup(context, 0, kind)
				building.set_process(false)
				var suffix := ""
				if kind == "house": suffix = " · 样式 " + str(int(entry.split(":")[1]) + 1)
				if kind == "farm":
					var stage := int(entry.split(":")[1])
					building.farm_stage_progress = stage * 0.5 * building.FARM_SOW_WORK
					building.queue_redraw()
					suffix = [" · 空田", " · 半播种", " · 已播种"][stage]
				title.text = CIV_NAMES[row] + "\n" + building.display_label() + suffix
				_configure(1.8, Vector2(160, 280), building.position)
				var shot := await _capture()
				sheet.blit_rect(shot, Rect2i(0, 0, 320, 380), Vector2i(col * 320, row * 380))
				assert(shot.save_png(output.path_join("individual/" + CIVS[row] + "-" + entry.replace(":", "-") + ".png")) == OK)
				building.free()
		assert(sheet.save_png(output.path_join(group + ".png")) == OK)
		print("GALLERY_OK: ", group)
	if not OS.get_environment("GALLERY_GROUP").is_empty() and OS.get_environment("GALLERY_GROUP") != "06-landmarks":
		quit()
		return
	var landmarks := Image.create(1920, 1140, false, Image.FORMAT_RGB8)
	for row in 3:
		context.civilizations[0] = CIVS[row]
		var col := 0
		for id in RtsLandmarkCatalog.LANDMARKS:
			if RtsLandmarkCatalog.LANDMARKS[id]["civilization"] != CIVS[row]: continue
			var building := RtsBuilding.new()
			context.add_child(building)
			building.setup(context, 0, "landmark", false, id)
			building.set_process(false)
			title.text = CIV_NAMES[row] + " / " + building.display_label()
			_configure(1.8, Vector2(160, 280), building.position)
			var shot := await _capture()
			landmarks.blit_rect(shot, Rect2i(0, 0, 320, 380), Vector2i(col * 320, row * 380))
			assert(shot.save_png(output.path_join("individual/" + id + ".png")) == OK)
			building.free()
			col += 1
	assert(landmarks.save_png(output.path_join("06-landmarks.png")) == OK)
	if OS.get_environment("GALLERY_GROUP").is_empty():
		for kind in GameData.BUILDINGS:
			assert(kind == "landmark" or covered.has(kind), "Missing building: " + kind)
	if covered.is_empty():
		print("GALLERY_LANDMARKS_COMPLETE: ", RtsLandmarkCatalog.LANDMARKS.size(), " landmarks")
	else:
		print("GALLERY_COMPLETE: ", covered.size(), " building types + ", RtsLandmarkCatalog.LANDMARKS.size(), " landmarks")
	quit()
