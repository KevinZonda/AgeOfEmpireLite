extends SceneTree

# Production resource/portrait captures, with deterministic animation samples.
# godot --path . --script tools/fish_preview.gd -- --mode=all --output=/tmp/fish
const Portrait = preload("res://scripts/ui/selection_portrait.gd")
const VisualState = preload("res://scripts/entities/visuals/unit_visual_state.gd")

class PreviewContext extends Node2D:
	var view_mode_25d := false
	var camera := Camera2D.new()
	var started := false

var viewport: SubViewport
var context: PreviewContext
var labels: CanvasLayer

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Fish previews require a graphics renderer")
		quit(1)
		return
	var output := "res://docs/fish-refinement"
	var mode := "all"
	var positional := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--"): mode = arg.trim_prefix("--")
		elif positional == 0:
			output = arg
			positional += 1
		else: mode = arg
	if mode not in ["all", "overview", "motion", "portrait", "game"]:
		push_error("Mode must be all, overview, motion, portrait or game")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.set_default_clear_color(Color("315866"))
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	context = PreviewContext.new()
	viewport.add_child(context)
	context.camera.enabled = false
	context.add_child(context.camera)
	labels = CanvasLayer.new()
	viewport.add_child(labels)
	if mode in ["all", "overview"]: await _sheet(output, false)
	if mode in ["all", "motion"]: await _sheet(output, true)
	if mode in ["all", "portrait"]: await _portraits(output)
	viewport.free()
	if mode in ["all", "game"]: await _game_scene(output)
	print("FISH_PREVIEW_OK ", output)
	quit()

func _sheet(output: String, motion: bool) -> void:
	var cell := Vector2i(200, 210) if motion else Vector2i(260, 250)
	var columns := 8 if motion else 4
	var sheet := Image.create(cell.x * columns, cell.y * 2, false, Image.FORMAT_RGB8)
	for row in 2:
		for column in columns:
			_clear()
			var iso := row == 1
			var zoom := 3.0 if motion or column % 2 == 1 else 1.0
			_configure(cell, iso, zoom, Vector2(cell.x * 0.5, cell.y * 0.62))
			var sample_time := column * 0.15 if motion and column < 6 else 0.0
			var seed_point := Vector2(320, 240) if motion or column < 2 else Vector2(611, 429)
			var fish := _fish(Vector2.ZERO, seed_point)
			fish.fish_time = sample_time
			if motion and column >= 6: fish.amount = 200 if column == 6 else 40
			fish.queue_redraw()
			_label(("2.5D" if iso else "2D") + " / %.0fx" % zoom, Vector2(12, 12))
			var detail := "t = %.2f s" % sample_time if motion else "school %d" % (column / 2 + 1)
			if motion and column >= 6: detail = "%d%% remaining" % roundi(float(fish.amount) / fish.initial_amount * 100.0)
			_label(detail, Vector2(12, 38))
			sheet.blit_rect(await _capture(), Rect2i(Vector2i.ZERO, cell), Vector2i(column * cell.x, row * cell.y))
	var path := output.path_join("motion.png" if motion else "overview.png")
	assert(sheet.save_png(path) == OK)
	print("FISH_CAPTURE_OK ", path)

func _configure(dimensions: Vector2i, iso: bool, zoom: float, origin: Vector2) -> void:
	viewport.size = dimensions
	context.view_mode_25d = iso
	context.camera.zoom = Vector2(zoom, zoom * 0.5 if iso else zoom)
	viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, origin) if iso else Transform2D(Vector2(zoom, 0), Vector2(0, zoom), origin)

func _fish(point: Vector2, seed_point: Vector2) -> RtsResource:
	var fish := RtsResource.new()
	fish.game = context
	fish.position = seed_point
	fish.setup("food", 500, "fish")
	fish.position = point
	context.add_child(fish)
	fish.set_process(false)
	return fish

func _portraits(output: String) -> void:
	_clear()
	viewport.canvas_transform = Transform2D.IDENTITY
	context.view_mode_25d = false
	var sheet := Image.create(600, 230, false, Image.FORMAT_RGB8)
	sheet.fill(Color("315866"))
	var column := 0
	for dimensions in [Vector2i(102, 142), Vector2i(80, 110), Vector2i(160, 180)]:
		_clear()
		viewport.size = Vector2i(200, 230)
		var fish := _fish(Vector2.ZERO, Vector2(320, 240))
		fish.hide()
		var portrait := Portrait.new()
		labels.add_child(portrait)
		portrait.custom_minimum_size = Vector2.ZERO
		portrait.position = Vector2((200 - dimensions.x) * 0.5, 40)
		portrait.size = Vector2(dimensions)
		portrait.show_subject(fish)
		_label("%d x %d" % [dimensions.x, dimensions.y], Vector2(12, 12))
		sheet.blit_rect(await _capture(), Rect2i(0, 0, 200, 230), Vector2i(column * 200, 0))
		column += 1
	var path := output.path_join("portrait.png")
	assert(sheet.save_png(path) == OK)
	print("FISH_CAPTURE_OK ", path)

func _label(content: String, point: Vector2) -> void:
	var label := Label.new()
	labels.add_child(label)
	label.text = content
	label.position = point
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("edf0dd"))

func _clear() -> void:
	for child in context.get_children():
		if child != context.camera: child.free()
	for child in labels.get_children(): child.free()

func _capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var captured := viewport.get_texture().get_image()
	assert(captured != null and not captured.is_empty())
	captured.convert(Image.FORMAT_RGB8)
	return captured

func _dock_site(game, fish: Vector2) -> Vector2:
	for distance in range(64, 480, 16):
		for direction in 32:
			var candidate: Vector2 = game.snap_build_point("dock", fish + Vector2(distance, 0).rotated(direction * TAU / 32.0))
			if game.can_place("dock", candidate): return candidate
	return Vector2.INF

func _working_spot(game, fish: Vector2, index: int) -> Vector2:
	for turn in 32:
		var candidate := fish + Vector2(34, 0).rotated(index * PI + turn * TAU / 32.0)
		var clear := true
		for side in 8:
			if not game.world_map.is_navigable(candidate + Vector2(14, 0).rotated(side * TAU / 8.0)):
				clear = false
		if clear: return candidate
	return Vector2.INF

func _game_scene(output: String) -> void:
	# Isolate screenshots from OS window scaling and saved fullscreen settings.
	var game_viewport := SubViewport.new()
	game_viewport.size = Vector2i(1280, 720)
	game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(game_viewport)
	var game = load("res://scenes/main.tscn").instantiate()
	game_viewport.add_child(game)
	await process_frame
	game.selected_map_style = "lakes"
	game.start_game("English", 431)
	game.paused = true
	var fish: RtsResource
	var dock_point := Vector2.INF
	for resource in game.resources:
		if resource.appearance != "fish": continue
		if _working_spot(game, resource.position, 0) == Vector2.INF or _working_spot(game, resource.position, 1) == Vector2.INF: continue
		dock_point = _dock_site(game, resource.position)
		if dock_point != Vector2.INF:
			fish = resource
			break
	assert(fish != null, "The preview seed needs fish near a valid dock site")
	game.spawn_building(0, "dock", dock_point)
	var boats: Array[RtsUnit] = []
	for index in 4:
		var offset := Vector2(34, 0).rotated(index * PI / 2.0) if index < 2 else Vector2(110, 0).rotated(index * PI / 2.0)
		var spot: Vector2 = _working_spot(game, fish.position, index) if index < 2 else game.world_map.nearest_water_point(fish.position + offset)
		var boat: RtsUnit = game.spawn_unit(0, "fishing_boat", spot)
		boat.position = spot
		boat.visual_last_position = spot
		boat.visual_phase = index * 0.9 + 0.5
		if index < 2:
			boat.order_gather(fish)
			boat.work_timer = 0.3 if index == 0 else 0.8
			boat._face_direction(fish.position - spot)
			assert(VisualState.capture(boat).fishing_active)
		else:
			boat.visual_moving = true
			boat._face_direction(Vector2(-1, 1) if index == 2 else Vector2(1, -1))
		boats.append(boat)
	game.fog.active = false
	game.fog.hide()
	game.weather.hide()
	for resource in game.resources: resource.show()
	for building in game.buildings: building.show()
	for boat in boats: boat.show()
	game.selected.clear()
	game.selected.append(fish)
	game._rebuild_actions()
	game._update_hud()
	for iso in [false, true]:
		if game.view_mode_25d != iso: game._toggle_view_mode()
		for zoom in [1.0, 2.0]:
			game.camera.position = fish.position.lerp(dock_point, 0.35)
			game.camera.zoom = Vector2(zoom, zoom * 0.5 if iso else zoom)
			game.camera.force_update_scroll()
			game.camera.position += game_viewport.get_canvas_transform().affine_inverse().basis_xform(Vector2(0, 85))
			game.camera.force_update_scroll()
			for resource in game.resources:
				if resource.appearance == "fish":
					resource.fish_time = 0.45
					resource.queue_redraw()
			for boat in boats: boat.queue_redraw()
			for frame in 4:
				await process_frame
				await RenderingServer.frame_post_draw
			var suffix := "25d" if iso else "2d"
			var path := output.path_join("in-game-%s%s.png" % [suffix, "-1x" if zoom == 1.0 else ""])
			var captured := game_viewport.get_texture().get_image()
			assert(captured.get_size() == Vector2i(1280, 720))
			assert(captured.save_png(path) == OK)
			print("FISH_CAPTURE_OK ", path)
	game_viewport.free()
