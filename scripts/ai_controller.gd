class_name RtsAiController
extends RefCounted

var game: Node2D

func _init(game_ref: Node2D) -> void:
	game = game_ref

func tick() -> void:
	var workers: Array[RtsUnit] = []
	var army: Array[RtsUnit] = []
	for unit in game.units:
		if not is_instance_valid(unit) or unit.owner_id != 1: continue
		if unit.kind == "villager": workers.append(unit)
		else: army.append(unit)
	for worker in workers:
		if worker.order == "idle":
			var resource_kind := "food" if game.players[1]["food"] < 330 else "wood" if game.players[1]["wood"] < 230 else "gold"
			var resource: RtsResource = game.find_nearest_resource(worker.position, resource_kind)
			if resource != null: worker.order_gather(resource)
	if game.players[1]["age"] == 1:
		game.advance_age(1)
		return
	var center: RtsBuilding = game._player_center(1)
	if center == null or workers.is_empty(): return
	if workers.size() < 8: game.train_unit(center, "villager")
	if game.population_cap(1) - game.population_used(1) <= 3 and not _has_building("house"):
		_construct("house", workers[0])
	if not _has_building("barracks"):
		_construct("barracks", workers[0])
	elif not _has_building("archery_range"):
		_construct("archery_range", workers[0])
	elif not _has_building("stable"):
		_construct("stable", workers[0])
	for building in game.buildings:
		if not is_instance_valid(building) or building.owner_id != 1 or not building.is_complete(): continue
		if building.kind == "barracks": game.train_unit(building, "spearman")
		if building.kind == "archery_range": game.train_unit(building, "longbow" if game.civilizations[1] == "English" else "archer")
		if building.kind == "stable": game.train_unit(building, "knight" if game.civilizations[1] == "French" else "horseman")
	if army.size() >= 4:
		var enemy_center: RtsBuilding = game._player_center(0)
		if enemy_center != null:
			for soldier in army:
				if soldier.order == "idle": soldier.order_attack(enemy_center)

func _has_building(kind: String) -> bool:
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == 1 and building.kind == kind: return true
	return false

func _construct(kind: String, worker: RtsUnit) -> void:
	if worker.order == "build" or not game.can_afford(1, GameData.BUILDINGS[kind]["cost"]): return
	var base := Vector2(2070, 720)
	for attempt in 24:
		var point := base + Vector2(-randf_range(90, 380), randf_range(-300, 300))
		if game.can_place(kind, point):
			game.place_building(1, kind, point, worker)
			return
