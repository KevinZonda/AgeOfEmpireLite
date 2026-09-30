extends SceneTree

const Figure = preload("res://scripts/entities/visuals/unit_figure_visual.gd")
const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")

# Save the code-drawn relic in both camera modes for visual review.
class PreviewContext extends Node2D:
	class PreviewFog extends RefCounted:
		var active := false
		func can_see(_owner: int, _point: Vector2) -> bool: return true
	var view_mode_25d := false
	var camera := Camera2D.new()
	var world_map: Node2D
	var fog := PreviewFog.new()

class MonkPreview extends Node2D:
	var view_mode_25d := false
	var state = State.preview("monk", GameData.UNITS["monk"], Color("4e9bea"))
	var figure := Figure.new()
	func _draw() -> void:
		state.carries_relic = true
		if view_mode_25d:
			draw_set_transform_matrix(RtsIsoProjection.upright(get_viewport().get_canvas_transform(), Vector2.ZERO, 3.0))
			figure.draw(self, state)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		else:
			figure.draw(self, state)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://.godot/relic-rendering"
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 320)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	RenderingServer.set_default_clear_color(Color("77876a"))
	var context := PreviewContext.new()
	viewport.add_child(context)
	context.camera.enabled = false
	context.add_child(context.camera)
	var relic := RtsRelic.new()
	context.add_child(relic)
	relic.game = context
	relic.set_process(false)
	var monk := MonkPreview.new()
	context.add_child(monk)
	monk.visible = false
	for mode in ["2d", "25d"]:
		context.view_mode_25d = mode == "25d"
		context.camera.zoom = Vector2(3.0, 1.5 if context.view_mode_25d else 3.0)
		viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339) * 3.0, Vector2(-0.70710678, 0.35355339) * 3.0, Vector2(160, 230)) if context.view_mode_25d else Transform2D(Vector2(3, 0), Vector2(0, 3), Vector2(160, 160))
		for subject in ["relic", "monk-carried"]:
			relic.visible = subject == "relic"
			monk.visible = subject == "monk-carried"
			monk.view_mode_25d = context.view_mode_25d
			relic.queue_redraw()
			monk.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var captured := viewport.get_texture().get_image()
			assert(captured != null and not captured.is_empty())
			assert(captured.save_png(output.path_join(subject + "-" + mode + ".png")) == OK)
	print("RELIC_RENDERING_OK: " + output)
	quit()
