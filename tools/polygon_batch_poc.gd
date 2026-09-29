extends "res://tools/battle_deer_poc.gd"

const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")

func _run() -> void:
	capture_frames = true
	await super._run()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.fps_label.hide()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var results := []
	var images: Array[Image] = []
	for legacy in [true, false]:
		FilledPolygon.force_legacy = legacy
		_redraw_tree(game)
		for i in 30: await process_frame
		samples.clear()
		for i in 120: await process_frame
		await RenderingServer.frame_post_draw
		var calls := 0.0
		var cpu := 0.0
		for sample in samples:
			calls += sample["draw_calls"]
			cpu += sample["viewport_cpu_ms"]
		results.append({"legacy": legacy, "draw_calls": calls / samples.size(), "viewport_cpu_ms": cpu / samples.size()})
		var rendered := root.get_texture().get_image()
		images.append(rendered)
		if OS.has_environment("RTS_POC_IMAGE_DIR"):
			rendered.save_png(OS.get_environment("RTS_POC_IMAGE_DIR").path_join("polygon-%s.png" % ("before" if legacy else "after")))
	var first := images[0].get_data()
	var second := images[1].get_data()
	var changed := 0
	var max_difference := 0
	for i in first.size():
		var difference := absi(int(first[i]) - int(second[i]))
		max_difference = maxi(max_difference, difference)
		if difference > 1: changed += 1
	print("POLYGON_BATCH_POC ", JSON.stringify({"buildings": building_count, "attackers": 80, "results": results, "channels_differing_over_one": changed, "max_channel_difference": max_difference, "total_channels": first.size()}))
	quit(0 if changed == 0 else 1)

func _redraw_tree(node: Node) -> void:
	if node is CanvasItem: node.queue_redraw()
	for child in node.get_children(): _redraw_tree(child)
