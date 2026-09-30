extends SceneTree

const Portrait = preload("res://scripts/ui/selection_portrait.gd")
class Context extends Node2D:
	var view_mode_25d := true
	var show_building_icons := false
	var show_building_names := false
	var world_map: Node2D
	var camera := Camera2D.new()
	var civilizations := ["English"]
	var players := [{"landmarks": []}]
	var world_size := Vector2(2000, 2000)
	var started := false
	func spawn_point_for(_owner: int) -> Vector2: return Vector2.ZERO
	func player_color(_owner: int) -> Color: return Color("4e9bea")
	func should_show_health_bar(_a: float, _b: float, _c: float) -> bool: return false

var viewport: SubViewport
var context: Context
var overlay: CanvasLayer
var title: Label
var baseline

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://docs/building-refinement"
	DirAccess.make_dir_recursive_absolute(output)
	var old_visual := OS.get_environment("RTS_BUILDING_BASELINE_VISUAL")
	if not old_visual.is_empty(): baseline = load(old_visual)
	RenderingServer.set_default_clear_color(Color("77876a"))
	viewport = SubViewport.new()
	viewport.size = Vector2i(240, 270)
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
	title.add_theme_font_size_override("font_size", 15)
	overlay.add_child(title)
	for mode in ["25d", "2d", "map-zoom"]:
		context.view_mode_25d = mode != "2d"
		var sheet := Image.create(1200, 810, false, Image.FORMAT_RGB8)
		for row in 3:
			context.civilizations[0] = ["English", "French", "Chinese"][row]
			for column in 5:
				var building := _building(column)
				var zoom := 1.0 if mode == "map-zoom" else 2.4
				_configure(zoom, Vector2(120, 155 if mode == "2d" else 195), building.position)
				title.text = "%s / %s" % [context.civilizations[0], "House %d" % (column + 1) if column < 3 else "Blacksmith" if column == 3 else "Market"]
				sheet.blit_rect(await _capture(), Rect2i(0, 0, 240, 270), Vector2i(column * 240, row * 270))
				building.free()
		var path := output.path_join(("before-" if baseline != null else "") + mode + ".png")
		assert(sheet.save_png(path) == OK)
		print("BUILDING_REFINEMENT_PREVIEW_OK: ", path)
	if baseline == null:
		var sheet := Image.create(720, 810, false, Image.FORMAT_RGB8)
		for row in 3:
			context.civilizations[0] = ["English", "French", "Chinese"][row]
			for column in 3:
				var building := _building(0 if column == 0 else column + 2)
				building.hide()
				var portrait := Portrait.new()
				overlay.add_child(portrait)
				portrait.position = Vector2(55, 64)
				portrait.size = Vector2(130, 170)
				portrait.subject = building
				title.text = "%s / %s" % [context.civilizations[0], ["House", "Blacksmith", "Market"][column]]
				sheet.blit_rect(await _capture(), Rect2i(0, 0, 240, 270), Vector2i(column * 240, row * 270))
				portrait.free()
				building.free()
		assert(sheet.save_png(output.path_join("portraits.png")) == OK)
	quit()

func _building(column: int) -> RtsBuilding:
	var building := RtsBuilding.new()
	if column < 3:
		for i in 100:
			var seed_point := Vector2(i * 43 + 7, i * 19 + 11)
			if absi(hash(seed_point)) % 3 == column:
				building.position = seed_point
				break
	context.add_child(building)
	building.setup(context, 0, "house" if column < 3 else "blacksmith" if column == 3 else "market")
	if baseline != null: building.building_visual = baseline.new()
	building.set_process(false)
	return building

func _configure(zoom: float, origin: Vector2, point: Vector2) -> void:
	context.camera.zoom = Vector2(zoom, zoom * 0.5 if context.view_mode_25d else zoom)
	var transform := Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, origin) if context.view_mode_25d else Transform2D(Vector2(zoom, 0), Vector2(0, zoom), origin)
	transform.origin -= transform.basis_xform(point)
	viewport.canvas_transform = transform

func _capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var captured := viewport.get_texture().get_image()
	assert(captured != null and not captured.is_empty())
	captured.convert(Image.FORMAT_RGB8)
	return captured
