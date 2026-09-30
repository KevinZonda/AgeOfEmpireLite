extends SceneTree

# Uses production resources and portraits. Requires a graphics driver.
const Portrait = preload("res://scripts/ui/selection_portrait.gd")
class PreviewContext extends Node2D:
	var view_mode_25d := false
	var camera := Camera2D.new()
	var world_map: Node2D
	var started := false

var viewport: SubViewport
var context: PreviewContext
var label_layer: CanvasLayer

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://docs/ore-preview"
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.set_default_clear_color(Color("77876a"))
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	context = PreviewContext.new()
	viewport.add_child(context)
	context.camera.enabled = false
	context.add_child(context.camera)
	label_layer = CanvasLayer.new()
	viewport.add_child(label_layer)
	for iso in [false, true]:
		context.view_mode_25d = iso
		var sheet := Image.create(1440, 600, false, Image.FORMAT_RGB8)
		for column in 8:
			_clear()
			_configure(Vector2i(180, 250), 2.5, Vector2(90, 165 if iso else 140))
			var ore := _ore(column < 4, Vector2.ZERO, Vector2((column % 4) * 71 + 3, (column % 4) * 37 + 8))
			if column % 4 == 3: ore.amount = 70
			_label(("STONE" if column < 4 else "GOLD") + (" / 14%" if column % 4 == 3 else " / %d" % (column % 4 + 1)), Vector2(12, 14))
			_label("2.5D / 2.5x" if iso else "2D / 2.5x", Vector2(12, 40))
			sheet.blit_rect(await _capture(), Rect2i(0, 0, 180, 250), Vector2i(column * 180, 0))
		for panel in 3:
			_clear()
			_configure(Vector2i(480, 350), 1.4 if panel == 0 else 1.0, Vector2(240, 125))
			if panel < 2:
				for stone in [true, false]:
					for i in 4:
						var point := Vector2(i * 46 - 70, -30 if stone else 65)
						_ore(stone, point, point)
				_label("CLUSTERS / %.1fx" % (1.4 if panel == 0 else 1.0), Vector2(12, 14))
			else:
				_label("RESOURCE PORTRAITS", Vector2(12, 14))
				for i in 2:
					var ore := _ore(i == 0, Vector2.ZERO, Vector2(3, 8))
					ore.hide()
					var portrait := Portrait.new()
					label_layer.add_child(portrait)
					portrait.position = Vector2(75 + i * 210, 72)
					portrait.size = Vector2(120, 150)
					portrait.subject = ore
			sheet.blit_rect(await _capture(), Rect2i(0, 0, 480, 350), Vector2i(panel * 480, 250))
		var path := output.path_join("ore-%s.png" % ("25d" if iso else "2d"))
		assert(sheet.save_png(path) == OK)
		print("ORE_PREVIEW_OK: ", path)
	quit()

func _configure(size: Vector2i, zoom: float, origin: Vector2) -> void:
	viewport.size = size
	context.camera.zoom = Vector2(zoom, zoom * 0.5 if context.view_mode_25d else zoom)
	viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, origin) if context.view_mode_25d else Transform2D(Vector2(zoom, 0), Vector2(0, zoom), origin)

func _ore(stone: bool, point: Vector2, seed_point: Vector2) -> RtsResource:
	var ore := RtsResource.new()
	ore.game = context
	ore.position = seed_point
	ore.setup("stone" if stone else "gold", 500, "ore")
	ore.position = point
	ore.z_index = roundi(point.x + point.y) if context.view_mode_25d else roundi(point.y)
	context.add_child(ore)
	ore.set_process(false)
	return ore

func _label(content: String, point: Vector2) -> void:
	var label := Label.new()
	label_layer.add_child(label)
	label.text = content
	label.position = point
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("edf0dd"))

func _clear() -> void:
	for node in context.get_children():
		if node != context.camera: node.free()
	for node in label_layer.get_children(): node.free()

func _capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var captured := viewport.get_texture().get_image()
	assert(captured != null and not captured.is_empty())
	captured.convert(Image.FORMAT_RGB8)
	return captured
