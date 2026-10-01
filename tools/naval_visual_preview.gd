extends SceneTree

# Render the actual UnitVisual, including its camera transform and waterline.
# Usage: godot --path . --script tools/naval_visual_preview.gd -- [output] [all|overview|directions|gameplay-scale|overview-2d]
const Visual = preload("res://scripts/entities/visuals/unit_visual.gd")
const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const Naval = preload("res://scripts/entities/visuals/naval_visual.gd")
const Fishing = preload("res://scripts/entities/visuals/fishing_boat_visual.gd")
const FONT = preload("res://assets/fonts/NotoSansSC-Regular.otf")
const KINDS = ["arrow_ship", "springald_ship", "incendiary_ship", "warship", "transport_ship"]
const ALL_KINDS = ["fishing_boat", "arrow_ship", "springald_ship", "incendiary_ship", "warship", "transport_ship"]
const HEADINGS = ["东", "东南", "南", "西南", "西", "西北", "北", "东北"]
const BACKGROUND := Color("24444a")
const TINT := Color("4e9bea")

class Actor extends Node2D:
	var state
	var renderer := Visual.new()
	func _draw() -> void:
		if state != null: renderer.draw(self, state)

var viewport: SubViewport
var actor: Actor
var labels: CanvasLayer
var naval := Naval.new()
var fishing := Fishing.new()

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Naval previews require the local graphics renderer")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else "res://docs/naval-refinement"
	var requested: String = args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.set_default_clear_color(BACKGROUND)
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	actor = Actor.new()
	viewport.add_child(actor)
	labels = CanvasLayer.new()
	viewport.add_child(labels)
	var modes: Array = ["overview", "directions", "gameplay-scale", "overview-2d"] if requested == "all" else [requested]
	for mode in modes:
		var picture: Image = await _sheet(mode)
		var path := output.path_join(mode + ".png")
		assert(picture.save_png(path) == OK)
		print("NAVAL_PREVIEW_OK ", path)
	quit()

func _sheet(mode: String) -> Image:
	assert(mode in ["overview", "directions", "gameplay-scale", "overview-2d"])
	var directions := mode == "directions"
	var actual := mode == "gameplay-scale"
	var iso := mode != "overview-2d"
	var cell := Vector2i(220, 240) if directions else Vector2i(200, 180) if actual else Vector2i(360, 340)
	var columns := 8 if directions else 6 if actual else 3
	var rows := 5 if directions else 2
	var title := "海军 · 八个航向" if directions else "海军 · 游戏原始尺寸（1×）" if actual else "海军 · 2.5D 船体与甲板" if iso else "海军 · 2D 航向投影"
	var sheet: Image = await _header(Vector2i(columns * cell.x, rows * cell.y + 76), title)
	for row in rows:
		for column in columns:
			var kind: String = KINDS[row] if directions else ALL_KINDS[column] if actual else ALL_KINDS[row * columns + column]
			var heading := column if directions else 1
			var moving := actual and row == 1
			var picture: Image = await _cell(kind, cell, iso, heading, moving, actual)
			sheet.blit_rect(picture, Rect2i(Vector2i.ZERO, cell), Vector2i(column * cell.x, 76 + row * cell.y))
	return sheet

func _header(dimensions: Vector2i, title: String) -> Image:
	for child in labels.get_children(): child.free()
	actor.hide()
	viewport.size = Vector2i(dimensions.x, 76)
	viewport.canvas_transform = Transform2D.IDENTITY
	_label(title, Vector2(0, 17), 28, Color("f4dfae"))
	await process_frame
	RenderingServer.force_draw()
	var sheet := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGB8)
	sheet.fill(BACKGROUND)
	var header := viewport.get_texture().get_image()
	header.convert(Image.FORMAT_RGB8)
	sheet.blit_rect(header, Rect2i(0, 0, dimensions.x, 76), Vector2i.ZERO)
	return sheet

func _cell(kind: String, cell: Vector2i, iso: bool, heading: int, moving: bool, actual: bool) -> Image:
	for child in labels.get_children(): child.free()
	viewport.size = cell
	actor.show()
	actor.state = State.preview(kind, GameData.UNITS[kind], TINT)
	actor.state.view_mode_25d = iso
	actor.state.facing_direction = Vector2.RIGHT.rotated(heading * PI / 4.0)
	actor.state.visual_moving = moving
	actor.state.visual_phase = 1.2 if moving else 0.0
	actor.state.passenger_count = 6 if kind == "transport_ship" else 0
	var bounds: Rect2 = fishing.bounds(actor.state) if kind == "fishing_boat" else naval.bounds(actor.state)
	bounds = bounds.grow(6.0)
	var usable := Rect2(15, 70, cell.x - 30, cell.y - 89)
	var zoom := 1.0 if actual else minf(3.3, minf(usable.size.x / bounds.size.x, usable.size.y / bounds.size.y))
	actor.state.zoom = zoom
	var anchor := usable.get_center() - bounds.get_center() * zoom
	viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, anchor) if iso else Transform2D(Vector2(zoom, 0), Vector2(0, zoom), anchor)
	_label(GameData.UNITS[kind]["label"], Vector2(0, 9), 20 if actual else 23, Color("f4dfae"))
	var detail: String = ("航行 · 尾流" if moving else "停泊 · 水线") if actual else "航向：" + HEADINGS[heading]
	if kind == "transport_ship": detail += " · 载员 6"
	_label(detail, Vector2(0, 42), 13, Color("b8d6d2"))
	actor.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	var picture := viewport.get_texture().get_image()
	picture.convert(Image.FORMAT_RGB8)
	return picture

func _label(content: String, point: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = content
	label.position = point
	label.size.x = viewport.size.x
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	labels.add_child(label)
