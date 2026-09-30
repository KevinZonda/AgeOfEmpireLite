extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 6789)
	game.paused = true
	game.fog.active = false
	var post: RtsTradePost = game.trade_posts[0]
	var roof := Vector3(-16, -3, 39.5)
	var goods := Vector3(-10, 35, 10)
	for projected in [false, true]:
		if game.view_mode_25d != projected: game._toggle_view_mode()
		for zoom in [0.65, 1.0, 2.2]:
			game.camera.zoom = Vector2(zoom, zoom * 0.5 if projected else zoom)
			game.camera.force_update_scroll()
			await process_frame
			var canvas: Transform2D = game.get_viewport().get_canvas_transform()
			for feature in [roof, goods, Vector3(25, 7, 18)]:
				var point := Vector2(feature.x, feature.y)
				if projected:
					var pixel: Vector2 = Vector2((feature.x - feature.y) * 0.70710678, (feature.x + feature.y) * 0.35355339 - feature.z) * zoom
					point = canvas.affine_inverse().basis_xform(pixel) + RtsIsoProjection.ground_lift(game, post.position)
				assert(game._trade_post_at(post.position + point) == post, "roof and goods should target the trade post in both views and at every zoom")
			assert(game._trade_post_at(post.position + Vector2(200, 200)) != post, "empty ground must not target the trade post")
	# Ground shadows and the caption are decorative, not trade targets.
	assert(not post.visual.contains(Vector2(43, 35), false), "shadow-only ground should not target the shop")
	assert(not post.visual.contains(Vector2(0, 55), true), "caption should not target the shop")
	print("TRADE_POST_TARGETING_OK")
	quit()
