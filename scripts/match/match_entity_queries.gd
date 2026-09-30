extends RefCounted

# The economy/production view of the live registry. Producers implement the
# queue, completion and cost methods; no scene root or presentation is needed.
var _registry: Object

func _init(registry: Object) -> void:
	_registry = registry

func owned_units(owner_id: int) -> Array:
	return _owned(_registry.units, owner_id)

func owned_buildings(owner_id: int) -> Array:
	return _owned(_registry.buildings, owner_id)

func _owned(collection: Array, owner_id: int) -> Array:
	var result: Array = []
	for entity in collection:
		if is_instance_valid(entity) and not entity.is_queued_for_deletion() and entity.owner_id == owner_id: result.append(entity)
	return result

func has_building(owner_id: int, kind: String, completed_only := false) -> bool:
	for building in owned_buildings(owner_id):
		if building.kind == kind and (not completed_only or building.is_complete()): return true
	return false

func completed_landmark(owner_id: int, landmark_id: String) -> Object:
	for building in owned_buildings(owner_id):
		if building.landmark_id == landmark_id and building.is_complete(): return building
	return null

func active_landmark_id(owner_id: int) -> String:
	for building in owned_buildings(owner_id):
		if building.kind == "landmark" and not building.is_complete(): return building.landmark_id
	return ""

func population_used(owner_id: int) -> int:
	var used := 0
	for unit in owned_units(owner_id): used += RtsBalanceData.population_cost(unit.kind)
	for building in owned_buildings(owner_id): used += building.queued_population_cost()
	return used

func population_cap(owner_id: int) -> int:
	var cap := 0
	for building in owned_buildings(owner_id):
		if building.is_complete(): cap += int(building.definition()["pop"])
	return cap

func queued_research(owner_id: int) -> Array[String]:
	var result: Array[String] = []
	for building in owned_buildings(owner_id):
		for tech_id in building.queued_research_ids():
			if not result.has(tech_id): result.append(tech_id)
	return result

func official_count(owner_id: int) -> int:
	var count := 0
	for unit in owned_units(owner_id):
		if unit.kind == "imperial_official": count += 1
	for building in owned_buildings(owner_id): count += building.queued_unit_count("imperial_official")
	return count

func training_cost_multiplier(civilization: String, producer: Object) -> float:
	return RtsCivilizationRules.training_cost_multiplier(civilization, producer, owned_buildings(producer.owner_id))

func refresh_stats(owner_id: int, include_buildings := false) -> void:
	for unit in owned_units(owner_id): unit.refresh_stats()
	if include_buildings:
		for building in owned_buildings(owner_id): building.refresh_stats()
