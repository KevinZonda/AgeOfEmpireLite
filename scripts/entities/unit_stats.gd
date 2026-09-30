extends RefCounted

# Resolve a fresh base before applying temporary effects once. Compatibility
# fields are projected only after all profile mutations have finished.
static func refresh(unit: RtsUnit, preserve_damage: bool) -> void:
	var missing_hp := maxf(0.0, unit.max_hp - unit.hp) if preserve_damage else 0.0
	var player: Dictionary = unit.game.players[unit.owner_id]
	var resolved := RtsUnitCatalog.unit_definition(unit.game.civilizations[unit.owner_id], unit.kind,
		player.get("researched", []), player.get("age", 1), player.get("landmarks", []),
		player.get("dynasty", ""), unit.producer_landmark_id)
	if unit.abilities.shield_timer > 0.0:
		resolved["armor"]["ranged"] = float(resolved["armor"].get("ranged", 0.0)) + 5.0
		for profile in resolved.get("profiles", {}).values():
			profile["range"] = float(profile.get("range", 0.0)) + 30.0
	if is_instance_valid(unit.wall_host): resolved["armor"]["ranged"] = float(resolved["armor"].get("ranged", 0.0)) + 2.0
	RtsStatResolver.project_legacy_primary(resolved)
	unit.stats = resolved
	unit.max_hp = float(resolved["hp"])
	unit.hp = maxf(1.0, unit.max_hp - missing_hp)
	unit.queue_redraw()
