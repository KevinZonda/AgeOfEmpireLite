extends SceneTree

const Fill = preload("res://scripts/entities/visuals/filled_polygon.gd")

class Swatches extends Node2D:
	func _draw() -> void:
		var shapes := [
			PackedVector2Array([Vector2(2, 5), Vector2(65, 8), Vector2(32, 64)]),
			PackedVector2Array([Vector2(2, 5), Vector2(65, 8), Vector2(59, 64), Vector2(12, 50)]),
			PackedVector2Array([Vector2(2, 5), Vector2(65, 8), Vector2(24, 24), Vector2(12, 64)]),
			PackedVector2Array([Vector2(2, 5), Vector2(65, 8), Vector2(32, 8), Vector2(12, 64)]),
			PackedVector2Array([Vector2(2, 5), Vector2(32, 1), Vector2(65, 8), Vector2(59, 64), Vector2(12, 50)])]
		for i in shapes.size():
			for reverse in 2:
				var shape: PackedVector2Array = shapes[i].duplicate()
				if reverse: shape.reverse()
				draw_set_transform(Vector2(10 + i * 90, 10 + reverse * 110), 0.07)
				Fill.draw(self, shape, Color(0.21, 0.63, 0.47, 0.61))
				draw_set_transform(Vector2(20 + i * 90, 20 + reverse * 110), -0.03)
				Fill.draw(self, shape, Color(0.75, 0.37, 0.27, 0.42))

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "This test needs an actual rendering driver")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 240)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var swatches := Swatches.new()
	viewport.add_child(swatches)
	var images: Array[Image] = []
	for legacy in [true, false]:
		Fill.force_legacy = legacy
		swatches.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		images.append(viewport.get_texture().get_image())
	var a := images[0].get_data()
	var b := images[1].get_data()
	var changed := 0
	for i in a.size():
		if absi(int(a[i]) - int(b[i])) > 1: changed += 1
	print("FILLED_POLYGON_RENDERING channels_differing_over_one=%d total_channels=%d" % [changed, a.size()])
	quit(0 if changed == 0 else 1)
