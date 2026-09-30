extends SceneTree

# Production siege rendering, no match simulation. Arguments: output directory,
# overview (default), directions, motion, or benchmark.
const Siege = preload("res://scripts/entities/visuals/siege_visual.gd")
const IsoProjection = preload("res://scripts/world/iso_projection.gd")
const KINDS = ["battering_ram", "trebuchet", "mangonel", "springald", "bombard", "cannon", "nest_of_bees", "siege_tower"]
const POSES = ["IDLE", "ROLLING", "WIND UP", "RELEASE", "RECOVER", "DEPLOY / LOADED"]

class Actor extends Node2D:
	var state
	var renderer = Siege.new()
	func _draw() -> void:
		if state.view_mode_25d:
			draw_set_transform_matrix(IsoProjection.upright(get_viewport().get_canvas_transform(), Vector2.ZERO, state.zoom))
		renderer.draw_shadow(self, state)
		renderer.draw(self, state)
		draw_set_transform_matrix(Transform2D.IDENTITY)

var viewport: SubViewport
var actor: Actor
var labels: CanvasLayer
var mode := "overview"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://docs/siege-refinement"
	mode = args[1] if args.size() > 1 else "overview"
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.set_default_clear_color(Color("41523e"))
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	actor = Actor.new()
	viewport.add_child(actor)
	labels = CanvasLayer.new()
	viewport.add_child(labels)
	if mode == "benchmark":
		await _benchmark()
		quit()
		return
	var columns := 6 if mode == "motion" else 8
	var rows := 4 if mode == "overview" else 8
	var cell := Vector2i(180, 280 if mode == "overview" else 210)
	var sheet := Image.create(cell.x * columns, cell.y * rows, false, Image.FORMAT_RGB8)
	for row in rows:
		for column in columns:
			var kind: String = KINDS[column] if mode == "overview" else KINDS[row]
			var iso := row < 2 if mode == "overview" else true
			var zoom := (2.6 if row % 2 == 0 else 1.0) if mode == "overview" else 1.65
			var heading := Vector2(1, 1).normalized() if mode != "directions" else Vector2.RIGHT.rotated(column * PI / 4)
			var picture := await _cell(kind, cell, iso, zoom, heading, column if mode == "motion" else 0)
			sheet.blit_rect(picture, Rect2i(Vector2i.ZERO, cell), Vector2i(column * cell.x, row * cell.y))
	var path := output.path_join(mode + ".png")
	assert(sheet.save_png(path) == OK)
	print("SIEGE_PREVIEW_OK ", path)
	quit()

func _cell(kind: String, cell: Vector2i, iso: bool, zoom: float, heading: Vector2, pose: int) -> Image:
	for child in labels.get_children(): child.free()
	viewport.size = cell
	var anchor := Vector2(cell.x * 0.5, cell.y * 0.78)
	viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, anchor) if iso else Transform2D(Vector2(zoom, 0), Vector2(0, zoom), anchor - Vector2(0, 35))
	actor.state = Siege.legacy_state(kind, float(GameData.UNITS[kind].get("radius", 19)), Color("4e9bea"), 0, iso)
	actor.state.view_mode_25d = iso
	actor.state.zoom = zoom
	actor.state.facing_direction = heading
	actor.state.visual_moving = pose == 1
	actor.state.visual_phase = 1.2
	actor.state.visual_action = "attack" if pose in [2, 3, 4] else ""
	actor.state.action_progress = 0.38 if pose == 2 else 0.5 if pose == 3 else 0.9 if pose == 4 else 0.0
	actor.state.action_released = pose in [3, 4]
	actor.state.release_elapsed = 0.07 if pose == 3 else 0.19 if pose == 4 else -1.0
	if "siege_deployed" in actor.state: actor.state.siege_deployed = pose == 5
	actor.state.passenger_count = 6 if pose == 5 else 0
	actor.queue_redraw()
	var label := Label.new()
	label.position = Vector2(9, 8)
	label.text = kind + "\n" + (POSES[pose] if mode == "motion" else "heading %d" % roundi(heading.angle() * 180 / PI) if mode == "directions" else ("2.5D" if iso else "2D") + " / %.1fx" % zoom)
	label.add_theme_font_size_override("font_size", 13)
	labels.add_child(label)
	await process_frame
	RenderingServer.force_draw()
	var picture := viewport.get_texture().get_image()
	picture.convert(Image.FORMAT_RGB8)
	return picture

func _benchmark() -> void:
	await _cell("trebuchet", Vector2i(1200, 800), true, 1.0, Vector2(1, 1).normalized(), 0)
	actor.hide()
	var actors: Array[Actor] = []
	for index in 96:
		var instance := Actor.new()
		instance.state = Siege.legacy_state(KINDS[index % 8], 19, Color("4e9bea"), 0, true)
		instance.state.zoom = 1.0
		instance.state.view_mode_25d = true
		instance.state.visual_moving = true
		instance.state.facing_direction = Vector2.RIGHT.rotated((index % 8) * PI / 4)
		instance.position = viewport.canvas_transform.affine_inverse() * Vector2(60 + (index % 12) * 95, 100 + (index / 12) * 85)
		viewport.add_child(instance)
		actors.append(instance)
	var samples: Array[float] = []
	for frame in 90:
		var start := Time.get_ticks_usec()
		for instance in actors:
			instance.state.visual_phase = frame * 0.12
			instance.queue_redraw()
		await process_frame
		RenderingServer.force_draw()
		if frame >= 10: samples.append((Time.get_ticks_usec() - start) / 1000.0)
	samples.sort()
	print("SIEGE_BENCHMARK 96 moving / render + frame wait ms median=%.2f p95=%.2f" % [samples[samples.size() / 2], samples[int(samples.size() * 0.95)]])
