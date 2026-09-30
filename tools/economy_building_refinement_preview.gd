extends SceneTree

const KINDS = ["town_center", "mill", "lumber_camp", "mining_camp", "siege_workshop"]
const LABELS = ["Town center", "Mill", "Lumber camp", "Mining camp", "Siege workshop"]
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
var portrait_script = Portrait

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://docs/economy-building-refinement"
	DirAccess.make_dir_recursive_absolute(output)
	var old_visual := OS.get_environment("RTS_BUILDING_BASELINE_VISUAL")
	if not old_visual.is_empty():
		baseline = load(old_visual)
		assert(baseline != null, "baseline renderer must load")
	var old_portrait := OS.get_environment("RTS_BUILDING_BASELINE_PORTRAIT")
	if not old_portrait.is_empty():
		portrait_script = load(old_portrait)
		assert(portrait_script != null, "baseline portrait must load")
	RenderingServer.set_default_clear_color(Color("77876a"))
	viewport = SubViewport.new()
	viewport.size = Vector2i(320, 360)
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
		var sheet := Image.create(1600, 1080, false, Image.FORMAT_RGB8)
		for row in 3:
			context.civilizations[0] = ["English", "French", "Chinese"][row]
			for column in 5:
				var building := _building(column)
				var zoom := 1.0 if mode == "map-zoom" else 1.8
				_configure(zoom, Vector2(160, 195 if mode == "2d" else 250), building.position)
				title.text = "%s / %s" % [context.civilizations[0], LABELS[column]]
				sheet.blit_rect(await _capture(), Rect2i(0, 0, 320, 360), Vector2i(column * 320, row * 360))
				building.free()
		var path := output.path_join(("before-" if baseline != null else "") + mode + ".png")
		assert(sheet.save_png(path) == OK)
		print("ECONOMY_BUILDING_PREVIEW_OK: ", path)
	var sheet := Image.create(1600, 1080, false, Image.FORMAT_RGB8)
	for row in 3:
		context.civilizations[0] = ["English", "French", "Chinese"][row]
		for column in 5:
			var building := _building(column)
			building.hide()
			var portrait: Control = portrait_script.new()
			overlay.add_child(portrait)
			portrait.position = Vector2(95, 94)
			portrait.size = Vector2(130, 170)
			portrait.subject = building
			title.text = "%s / %s" % [context.civilizations[0], LABELS[column]]
			sheet.blit_rect(await _capture(), Rect2i(0, 0, 320, 360), Vector2i(column * 320, row * 360))
			portrait.free()
			building.free()
	assert(sheet.save_png(output.path_join(("before-" if baseline != null else "") + "portraits.png")) == OK)
	quit()

func _building(column: int) -> RtsBuilding:
	var building := RtsBuilding.new()
	context.add_child(building)
	building.setup(context, 0, KINDS[column])
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
