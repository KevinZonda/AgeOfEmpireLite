extends RefCounted

# Rebuilt at each think, discarded afterward. Counts include queued units and
# are adjusted for successful decisions within the same think.
var units: Array[RtsUnit] = []
var unit_counts: Dictionary = {}
var building_counts: Dictionary = {}
var unfinished_counts: Dictionary = {}

func _init(game: Node2D, owner_id: int) -> void:
	for unit in game.units:
		if not is_instance_valid(unit) or unit.owner_id != owner_id: continue
		units.append(unit)
		add_unit(unit.kind)
	for building in game.buildings:
		if not is_instance_valid(building) or building.owner_id != owner_id: continue
		add_building(building)
		for job in building.production_queue:
			if job["type"] == "train": add_unit(job["kind"])

func add_unit(kind: String) -> void:
	unit_counts[kind] = int(unit_counts.get(kind, 0)) + 1

func add_building(building: RtsBuilding) -> void:
	building_counts[building.kind] = int(building_counts.get(building.kind, 0)) + 1
	if not building.is_complete(): unfinished_counts[building.kind] = int(unfinished_counts.get(building.kind, 0)) + 1

func remove_building(building: RtsBuilding) -> void:
	building_counts[building.kind] = maxi(0, int(building_counts.get(building.kind, 0)) - 1)
	if not building.is_complete(): unfinished_counts[building.kind] = maxi(0, int(unfinished_counts.get(building.kind, 0)) - 1)

func unit_count(kind: String) -> int:
	return int(unit_counts.get(kind, 0))

func building_count(kind: String) -> int:
	return int(building_counts.get(kind, 0))

func has_unfinished(kind: String) -> bool:
	return int(unfinished_counts.get(kind, 0)) > 0
