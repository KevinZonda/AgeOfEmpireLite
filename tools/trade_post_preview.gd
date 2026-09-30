extends SceneTree

# Capture the production model in both projections and at normal map zoom.
class PreviewContext extends Node2D:
	var view_mode_25d := false
	var camera := Camera2D.new()
	var world_map: Node2D
	var text_scale := 1.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://docs/trade-post-preview"
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.set_default_clear_color(Color("77876a"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 340)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var context := PreviewContext.new()
	viewport.add_child(context)
	context.camera.enabled = false
	context.add_child(context.camera)
	var post := RtsTradePost.new()
	post.game = context
	context.add_child(post)
	var overlay := CanvasLayer.new()
	viewport.add_child(overlay)
	var title := Label.new()
	title.position = Vector2(16, 12)
	title.add_theme_font_size_override("font_size", 18)
	overlay.add_child(title)
	for isometric in [false, true]:
		context.view_mode_25d = isometric
		var sheet := Image.create(1080, 340, false, Image.FORMAT_RGB8)
		for column in 3:
			var zoom: float = [3.0, 1.5, 1.0][column]
			context.camera.zoom = Vector2(zoom, zoom * 0.5 if isometric else zoom)
			var origin := Vector2(180, 200 if isometric else 160)
			viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, origin) if isometric else Transform2D(Vector2(zoom, 0), Vector2(0, zoom), origin)
			title.text = "%s / %.1fx" % ["2.5D" if isometric else "2D", zoom]
			post.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw
			var captured := viewport.get_texture().get_image()
			assert(captured != null and not captured.is_empty())
			captured.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(captured, Rect2i(0, 0, 360, 340), Vector2i(column * 360, 0))
		var path := output.path_join("trade-post-%s.png" % ("25d" if isometric else "2d"))
		assert(sheet.save_png(path) == OK)
		print("TRADE_POST_PREVIEW_OK: ", path)
	quit()
