extends RefCounted

# Rendering values only: no unit, order, inventory, or game references survive capture.
var kind := ""
var tags: Array = []
var radius := 12.0
var player_color := Color.WHITE
var view_mode_25d := false
var zoom := 1.0
var ground_height := 0.0
var visual_phase := 0.0
var visual_moving := false
var visual_action := ""
var swing := 0.0
var facing_back := false
var facing_right := true
var facing_direction := Vector2(0.70710678, 0.70710678)
var action_progress := 0.0
var action_released := false
var release_elapsed := -1.0
var charging := false
var charge_impact := false
var movement_speed_factor := 1.0
var shield_active := false
var healing := false
var converting := false
var tax_active := false
var passenger_count := 0
var siege_deployed := false
var paling := false
var gather_kind := ""
var fishing_active := false
var fishing_cycle := 0.0
var hunting := false
var hunt_draw := 0.0
var carries_relic := false
var braced := false
var hit_flash_timer := 0.0
var hp := 1.0
var max_hp := 1.0
var show_health_bar := false

static func capture(unit, existing_state = null):
	var result = existing_state if existing_state != null else new()
	result.kind = unit.kind
	# Snapshots are read-only; share the tags array instead of allocating a copy.
	result.tags = unit.stats.get("tags", [])
	result.radius = unit.radius()
	result.player_color = unit.game.player_color(unit.owner_id)
	result.update_view(unit.game)
	result.ground_height = 0.0
	if unit.game.world_map != null: result.ground_height = unit.game.world_map.elevation_at(unit.position)
	result.visual_phase = unit.visual_phase
	result.visual_moving = unit.visual_moving
	result.visual_action = unit.visual_action
	result.facing_back = unit.facing_back
	result.facing_right = unit.facing_right
	var direction: Vector2 = unit.get_viewport().get_canvas_transform().basis_xform(unit.visual_facing_world)
	if direction.is_zero_approx(): direction = Vector2(1.0 if unit.facing_right else -1.0, -1.0 if unit.facing_back else 1.0)
	result.facing_direction = Vector2.RIGHT.rotated(round(direction.angle() / (PI / 4.0)) * (PI / 4.0))
	result.action_progress = clampf(1.0 - unit.visual_action_timer / unit.visual_action_length, 0.0, 1.0) if unit.visual_action_length > 0.0 and unit.visual_action_timer > 0.0 else 0.0
	result.action_released = unit.visual_action_released
	result.release_elapsed = unit.visual_release_elapsed
	result.charging = unit.charging
	result.charge_impact = unit.visual_charge_impact
	result.movement_speed_factor = clampf(unit.effective_speed() / 130.0, 0.5, 1.8)
	result.shield_active = unit.shield_timer > 0.0
	result.healing = unit.kind == "monk" and unit.visual_action == "heal"
	result.converting = unit.kind == "monk" and unit.conversion_timer > 0.0
	result.tax_active = unit.kind == "imperial_official" and (unit.order in ["supervise", "collect_tax"] or unit.visual_action == "tax")
	result.gather_kind = unit.gather_kind
	result.fishing_active = unit.kind == "fishing_boat" and unit.order == "gather" and not unit.visual_moving and is_instance_valid(unit.target) and not unit.target.is_queued_for_deletion() and unit.target is RtsResource and unit.target.appearance == "fish" and unit.target.amount > 0 and unit.position.distance_to(unit.target.position) <= unit.radius() + unit.target.radius + 2.5
	result.fishing_cycle = clampf(1.0 - unit.work_timer / 1.1, 0.0, 1.0) if result.fishing_active else 0.0
	if result.fishing_active:
		# Work side-on to the fish: the deployed net hangs from starboard.
		# This is a rendering pose; the navigation heading remains unchanged.
		var fishing_heading: Vector2 = unit.get_viewport().get_canvas_transform().basis_xform((unit.target.position - unit.position).rotated(-PI * 0.5))
		if not fishing_heading.is_zero_approx():
			result.facing_direction = Vector2.RIGHT.rotated(round(fishing_heading.angle() / (PI / 4.0)) * (PI / 4.0))
	result.hunting = unit.kind == "villager" and (unit.visual_action == "hunt" or unit.order == "gather" and is_instance_valid(unit.target) and unit.target is RtsResource and unit.target.appearance == "deer" and unit.target.wildlife_hp > 0.0)
	result.hunt_draw = clampf(1.0 - unit.hunt_windup / unit.UnitWork.HUNT_WINDUP, 0.0, 1.0) if unit.hunt_windup >= 0.0 else 0.0
	# The hit flash is a self_modulate tint on the unit; no redraw-time ring.
	result.hit_flash_timer = 0.0
	result.hp = unit.hp
	result.max_hp = unit.max_hp
	result.swing = unit._action_swing()
	result.passenger_count = unit.passengers.size()
	result.siege_deployed = unit.kind == "siege_tower" and unit.order == "siege_tower_docked"
	result.paling = unit.paling_timer > 0.0
	result.carries_relic = unit.carried_relic != null
	result.braced = unit.is_braced() if unit.kind == "spearman" else false
	result.show_health_bar = unit.game.has_method("should_show_health_bar") and unit.game.should_show_health_bar(unit.hp, unit.max_hp, unit.health_bar_timer)
	return result

static func preview(unit_kind: String, definition: Dictionary, color: Color):
	var result = new()
	result.kind = unit_kind
	result.tags = definition.get("tags", []).duplicate()
	result.radius = float(definition.get("radius", 12.0))
	result.player_color = color
	result.max_hp = float(definition.get("hp", 1.0))
	result.hp = result.max_hp
	result.movement_speed_factor = clampf(float(definition.get("speed", 130.0)) / 130.0, 0.5, 1.8)
	return result

func update_view(context: Node2D) -> void:
	view_mode_25d = context.view_mode_25d
	zoom = context.camera.zoom.x
