extends SceneTree

const Visual = preload("res://scripts/entities/visuals/unit_visual.gd")
const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const FOG := Color(0.035, 0.055, 0.065, 1.0)

class Soldier extends Node2D:
	var state
	var visual := Visual.new()
	func _draw() -> void: visual.draw(self, state)

func _initialize() -> void: call_deferred("_run")

func _capture(viewport: SubViewport) -> Image:
	await process_frame
	RenderingServer.force_draw()
	return viewport.get_texture().get_image()

func _blue(image: Image, anchor: Vector2, zoom: float) -> int:
	var pixels := 0
	var area := Rect2i(Vector2i(anchor - Vector2(22, 46) * zoom), Vector2i(Vector2(44, 50) * zoom)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var color := image.get_pixel(x, y)
			if color.b > color.r * 1.3 and color.b > color.g * 1.10 and color.b > 0.25: pixels += 1
	return pixels

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "terrain occlusion needs pixel rendering")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 640)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var map := RtsWorldMap.new()
	map.z_index = -10
	map.generate(4242, Vector2(500, 500))
	map.cells.fill(RtsWorldMap.Terrain.GRASS)
	map.plants.clear()
	map.stealth_patches.clear()
	for y in range(4, 7):
		for x in range(4, 7): map.cells[map._index(Vector2i(x, y))] = RtsWorldMap.Terrain.MOUNTAIN
	for y in map.grid_size.y + 1:
		for x in map.grid_size.x + 1:
			map.elevation_vertices[map._vertex_index(x, y)] = maxf(0, 160.0 * (1.0 - Vector2(x * 50, y * 50).distance_to(Vector2(300, 300)) / 150.0))
	viewport.add_child(map)
	var camera := Camera2D.new()
	camera.ignore_rotation = false
	camera.rotation = -PI / 4
	camera.position = Vector2(250, 250)
	viewport.add_child(camera)
	camera.make_current()
	var rear := Soldier.new()
	var front := Soldier.new()
	rear.position = Vector2(175, 175)
	front.position = Vector2(385, 385)
	for actor in [rear, front]:
		actor.z_index = roundi((actor.position.x + actor.position.y) * 0.5)
		actor.state = State.preview("spearman", GameData.UNITS["spearman"], Color("4e9bea"))
		actor.state.view_mode_25d = true
		actor.state.ground_height = map.elevation_at(actor.position)
		viewport.add_child(actor)
	var fog_image := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	var cases := 0
	for zoom in [0.7, 1.0, 1.65]:
		map.isometric_view = true
		camera.zoom = Vector2(zoom, zoom * 0.5)
		camera.force_update_scroll()
		map.queue_redraw()
		for actor in [rear, front]:
			actor.state.zoom = zoom
			actor.queue_redraw()
		await _capture(viewport)
		map.occlusion_layer.hide()
		var uncovered := await _capture(viewport)
		var canvas := viewport.get_canvas_transform()
		var rear_anchor: Vector2 = canvas * (rear.position + map.lift_per_height * rear.state.ground_height)
		var front_anchor: Vector2 = canvas * (front.position + map.lift_per_height * front.state.ground_height)
		var rear_pixels := _blue(uncovered, rear_anchor, zoom)
		var front_pixels := _blue(uncovered, front_anchor, zoom)
		assert(rear_pixels > 15 and front_pixels > 15, "fixture needs two visible production unit figures")
		map.occlusion_layer.show()
		var covered := await _capture(viewport)
		assert(_blue(covered, rear_anchor, zoom) < rear_pixels * 0.20, "a rear unit paints through the mountain")
		assert(_blue(covered, front_anchor, zoom) >= front_pixels * 0.95, "the mountain incorrectly covers a front unit")
		if zoom == 1.0:
			var comparison := Image.create(1280, 640, false, Image.FORMAT_RGB8)
			uncovered.convert(Image.FORMAT_RGB8)
			covered.convert(Image.FORMAT_RGB8)
			comparison.blit_rect(uncovered, Rect2i(0, 0, 640, 640), Vector2i.ZERO)
			comparison.blit_rect(covered, Rect2i(0, 0, 640, 640), Vector2i(640, 0))
			DirAccess.make_dir_recursive_absolute("res://tmp/terrain-preview")
			assert(comparison.save_png("res://tmp/terrain-preview/occlusion.png") == OK)
		var probe: Vector2 = canvas * (Vector2(300, 300) + map.lift_per_height * map.elevation_at(Vector2(300, 300))) + Vector2(0, 8 * zoom)
		var clear_color := covered.get_pixelv(Vector2i(probe.round()))
		assert(clear_color.r > 0.25, "fixture must sample visible rock")
		fog_image.fill(FOG)
		var texture := ImageTexture.create_from_image(fog_image)
		map.set_occlusion_fog(texture)
		var fogged := await _capture(viewport)
		var fog_color := fogged.get_pixelv(Vector2i(probe.round()))
		assert(absf(fog_color.r - FOG.r) < 0.015 and absf(fog_color.g - FOG.g) < 0.015, "occluding mountain reveals unexplored rock")
		fog_image.fill(Color(FOG, 0.68))
		texture.update(fog_image)
		var explored := await _capture(viewport)
		var explored_color := explored.get_pixelv(Vector2i(probe.round()))
		var expected := clear_color.lerp(FOG, 0.68)
		assert(absf(explored_color.r - expected.r) < 0.02, "explored mountain brightness disagrees with fog")
		fog_image.fill(Color.TRANSPARENT)
		texture.update(fog_image)
		var revealed := await _capture(viewport)
		assert(absf(revealed.get_pixelv(Vector2i(probe.round())).r - clear_color.r) < 0.015, "mountain does not follow the updated visibility texture")
		map.set_occlusion_fog(null)
		map.isometric_view = false
		map.queue_redraw()
		await _capture(viewport)
		assert(not map.occlusion_layer.visible, "top-down mode retains terrain occluders")
		cases += 1
	viewport.free()
	print("TERRAIN_OCCLUSION_OK zooms=%d rear_hidden=3 front_visible=3 fog_states=9" % cases)
	quit()
