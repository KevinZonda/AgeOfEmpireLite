extends SceneTree

# Uses the production snapshot renderer and HUD portrait, without a match.
# godot --path . --script tools/fishing_boat_preview.gd -- <output> <mode>
# Modes: overview, before, directions, motion, portrait.
const Visual = preload("res://scripts/entities/visuals/unit_visual.gd")
const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const TINT := Color("4e9bea")
const POSES := ["IDLE", "SAILING", "CAST NET", "NET IN WATER", "HAUL NET", "RECOVER"]

class Actor extends Node2D:
	var state
	var renderer := Visual.new()
	func _draw() -> void:
		if state != null: renderer.draw(self, state)

var viewport: SubViewport
var actor: Actor
var labels: CanvasLayer
var mode := "overview"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Fishing boat previews require a graphics renderer")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://docs/fishing-boat-refinement"
	mode = args[1] if args.size() > 1 else "overview"
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.set_default_clear_color(Color("315866"))
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	actor = Actor.new()
	viewport.add_child(actor)
	labels = CanvasLayer.new()
	viewport.add_child(labels)
	if mode == "portrait":
		await _portraits(output)
		quit()
		return
	var overview := mode in ["overview", "before"]
	var columns := 4 if overview else 8 if mode == "directions" else 6
	var rows := 2
	var cell := Vector2i(240, 260)
	var sheet := Image.create(cell.x * columns, cell.y * rows, false, Image.FORMAT_RGB8)
	for row in rows:
		for column in columns:
			var iso := row == 0
			var zoom := (3.3 if column % 2 == 0 else 1.0) if overview else 2.7
			var heading := Vector2.RIGHT.rotated(column * PI / 4) if mode == "directions" else Vector2.RIGHT if column < 2 or not overview else Vector2.LEFT
			var picture := await _cell(cell, iso, zoom, heading, column if mode == "motion" else 0)
			sheet.blit_rect(picture, Rect2i(Vector2i.ZERO, cell), Vector2i(column * cell.x, row * cell.y))
	var path := output.path_join(mode + ".png")
	assert(sheet.save_png(path) == OK)
	print("FISHING_BOAT_PREVIEW_OK ", path)
	quit()

func _cell(cell: Vector2i, iso: bool, zoom: float, heading: Vector2, pose: int) -> Image:
	for child in labels.get_children(): child.free()
	viewport.size = cell
	var anchor := Vector2(cell.x * 0.5, cell.y * 0.63)
	viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, anchor) if iso else Transform2D(Vector2(zoom, 0), Vector2(0, zoom), anchor)
	actor.state = State.preview("fishing_boat", GameData.UNITS["fishing_boat"], TINT)
	actor.state.view_mode_25d = iso
	actor.state.zoom = zoom
	actor.state.facing_direction = heading
	actor.state.visual_moving = pose == 1
	actor.state.visual_phase = [0.0, 1.2, 0.4, 1.8, 3.5, 5.3][pose]
	actor.state.visual_action = "gather" if pose >= 2 else ""
	actor.state.gather_kind = "fish" if pose >= 2 else ""
	actor.state.action_progress = [0.0, 0.0, 0.15, 0.45, 0.75, 0.95][pose]
	if "fishing_active" in actor.state: actor.state.fishing_active = pose >= 2
	if "fishing_cycle" in actor.state: actor.state.fishing_cycle = [0.0, 0.0, 0.08, 0.35, 0.7, 0.94][pose]
	actor.queue_redraw()
	var label := Label.new()
	label.position = Vector2(10, 10)
	label.text = ("2.5D" if iso else "2D") + " / %.1fx" % zoom + "\n" + (POSES[pose] if mode == "motion" else "heading %d deg" % roundi(heading.angle() * 180 / PI))
	label.add_theme_font_size_override("font_size", 15)
	labels.add_child(label)
	await process_frame
	RenderingServer.force_draw()
	var picture := viewport.get_texture().get_image()
	picture.convert(Image.FORMAT_RGB8)
	return picture

func _portraits(output: String) -> void:
	actor.hide()
	labels.hide()
	viewport.canvas_transform = Transform2D.IDENTITY
	var sheet := Image.create(570, 190, false, Image.FORMAT_RGB8)
	sheet.fill(Color("315866"))
	var column := 0
	for dimensions in [Vector2i(102, 142), Vector2i(80, 110), Vector2i(160, 180)]:
		viewport.size = dimensions
		var portrait := RtsSelectionPortrait.new()
		viewport.add_child(portrait)
		portrait.custom_minimum_size = Vector2.ZERO
		portrait.size = Vector2(dimensions)
		var unit := RtsUnit.new()
		unit.kind = "fishing_boat"
		unit.stats = GameData.UNITS["fishing_boat"].duplicate(true)
		portrait.show_subject(unit, TINT)
		await process_frame
		RenderingServer.force_draw()
		var picture := viewport.get_texture().get_image()
		picture.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(picture, Rect2i(Vector2i.ZERO, dimensions), Vector2i(column * 190 + 15, 5))
		portrait.free()
		unit.free()
		column += 1
	var path := output.path_join("portrait.png")
	assert(sheet.save_png(path) == OK)
	print("FISHING_BOAT_PREVIEW_OK ", path)
