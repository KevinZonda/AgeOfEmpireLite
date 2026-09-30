extends SceneTree

const Siege = preload("res://scripts/entities/visuals/siege_visual.gd")
const Guns = preload("res://scripts/entities/visuals/siege_gunpowder_models.gd")
const SCALE := 8.0
const ANCHOR := Vector2(320, 470)

class Detail extends Node2D:
	var state
	var renderer := Siege.new()
	func _draw() -> void: renderer.draw(self, state)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 640)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var actor := Detail.new()
	actor.position = ANCHOR
	actor.scale = Vector2.ONE * SCALE
	viewport.add_child(actor)
	var mouths := 0
	var posts := 0
	for iso in [false, true]:
		for heading in [PI / 4, PI / 2, PI * 3 / 4]:
			actor.state = Siege.legacy_state("nest_of_bees", 19, Color("4e9bea"), 0, iso)
			actor.state.facing_direction = Vector2.RIGHT.rotated(heading)
			actor.queue_redraw()
			await process_frame
			RenderingServer.force_draw()
			var picture := viewport.get_texture().get_image()
			var g = actor.renderer.geometry(actor.state)
			for row in 3:
				for column in 4:
					var tube := Vector3(-7.5 + column * 5, -9.45, -5 + row * 5)
					var center_pixel: Vector2 = ANCHOR + g.project(Guns._rack_point(tube + Vector3(0, -0.12, 0), -0.38)) * SCALE
					var bore := picture.get_pixelv(Vector2i(center_pixel.round()))
					assert(bore.r < 0.15 and bore.g < 0.15, "tube bore covered: iso=%s heading=%.2f row=%d column=%d" % [iso, heading, row, column])
					var visible_rim := 0
					for sample in 8:
						var angle := TAU * sample / 8
						var point: Vector3 = Guns._rack_point(tube + Vector3(cos(angle) * 1.45, 0, sin(angle) * 1.45), -0.38)
						var pixel: Vector2 = ANCHOR + g.project(point) * SCALE
						var color := picture.get_pixelv(Vector2i(pixel.round()))
						if color.r > 0.28 and color.r > color.g * 1.15 and color.b < color.g * 0.85: visible_rim += 1
					assert(visible_rim >= 5, "tube rim missing: iso=%s heading=%.2f row=%d column=%d visible=%d" % [iso, heading, row, column, visible_rim])
					mouths += 1
			actor.state = Siege.legacy_state("battering_ram", 18, Color("4e9bea"), 0, iso)
			actor.state.facing_direction = Vector2.RIGHT.rotated(heading)
			actor.queue_redraw()
			await process_frame
			RenderingServer.force_draw()
			picture = viewport.get_texture().get_image()
			g = actor.renderer.geometry(actor.state)
			for x in [-13.0, 13.0]:
				for height in range(9, 23):
					var pixel: Vector2 = ANCHOR + g.project(Vector3(x, -18, height)) * SCALE
					var color := picture.get_pixelv(Vector2i(pixel.round()))
					assert(color.g <= color.r * 1.2, "grass cuts through ram post: iso=%s heading=%.2f x=%.1f z=%d" % [iso, heading, x, height])
				posts += 1
	viewport.free()
	print("SIEGE_DETAIL_OCCLUSION_OK mouths=%d continuous_posts=%d" % [mouths, posts])
	quit()
