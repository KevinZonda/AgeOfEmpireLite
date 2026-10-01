extends SceneTree

# Capture the actual map renderer in both camera projections, without fog.
class MeasuredMap extends RtsWorldMap:
	var rebuild_ms := 0.0
	func _draw() -> void:
		var start := Time.get_ticks_usec()
		super._draw()
		rebuild_ms = (Time.get_ticks_usec() - start) / 1000.0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://tmp/smooth-terrain"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1000, 700)
	var map := MeasuredMap.new()
	root.add_child(map)
	var camera := Camera2D.new()
	camera.ignore_rotation = false
	root.add_child(camera)
	camera.make_current()
	for style in ["balanced", "lakes", "highlands", "islands"]:
		map.generate(431, Vector2(2400, 1800), style)
		for iso in [false, true]:
			map.isometric_view = iso
			camera.rotation = -PI / 4.0 if iso else 0.0
			camera.zoom = Vector2(0.30, 0.15) if iso else Vector2(0.35, 0.35)
			camera.position = map.world_size * 0.5
			camera.force_update_scroll()
			map.queue_redraw()
			await _save(output.path_join(style + ("-iso" if iso else "-2d") + ".png"))
	map.generate(431, Vector2(2400, 1800), "balanced")
	map.isometric_view = false
	camera.rotation = 0.0
	camera.zoom = Vector2.ONE * 1.6
	camera.position = map._world_point(map.terrain_shapes[2].center)
	camera.force_update_scroll()
	map.queue_redraw()
	await _save(output.path_join("shore.png"))
	map.isometric_view = true
	camera.rotation = -PI / 4.0
	camera.zoom = Vector2(1.5, 0.75)
	camera.position = map._world_point(map.terrain_shapes[0].center)
	camera.force_update_scroll()
	map.queue_redraw()
	await _save(output.path_join("mountain.png"))
	print("SMOOTH_TERRAIN_REBUILD_MS %.2f" % map.rebuild_ms)
	var times: Array[float] = []
	for frame in 40:
		await process_frame
		var start := Time.get_ticks_usec()
		RenderingServer.force_draw()
		if frame > 5: times.append((Time.get_ticks_usec() - start) / 1000.0)
	times.sort()
	print("SMOOTH_TERRAIN_RENDER_MS median=%.2f p95=%.2f" % [times[times.size() / 2], times[int(times.size() * 0.95)]])
	quit()

func _save(path: String) -> void:
	for frame in 3:
		await process_frame
		RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("SMOOTH_TERRAIN_CAPTURE_OK ", path)
