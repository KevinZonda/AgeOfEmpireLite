extends SceneTree

const Manager = preload("res://scripts/match/objective_manager.gd")
const STATES = ["neutral", "blue", "red", "capturing", "contested", "reset"]
const LABELS = ["Neutral", "Blue owner", "Red owner", "Capturing 50%", "Contested", "After reset"]

class MapStub extends Node2D:
	var world_size := Vector2(2000, 2000)
	var ground_height := 0.0
	func nearest_walkable_point(point: Vector2) -> Vector2: return point
	func sacred_site_positions() -> Array[Vector2]: return [Vector2.ZERO, Vector2(600, 0), Vector2(0, 600)]
	func elevation_at(_point: Vector2) -> float: return ground_height

class Context extends Node2D:
	var world_map: MapStub
	var camera := Camera2D.new()
	var view_mode_25d := true
	var civilizations := ["English", "French"]
	var units: Array[Node2D] = []
	var buildings: Array[Node2D] = []
	var started := false
	var paused := true
	var game_over := false
	var fog: Node2D
	func player_color(owner: int) -> Color: return Color("4e9bea") if owner == 0 else Color("d66557")

var viewport: SubViewport
var context: Context
var title: Label

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else "res://docs/sacred-site-refinement"
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.set_default_clear_color(Color("77876a"))
	viewport = SubViewport.new()
	viewport.size = Vector2i(320, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	context = Context.new()
	viewport.add_child(context)
	context.world_map = MapStub.new()
	context.add_child(context.world_map)
	context.camera.enabled = false
	context.add_child(context.camera)
	var overlay := CanvasLayer.new()
	viewport.add_child(overlay)
	title = Label.new()
	title.position = Vector2(12, 12)
	title.add_theme_font_size_override("font_size", 14)
	overlay.add_child(title)
	for mode in ["25d", "2d", "map-zoom"]:
		context.view_mode_25d = mode != "2d"
		var sheet := Image.create(1920, 1080, false, Image.FORMAT_RGB8)
		for row in 3:
			context.world_map.ground_height = 21.0 if row == 2 else 0.0
			for column in 6:
				var manager = Manager.new()
				context.add_child(manager)
				manager.setup(context)
				manager.set_process(false)
				var state: Dictionary = manager.sacred_sites[row]
				configure_state(manager, state, STATES[column])
				for visual in manager.site_visuals: visual.sync_visual()
				var zoom := 1.0 if mode == "map-zoom" else 1.5
				_configure(zoom, Vector2(160, 190 if mode == "2d" else 245), state["position"])
				title.text = "%s / ruin %d%s" % [LABELS[column], row + 1, " / raised 21" if row == 2 else ""]
				manager.queue_redraw()
				sheet.blit_rect(await _capture(), Rect2i(0, 0, 320, 360), Vector2i(column * 320, row * 360))
				manager.free()
		var path := output.path_join(mode + ".png")
		assert(sheet.save_png(path) == OK)
		print("SACRED_SITE_PREVIEW_OK: ", path)
	quit()

static func configure_state(manager, state: Dictionary, status: String) -> void:
	match status:
		"blue": state["owner_id"] = 0
		"red": state["owner_id"] = 1
		"capturing":
			state["capture_owner"] = 0
			state["capture_progress"] = manager.CAPTURE_TIME * 0.5
		"contested":
			state["owner_id"] = 0
			state["contested"] = true
		"reset":
			state["owner_id"] = 1
			state["capture_owner"] = 0
			state["capture_progress"] = manager.CAPTURE_TIME * 0.5
			state["contested"] = true
			manager.reset()

func _configure(zoom: float, origin: Vector2, point: Vector2) -> void:
	context.camera.zoom = Vector2(zoom, zoom * 0.5 if context.view_mode_25d else zoom)
	var transform := Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, origin) if context.view_mode_25d else Transform2D(Vector2(zoom, 0), Vector2(0, zoom), origin)
	transform.origin -= transform.basis_xform(point)
	viewport.canvas_transform = transform

func _capture() -> Image:
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	RenderingServer.force_draw()
	var captured := viewport.get_texture().get_image()
	assert(captured != null and not captured.is_empty())
	captured.convert(Image.FORMAT_RGB8)
	return captured
