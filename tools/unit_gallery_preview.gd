extends SceneTree

# Export the complete current unit roster using the production 2.5D renderer.
const Visual = preload("res://scripts/entities/visuals/unit_visual.gd")
const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const FONT = preload("res://assets/fonts/NotoSansSC-Regular.otf")
const GROUPS = [
	["01-support-melee", "经济、辅助与近战步兵", ["villager", "imperial_official", "trader", "monk", "spearman", "man_at_arms", "palace_guard"]],
	["02-ranged", "远程步兵", ["archer", "longbow", "crossbowman", "arbaletrier", "zhuge_nu", "handcannoneer", "grenadier"]],
	["03-cavalry", "骑兵", ["scout", "horseman", "knight", "royal_knight", "fire_lancer"]],
	["04-siege", "攻城器械", ["battering_ram", "trebuchet", "mangonel", "springald", "bombard", "cannon", "nest_of_bees", "siege_tower"]],
	["05-naval", "船只", ["fishing_boat", "arrow_ship", "springald_ship", "incendiary_ship", "warship", "transport_ship"]],
]
const CELL = Vector2i(360, 340)
const BACKGROUND = Color("253b35")

class Actor extends Node2D:
	var state
	var renderer = Visual.new()
	func _draw() -> void:
		renderer.draw(self, state)

var viewport: SubViewport
var actor: Actor
var overlay: CanvasLayer

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://docs/unit-gallery-25d"
	DirAccess.make_dir_recursive_absolute(output.path_join("units"))
	RenderingServer.set_default_clear_color(BACKGROUND)
	viewport = SubViewport.new()
	viewport.size = CELL
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	actor = Actor.new()
	viewport.add_child(actor)
	overlay = CanvasLayer.new()
	viewport.add_child(overlay)
	var seen := {}
	var cells: Array[Image] = []
	for group in GROUPS:
		var sheet := await _sheet(4, ceili(group[2].size() / 4.0), group[1])
		for index in group[2].size():
			var kind: String = group[2][index]
			assert(not seen.has(kind))
			seen[kind] = true
			var picture := await _cell(kind)
			assert(picture.save_png(output.path_join("units/" + kind + ".png")) == OK)
			sheet.blit_rect(picture, Rect2i(Vector2i.ZERO, CELL), Vector2i(index % 4 * CELL.x, 86 + index / 4 * CELL.y))
			cells.append(picture)
		assert(sheet.save_png(output.path_join(group[0] + ".png")) == OK)
	assert(seen.size() == GameData.UNITS.size(), "The gallery must include every unit.")
	var overview := await _sheet(6, ceili(cells.size() / 6.0), "全部单位 · %d 种" % cells.size())
	for index in cells.size():
		overview.blit_rect(cells[index], Rect2i(Vector2i.ZERO, CELL), Vector2i(index % 6 * CELL.x, 86 + index / 6 * CELL.y))
	assert(overview.save_png(output.path_join("all-units.png")) == OK)
	print("UNIT_GALLERY_OK ", seen.size(), " units · ", output)
	quit()

func _sheet(columns: int, rows: int, title: String) -> Image:
	var sheet := Image.create(CELL.x * columns, CELL.y * rows + 86, false, Image.FORMAT_RGB8)
	sheet.fill(BACKGROUND)
	for child in overlay.get_children(): child.free()
	actor.hide()
	viewport.size = Vector2i(sheet.get_width(), 86)
	_label(title + " · 2.5D", Vector2(0, 20), 30, Color("f4dfae"))
	await process_frame
	RenderingServer.force_draw()
	var header := viewport.get_texture().get_image()
	header.convert(Image.FORMAT_RGB8)
	sheet.blit_rect(header, Rect2i(0, 0, sheet.get_width(), 86), Vector2i.ZERO)
	return sheet

func _cell(kind: String) -> Image:
	for child in overlay.get_children(): child.free()
	viewport.size = CELL
	actor.show()
	actor.state = State.preview(kind, GameData.UNITS[kind], Color("4e9bea"))
	actor.state.view_mode_25d = true
	actor.state.facing_direction = Vector2(1, 1).normalized()
	actor.state.visual_phase = 0.0
	actor.scale = Vector2.ONE * 4.0
	actor.position = Vector2(CELL.x * 0.5, 260)
	if actor.state.tags.has("cavalry"):
		actor.scale = Vector2.ONE * 3.0
		actor.position.y = 290
	elif actor.state.tags.has("naval") and kind != "fishing_boat":
		actor.scale = Vector2.ONE * 3.0
	if actor.renderer.siege_renderer.handles(kind) or actor.state.tags.has("naval"):
		var bounds: Rect2
		if kind == "fishing_boat": bounds = actor.renderer.fishing_renderer.bounds(actor.state)
		elif actor.state.tags.has("naval"): bounds = actor.renderer.naval_renderer.bounds(actor.state)
		else: bounds = actor.renderer.siege_renderer.geometry(actor.state).bounds
		bounds = bounds.grow(7.0)
		var usable := Rect2(24, 86, CELL.x - 48, CELL.y - 114)
		var fit := minf(4.0, minf(usable.size.x / bounds.size.x, usable.size.y / bounds.size.y))
		actor.scale = Vector2.ONE * fit
		actor.position = usable.get_center() - bounds.get_center() * fit
	_label(GameData.UNITS[kind]["label"], Vector2(0, 12), 24, Color("f4dfae"))
	_label(kind, Vector2(0, 49), 14, Color("a7b8ad"))
	actor.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	var picture := viewport.get_texture().get_image()
	picture.convert(Image.FORMAT_RGB8)
	return picture

func _label(content: String, point: Vector2, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = content
	label.position = point
	label.size.x = viewport.size.x
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	overlay.add_child(label)
