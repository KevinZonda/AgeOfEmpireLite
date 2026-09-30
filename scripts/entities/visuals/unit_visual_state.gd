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
var passenger_count := 0
var paling := false
var gather_kind := ""
var carries_relic := false
var braced := false
var hit_flash_timer := 0.0
var hp := 1.0
var max_hp := 1.0
var show_health_bar := false

static func capture(unit):
	var result = new()
	result.kind = unit.kind
	result.tags = unit.stats.get("tags", []).duplicate()
	result.radius = unit.radius()
	result.player_color = unit.game.player_color(unit.owner_id)
	result.update_view(unit.game)
	if unit.game.world_map != null: result.ground_height = unit.game.world_map.elevation_at(unit.position)
	for field in ["visual_phase", "visual_moving", "visual_action", "facing_back", "facing_right", "gather_kind", "hit_flash_timer", "hp", "max_hp"]:
		result.set(field, unit.get(field))
	result.swing = unit._action_swing()
	result.passenger_count = unit.passengers.size()
	result.paling = unit.paling_timer > 0.0
	result.carries_relic = unit.carried_relic != null
	result.braced = unit.is_braced() if unit.kind == "spearman" else false
	result.show_health_bar = unit.game.should_show_health_bar(unit.hp, unit.max_hp, unit.health_bar_timer)
	return result

static func preview(unit_kind: String, definition: Dictionary, color: Color):
	var result = new()
	result.kind = unit_kind
	result.tags = definition.get("tags", []).duplicate()
	result.radius = float(definition.get("radius", 12.0))
	result.player_color = color
	result.max_hp = float(definition.get("hp", 1.0))
	result.hp = result.max_hp
	return result

func update_view(context: Node2D) -> void:
	view_mode_25d = context.view_mode_25d
	zoom = context.camera.zoom.x
