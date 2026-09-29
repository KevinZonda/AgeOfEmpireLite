extends RefCounted

var _controller: WeakRef
var game: Node2D
var owner_id: int

func _init(ai: RefCounted) -> void:
	_controller = weakref(ai)
	game = ai.game
	owner_id = ai.owner_id

func _has_unfinished_house() -> bool:
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "house" and not building.is_complete(): return true
	return false

func _needed_resource(gathering: Dictionary, worker_count: int) -> String:
	var bank: Dictionary = game.players[owner_id]
	var age: int = bank["age"]
	var age_cost: Dictionary = RtsTechTree.age_cost(age)
	var targets := {"food": 0.42, "wood": 0.30, "gold": 0.28, "stone": 0.0}
	if age < RtsTechTree.MAX_AGE and game.match_statistics.elapsed > 90.0:
		targets = {"food": 0.40, "wood": 0.22, "gold": 0.38, "stone": 0.0}
	if int(bank["wood"]) < 180: targets["wood"] += 0.18
	if age >= 3 and game.map_style != "islands" and (_unit_count("battering_ram") == 0 or not _has_building("monastery")) and int(bank["wood"]) < 300: targets["wood"] += 0.30
	if int(bank["food"]) < 160: targets["food"] += 0.18
	if age_cost.has("gold") and int(bank["gold"]) < int(age_cost["gold"]): targets["gold"] += 0.12
	if age >= 3 and game.civilizations[owner_id] == "French" and game.map_style != "islands" and not _has_building("keep") and int(bank["stone"]) < 400: targets["stone"] = 0.23
	var best := "food"
	var best_score := -INF
	for kind in ["food", "wood", "gold", "stone"]:
		var score: float = float(targets[kind]) * float(maxi(worker_count, 3)) - float(gathering[kind])
		if score > best_score:
			best_score = score
			best = kind
	return best

func _expand_production(workers: Array[RtsUnit], army_size: int, age: int) -> void:
	if workers.size() < 13 or age < 3: return
	if game.map_style != "islands" and (not _has_building("siege_workshop") or _unit_count("battering_ram") == 0 or not _has_building("monastery")): return
	var desired := 2 if age == 3 else 3
	if workers.size() < 25: desired = 2
	if army_size < 12: desired = mini(desired, 2)
	var bank: Dictionary = game.players[owner_id]
	if int(bank["wood"]) < 220: return
	for kind in ["barracks", "archery_range", "stable"]:
		if _building_count(kind) < desired and not _has_unfinished_building(kind):
			_construct(kind, workers[0])
			return

func _has_building(kind: String) -> bool:
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == kind: return true
	return false

func _building_count(kind: String) -> int:
	var count := 0
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == kind: count += 1
	return count

func _has_unfinished_building(kind: String) -> bool:
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == kind and not building.is_complete(): return true
	return false

func _unit_count(kind: String) -> int:
	var count := 0
	for unit in game.units:
		if is_instance_valid(unit) and unit.owner_id == owner_id and unit.kind == kind: count += 1
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == owner_id: count += building.queued_unit_count(kind)
	return count

func _balance_market(age: int) -> void:
	if game.find_nearest_owned_building(owner_id, "market", game.spawn_point_for(owner_id)) == null: return
	var bank: Dictionary = game.players[owner_id]
	var age_cost := RtsTechTree.age_cost(age)
	var gold_goal := int(age_cost.get("gold", 180)) + 50
	if bank["food"] > maxi(650, int(age_cost.get("food", 0)) + 150) and bank["gold"] < gold_goal:
		game.exchange_resource(owner_id, "food", false)
	elif bank["food"] < 140 and bank["wood"] >= 200 and bank["gold"] <= game.market_quote("food", true, owner_id) + 120:
		game.exchange_resource(owner_id, "wood", false)
	elif bank["food"] < 140 and bank["gold"] > game.market_quote("food", true, owner_id) + 120:
		game.exchange_resource(owner_id, "food", true)
	elif bank["wood"] < 100 and bank["gold"] > game.market_quote("wood", true, owner_id) + gold_goal:
		game.exchange_resource(owner_id, "wood", true)
	elif bank["wood"] > 600 and bank["gold"] < gold_goal:
		game.exchange_resource(owner_id, "wood", false)

func _resume_construction(workers: Array[RtsUnit]) -> void:
	var controller = _controller.get_ref()
	var construction_watch: Dictionary = controller.construction_watch
	var now: float = game.match_statistics.elapsed
	for building in game.buildings.duplicate():
		if not is_instance_valid(building) or building.owner_id != owner_id or building.is_complete(): continue
		var building_id: int = building.get_instance_id()
		var state: Dictionary = construction_watch.get(building_id, {"remaining": building.build_remaining, "progress_at": now, "created_at": now, "tried": []})
		if building.build_remaining < float(state["remaining"]) - 0.01:
			state["progress_at"] = now
			state["created_at"] = now
			state["tried"] = []
		state["remaining"] = building.build_remaining
		if now - float(state["created_at"]) > 90.0 and building.kind not in ["landmark", "wonder"]:
			for worker in workers:
				if worker.order == "build" and worker.target == building: worker.order_stop()
			for resource in GameData.BUILDINGS[building.kind]["cost"]:
				game.credit_resource(owner_id, resource, int(GameData.BUILDINGS[building.kind]["cost"][resource]))
			game.entity_destroyed(building)
			construction_watch.erase(building_id)
			continue
		if now - float(state["progress_at"]) > 22.0:
			for worker in workers:
				if worker.order == "build" and worker.target == building:
					state["tried"].append(worker.get_instance_id())
					worker.order_stop()
			state["progress_at"] = now
		if game.count_builders(building) == 0:
			var candidates := workers.duplicate()
			candidates.sort_custom(func(a: RtsUnit, b: RtsUnit) -> bool: return a.position.distance_squared_to(building.position) < b.position.distance_squared_to(building.position))
			for worker in candidates:
				if worker.order == "build" or state["tried"].has(worker.get_instance_id()): continue
				if game.navigation.path_to_range(worker.position, building.position, building.size().x * 0.6 + worker.radius(), worker).is_empty(): continue
				worker.order_build(building)
				break
			if game.count_builders(building) == 0: state["tried"] = []
		construction_watch[building_id] = state

func _construction_worker(point: Vector2) -> RtsUnit:
	var candidates: Array[RtsUnit] = []
	for unit in game.units:
		if is_instance_valid(unit) and unit.owner_id == owner_id and unit.kind == "villager" and unit.garrisoned_in == null and unit.order != "build":
			candidates.append(unit)
	candidates.sort_custom(func(a: RtsUnit, b: RtsUnit) -> bool: return a.position.distance_squared_to(point) < b.position.distance_squared_to(point))
	for unit in candidates.slice(0, mini(4, candidates.size())):
		if not game.navigation.path_between(unit.position, point, unit).is_empty(): return unit
	return null

func _construct(kind: String, _worker: RtsUnit) -> void:
	var controller = _controller.get_ref()
	var rng: RandomNumberGenerator = controller.rng
	if not game.can_afford(owner_id, GameData.BUILDINGS[kind]["cost"]): return
	var base: Vector2 = game.spawn_point_for(owner_id)
	if kind == "outpost" and game.civilizations[owner_id] == "English" and game.map_style in ["lakes", "highlands"]:
		var site: Vector2 = game.world_map.sacred_site_positions()[1]
		for fraction in [0.48, 0.40, 0.32]:
			var forward: Vector2 = base.lerp(site, fraction)
			if not game.can_place(kind, forward): continue
			var builder := _construction_worker(forward)
			if builder != null:
				var builders: Array[RtsUnit] = [builder]
				game.place_building(owner_id, kind, forward, builders)
				return
	if kind == "farm":
		for unit in game.units:
			if not is_instance_valid(unit) or unit.owner_id != owner_id or unit.kind != "villager" or unit.order == "build": continue
			for attempt in 10:
				var nearby: Vector2 = unit.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(85.0, 155.0)
				if nearby.distance_to(base) > 490.0 or not game.can_place(kind, nearby): continue
				var approach: Vector2 = nearby + (unit.position - nearby).normalized() * (float(GameData.BUILDINGS[kind]["size"].x) * 0.6 + unit.radius())
				if not game.navigation._segment_clear(unit.position, approach, unit.radius(), unit): continue
				var farm_builders: Array[RtsUnit] = [unit]
				game.place_building(owner_id, kind, nearby, farm_builders)
				return
	for attempt in 24:
		var point := base + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(105, 245) if kind == "farm" else base + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(120, 360)
		if game.can_place(kind, point):
			var worker := _construction_worker(point)
			if worker == null: continue
			var builders: Array[RtsUnit] = [worker]
			game.place_building(owner_id, kind, point, builders)
			return

func _construct_french_keep() -> void:
	var stable: RtsBuilding = game.find_nearest_owned_building(owner_id, "stable", game.spawn_point_for(owner_id))
	if stable == null or not stable.is_complete(): return
	for radius in [125.0, 155.0, 175.0]:
		for step in 16:
			var point: Vector2 = stable.position + Vector2.from_angle(TAU * float(step) / 16.0) * radius
			if not game.can_place("keep", point): continue
			var worker := _construction_worker(point)
			if worker == null: continue
			var builders: Array[RtsUnit] = [worker]
			game.place_building(owner_id, "keep", point, builders)
			return

func _construct_dock(_worker: RtsUnit) -> void:
	var base: Vector2 = game.spawn_point_for(owner_id)
	var scale: float = game.world_size.x / 2400.0
	for distance in range(180, 1320, 35):
		for step in 48:
			var point: Vector2 = base + Vector2.from_angle(TAU * step / 48.0) * float(distance) * scale
			if game.can_place("dock", point):
				var worker := _construction_worker(point)
				if worker == null: continue
				var builders: Array[RtsUnit] = [worker]
				game.place_building(owner_id, "dock", point, builders)
				return
