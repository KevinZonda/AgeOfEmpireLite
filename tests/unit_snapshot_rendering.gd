extends SceneTree

const Visual = preload("res://scripts/entities/visuals/unit_visual.gd")
const VisualState = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const Figure = preload("res://scripts/entities/visuals/unit_figure_visual.gd")

class Context extends Node2D:
	var started := false
	var view_mode_25d := false
	# Preview actors have no navigation service; exit still cancels their order lifecycle.
	var navigation: RtsNavigation
	var world_map: Node2D
	var camera := Camera2D.new()
	var show_health := false
	func player_color(_owner: int) -> Color: return Color("4e9bea")
	func should_show_health_bar(_hp: float, _max_hp: float, _timer: float) -> bool: return show_health

class SnapshotVisual extends Node2D:
	var state
	var renderer = Visual.new()
	func _draw() -> void: renderer.draw(self, state)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "This test requires a rendering driver")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(300, 260)
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
			# Capture actual camera projection, rather than only changing the mode flag.
			viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339), Vector2(-0.70710678, 0.35355339), Vector2(150, 170)) if mode == 1 else Transform2D(0.0, Vector2(150, 170))
			var humanoid: bool = Figure.handles(kind)
			for pose in (8 if humanoid else 2):
				context.show_health = humanoid and pose >= 4
				var unit := RtsUnit.new()
				unit.game = context
				unit.kind = kind
				unit.stats = GameData.UNITS[kind].duplicate(true)
				unit.visual_phase = 1.3
				unit.visual_moving = pose == 1
				unit.facing_right = pose == 0
				unit.visual_action = "attack"
				unit.visual_action_length = 1.0
				unit.visual_action_timer = 0.3
				if humanoid:
					unit.visual_facing_world = Vector2.RIGHT.rotated(pose * PI / 4.0)
					unit.visual_action_timer = 0.8 if pose < 4 else 0.5
					unit.visual_action_released = pose >= 4
					unit.visual_release_elapsed = 0.02 if pose == 4 else 0.15 if pose >= 4 else -1.0
					unit.charging = kind in ["horseman", "knight", "royal_knight", "fire_lancer"] and pose == 3
					unit.visual_charge_impact = unit.charging or kind in ["horseman", "knight", "royal_knight", "fire_lancer"] and pose == 4
					unit.shield_timer = 1.0 if kind == "arbaletrier" and pose >= 4 else 0.0
					if kind == "monk":
						unit.visual_action = "heal" if pose == 3 else ""
						unit.conversion_timer = 2.0 if pose >= 4 else 0.0
					if kind == "imperial_official": unit.order = "supervise" if pose >= 4 else "idle"
					if kind == "villager" and pose >= 4:
						unit.visual_action = "build" if pose == 7 else "gather"
						unit.gather_kind = "gold" if pose == 5 else "food" if pose == 6 else "wood"
				if kind == "villager" and pose == 2:
					unit.visual_action = "hunt"
					unit.hunt_windup = 0.1
				unit.paling_timer = float(pose)
				unit.position = Vector2.ZERO
				unit.scale = Vector2.ONE * 2.0
				unit.process_mode = Node.PROCESS_MODE_DISABLED
				context.add_child(unit)
				if context.show_health: unit.hp = unit.max_hp * 0.6
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
