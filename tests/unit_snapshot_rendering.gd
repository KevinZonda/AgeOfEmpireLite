extends SceneTree

const Visual = preload("res://scripts/entities/visuals/unit_visual.gd")
const VisualState = preload("res://scripts/entities/visuals/unit_visual_state.gd")

class Context extends Node2D:
	var started := false
	var view_mode_25d := false
	# Preview actors have no navigation service; exit still cancels their order lifecycle.
	var navigation: RtsNavigation
	var world_map: Node2D
	var camera := Camera2D.new()
	func player_color(_owner: int) -> Color: return Color("4e9bea")
	func should_show_health_bar(_hp: float, _max_hp: float, _timer: float) -> bool: return false

class SnapshotVisual extends Node2D:
	var state
	var renderer = Visual.new()
	func _draw() -> void: renderer.draw(self, state)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "This test requires a rendering driver")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(220, 220)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var context := Context.new()
	viewport.add_child(context)
	context.camera.enabled = false
	context.add_child(context.camera)
	var count := 0
	for kind in GameData.UNITS:
		for mode in 2:
			context.view_mode_25d = mode == 1
			for pose in 2:
				var unit := RtsUnit.new()
				unit.game = context
				unit.kind = kind
				unit.stats = GameData.UNITS[kind].duplicate(true)
				unit.visual_phase = 1.3
				unit.visual_moving = pose == 1
				unit.visual_action = "attack"
				unit.visual_action_length = 1.0
				unit.visual_action_timer = 0.3
				unit.paling_timer = float(pose)
				unit.position = Vector2(110, 125)
				unit.scale = Vector2.ONE * 2.0
				unit.process_mode = Node.PROCESS_MODE_DISABLED
				context.add_child(unit)
				var state = VisualState.capture(unit)
				await process_frame
				RenderingServer.force_draw()
				var live := viewport.get_texture().get_image()
				var snapshot := SnapshotVisual.new()
				snapshot.state = state
				snapshot.position = unit.position
				snapshot.scale = unit.scale
				unit.free()
				context.add_child(snapshot)
				await process_frame
				RenderingServer.force_draw()
				var remembered := viewport.get_texture().get_image()
				assert(live.get_data() == remembered.get_data(), "snapshot rendering differs for %s mode=%d pose=%d" % [kind, mode, pose])
				snapshot.free()
				count += 1
	print("UNIT_SNAPSHOT_RENDERING_OK appearances=%d" % count)
	quit()
