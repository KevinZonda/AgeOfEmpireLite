extends SceneTree

# Real building and selection-panel renders for the four western landmarks.
# Example: godot --path . --script res://tools/western_landmark_refinement_preview.gd -- /tmp/landmarks --prefix=before-
const IDS = ["eng_council_hall", "eng_wynguard_palace", "fr_chamber_of_commerce", "fr_college_of_artillery"]
const LABELS = ["Council Hall", "Wynguard Palace", "Chamber of Commerce", "College of Artillery"]
const CELL_SIZE = Vector2i(360, 400)
const Portrait = preload("res://scripts/ui/selection_portrait.gd")

class PreviewContext extends Node2D:
	const HEALTH_BAR_CHANGE_DURATION := 3.0
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
	func should_show_health_bar(_current: float, _maximum: float, _timer: float) -> bool: return false

var viewport: SubViewport
var context: PreviewContext
var overlay: CanvasLayer
var title: Label

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := "res://docs/western-landmark-refinement"
	var prefix := ""
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty() and not arguments[0].begins_with("--"):
		output = arguments[0]
	for argument in arguments:
		if argument.begins_with("--prefix="):
			prefix = argument.trim_prefix("--prefix=")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	RenderingServer.set_default_clear_color(Color("77876a"))
	viewport = SubViewport.new()
	viewport.size = CELL_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	context = PreviewContext.new()
	viewport.add_child(context)
	context.camera.enabled = false
	context.add_child(context.camera)
	overlay = CanvasLayer.new()
	viewport.add_child(overlay)
	title = Label.new()
	title.position = Vector2(12, 12)
	title.add_theme_font_size_override("font_size", 16)
	overlay.add_child(title)
	for mode in ["25d", "2d", "map-zoom", "construction-25d", "portraits"]:
		context.view_mode_25d = mode != "2d"
		var sheet := Image.create(CELL_SIZE.x * IDS.size(), CELL_SIZE.y, false, Image.FORMAT_RGB8)
		for column in IDS.size():
			var building := _building(column, mode == "construction-25d")
			var zoom := 1.0 if mode == "map-zoom" else 1.8
			_configure(zoom, Vector2(180, 220 if mode == "2d" else 270), building.position)
			title.text = "%s\n%s" % [LABELS[column], context.civilizations[0]]
			var portrait: Control
			if mode == "portraits":
				building.hide()
				portrait = Portrait.new()
				overlay.add_child(portrait)
				portrait.position = Vector2(115, 110)
				portrait.size = Vector2(130, 170)
				portrait.show_subject(building, context.player_color(0))
			sheet.blit_rect(await _capture(), Rect2i(Vector2i.ZERO, CELL_SIZE), Vector2i(column * CELL_SIZE.x, 0))
			if portrait != null: portrait.free()
			building.free()
		var path := output.path_join(prefix + mode + ".png")
		assert(sheet.save_png(path) == OK)
		print("WESTERN_LANDMARK_PREVIEW_OK: ", path)
	quit()

func _building(column: int, construction: bool) -> RtsBuilding:
	var id: String = IDS[column]
	context.civilizations[0] = RtsLandmarkCatalog.LANDMARKS[id]["civilization"]
	var building := RtsBuilding.new()
	context.add_child(building)
	building.setup(context, 0, "landmark", construction, id)
	if construction:
		building.build_remaining = building.build_total * 0.6
		building.hp = building.max_hp * (1.0 - 0.7 * 0.6)
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
