extends SceneTree

# Production resource renderer: isolated variants, harvest states, clusters,
# and resource portraits. Run with a rendering driver (not --headless).
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
	var output := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://docs/vegetation-preview"
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
		var sheet := Image.create(1260, 600, false, Image.FORMAT_RGB8)
		for column in 7:
			_clear()
			_configure(Vector2i(180, 250), 2.0, Vector2(90, 210 if iso else 145))
			var plant := _plant(column < 4, Vector2.ZERO, Vector2(column * 71 + 3, column * 37 + 8))
			plant.amount = plant.initial_amount if column < 5 else 210 if column == 5 else 60
			_label("TREE %d" % (column + 1) if column < 4 else ["BERRIES 100%", "BERRIES 50%", "BERRIES 14%"][column - 4], Vector2(12, 14))
			_label("2.5D" if iso else "2D", Vector2(12, 40))
			sheet.blit_rect(await _capture(), Rect2i(0, 0, 180, 250), Vector2i(column * 180, 0))
		for panel in 3:
			_clear()
			_configure(Vector2i(420, 350), 1.4 if panel == 0 else 1.0, Vector2(210, 165))
			if panel < 2:
				for i in 8:
					var point := Vector2((i % 3) * 49 - 65, (i / 3) * 47 - 45)
					_plant(true, point, point)
				for i in 3:
					var point := Vector2(i * 46 - 53, 97)
					_plant(false, point, point)
				_label("CLUSTER / %.1fx" % (1.4 if panel == 0 else 1.0), Vector2(12, 14))
			else:
				_label("RESOURCE PORTRAITS", Vector2(12, 14))
				for i in 2:
					var plant := _plant(i == 0, Vector2.ZERO, Vector2(3, 8))
					plant.hide()
					var portrait := Portrait.new()
					label_layer.add_child(portrait)
					portrait.position = Vector2(60 + i * 180, 72)
					portrait.size = Vector2(120, 150)
					portrait.subject = plant
			sheet.blit_rect(await _capture(), Rect2i(0, 0, 420, 350), Vector2i(panel * 420, 250))
		var path := output.path_join("vegetation-%s.png" % ("25d" if iso else "2d"))
		assert(sheet.save_png(path) == OK)
		print("VEGETATION_PREVIEW_OK: ", path)
	quit()

func _configure(size: Vector2i, zoom: float, origin: Vector2) -> void:
	viewport.size = size
	context.camera.zoom = Vector2(zoom, zoom * 0.5 if context.view_mode_25d else zoom)
	viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, origin) if context.view_mode_25d else Transform2D(Vector2(zoom, 0), Vector2(0, zoom), origin)

func _plant(tree: bool, point: Vector2, seed_point: Vector2) -> RtsResource:
	var plant := RtsResource.new()
	plant.game = context
	plant.position = seed_point
	plant.setup("wood" if tree else "food", 500 if tree else 420, "tree" if tree else "berry")
	plant.position = point
	plant.z_index = roundi(point.x + point.y) if context.view_mode_25d else roundi(point.y)
	context.add_child(plant)
	plant.set_process(false)
	return plant

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
	# Resizing a render target invalidates its backing texture for one frame.
	await process_frame
	await RenderingServer.frame_post_draw
	var captured := viewport.get_texture().get_image()
	assert(captured != null and not captured.is_empty())
	captured.convert(Image.FORMAT_RGB8)
	return captured
