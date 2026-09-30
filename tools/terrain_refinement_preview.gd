extends SceneTree

const UnitVisual = preload("res://scripts/entities/visuals/unit_visual.gd")
const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")

class Soldier extends Node2D:
	var state
	var visual := UnitVisual.new()
	func _draw() -> void: visual.draw(self, state)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://docs/terrain-refinement"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1000, 640)
	var map := RtsWorldMap.new()
	root.add_child(map)
	var camera := Camera2D.new()
	camera.ignore_rotation = false
	root.add_child(camera)
	camera.make_current()
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var label := Label.new()
	label.position = Vector2(20, 18)
	label.add_theme_font_size_override("font_size", 20)
	overlay.add_child(label)
	var actors: Array[Node2D] = []
	for index in 4:
		for actor in actors: actor.free()
		actors.clear()
		var style := "highlands" if index == 2 else "balanced"
		map.generate(4242, Vector2(2400, 1800), style)
		var center: Vector2 = map.spawn_positions()[0] + Vector2(300, -100) if index == 0 else map._world_point(map.terrain_shapes[0].center)
		if index == 2: center = map._world_point(Vector2(map.barrier_x, 520))
		map.isometric_view = index != 3
		camera.rotation = -PI / 4 if map.isometric_view else 0.0
		camera.zoom = Vector2(1.3, 0.65) if map.isometric_view else Vector2(1.3, 1.3)
		camera.position = center
		camera.force_update_scroll()
		map.queue_redraw()
		for offset in [Vector2(-160, 120), Vector2(-100, 160), Vector2(-40, 190), Vector2(40, 210), Vector2(120, 230)]:
			var at: Vector2 = center + offset
			if not map.is_walkable(at): continue
			var actor := Soldier.new()
			actor.position = at
			actor.z_index = clampi(roundi((at.x + at.y) * 0.5), 0, 2800) if map.isometric_view else 0
			actor.state = State.preview("spearman", GameData.UNITS["spearman"], Color("4e9bea"))
			actor.state.view_mode_25d = map.isometric_view
			actor.state.zoom = 1.3
			actor.state.ground_height = map.elevation_at(at)
			root.add_child(actor)
			actors.append(actor)
		label.text = ["Grassland / 2.5D", "Mountain and walkable foothill / 2.5D", "Highlands ridge / 2.5D", "Mountain / 2D"][index]
		for frame in 3:
			await process_frame
			RenderingServer.force_draw()
		var path: String = output.path_join(["grassland", "foothill", "highlands", "topdown"][index] + ".png")
		assert(root.get_texture().get_image().save_png(path) == OK)
		print("TERRAIN_CAPTURE_OK ", path)
	var comparison := Image.create(2000, 1280, false, Image.FORMAT_RGB8)
	var comparisons := 0
	for row in 2:
		var name: String = ["foothill", "highlands"][row]
		if not FileAccess.file_exists(output.path_join("before-" + name + ".png")): continue
		var before := Image.load_from_file(output.path_join("before-" + name + ".png"))
		var after := Image.load_from_file(output.path_join(name + ".png"))
		if before == null: continue
		before.convert(Image.FORMAT_RGB8)
		after.convert(Image.FORMAT_RGB8)
		comparison.blit_rect(before, Rect2i(0, 0, 1000, 640), Vector2i(0, row * 640))
		comparison.blit_rect(after, Rect2i(0, 0, 1000, 640), Vector2i(1000, row * 640))
		comparisons += 1
	if comparisons > 0: assert(comparison.save_png(output.path_join("comparison.png")) == OK)
	# Static rendering cost only; navigation, combat and UI are not simulated.
	map.isometric_view = true
	map.generate(4242, Vector2(3200, 2200), "highlands")
	camera.rotation = -PI / 4
	camera.zoom = Vector2(1.3, 0.65)
	camera.position = map.world_size * 0.5
	camera.force_update_scroll()
	map.queue_redraw()
	var samples: Array[float] = []
	for frame in 50:
		await process_frame
		var start := Time.get_ticks_usec()
		RenderingServer.force_draw()
		if frame > 5: samples.append((Time.get_ticks_usec() - start) / 1000.0)
	samples.sort()
	print("TERRAIN_STATIC_RENDER_MS median=%.2f p95=%.2f depth_batches=%d" % [samples[samples.size() / 2], samples[int(samples.size() * 0.95)], map.occlusion_layer.pieces.size()])
	quit()
