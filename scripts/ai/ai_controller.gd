class_name RtsAiController
extends RefCounted

const Snapshot = preload("res://scripts/ai/ai_snapshot.gd")
const Profile = preload("res://scripts/ai/ai_profile.gd")
const EconomyPlan = preload("res://scripts/ai/economy_plan.gd")
var snapshot: Snapshot
const TACTICS_SCRIPT = preload("res://scripts/ai/ai_tactics.gd")
const ECONOMY_SCRIPT = preload("res://scripts/ai/ai_economy.gd")
const IDLE_ASSIGNMENTS_PER_THINK := 4

var game: Node2D
var owner_id := 1
var difficulty := "normal"
var transport_wait: Dictionary = {}
var construction_watch: Dictionary = {}
var rng := RandomNumberGenerator.new()
var last_tactic := ""
var tactic_cooldown := 0.0
var push_cooldown := 0.0
var site_cooldown := 0.0
var attack_watch: Dictionary = {}
var think_phase := 0.0
var _think_phase_pending := false
var _idle_worker_cursor := 0
var _tactics: RefCounted
var _economy: RefCounted

func _init(game_ref: Node2D, player_id := 1, chosen_difficulty := "normal") -> void:
	game = game_ref
	owner_id = player_id
	difficulty = chosen_difficulty if chosen_difficulty in ["easy", "normal", "hard"] else "normal"
	rng.seed = int(game.map_seed) + player_id * 104729
	_tactics = TACTICS_SCRIPT.new(self)
	_economy = ECONOMY_SCRIPT.new(self)

func worker_goal() -> int:
	var age: int = game.players[owner_id]["age"] if game.players.size() > owner_id else 1
	return Profile.for_difficulty(difficulty)["workers"][clampi(age - 1, 0, 3)]

func attack_threshold() -> int:
	return int(Profile.for_difficulty(difficulty)["attack_threshold"])

func think_interval() -> float:
	return float(Profile.for_difficulty(difficulty)["interval"])

# The phase shifts this controller's steady-state think times away from other
# AIs sharing the same interval. It is consumed once; afterwards the period is
# exactly the interval again.
func next_think_delay() -> float:
	var delay := think_interval()
	if _think_phase_pending:
		_think_phase_pending = false
		delay += think_phase
	return delay

func _has_unfinished_house() -> bool:
	return _economy._has_unfinished_house()

func tick() -> void:
	snapshot = Snapshot.new(game, owner_id)
	_think()
	snapshot = null

func _think() -> void:
	tactic_cooldown = maxf(0.0, tactic_cooldown - think_interval())
	push_cooldown = maxf(0.0, push_cooldown - think_interval())
	site_cooldown = maxf(0.0, site_cooldown - think_interval())
	var workers: Array[RtsUnit] = []
	var army: Array[RtsUnit] = []
	var economic_explorers := 0
	for unit in snapshot.units:
		if not is_instance_valid(unit) or unit.garrisoned_in != null: continue
		if unit.kind == "villager":
			workers.append(unit)
			if unit.order == "move": economic_explorers += 1
		elif unit.kind == "scout":
			if unit.order == "idle": _assign_scout(unit)
		elif unit.kind == "transport_ship":
			if unit.order == "idle": _assign_transport(unit)
		elif unit.kind == "warship":
			if unit.order == "idle":
				var target: Node2D = game.nearest_enemy(unit, 350.0)
				if target != null: unit.order_attack(target)
		elif unit.stats.get("tags", []).has("military"): army.append(unit)
		elif unit.kind == "trader":
			if game.civilizations[owner_id] == "French": unit.trade_resource_kind = _french_trade_resource()
			if unit.order == "idle" and not game.trade_posts.is_empty():
				var post: RtsTradePost = _reachable_trade_post(unit)
				if post != null: unit.issue_command("trade", Vector2.INF, post)
		elif unit.kind == "imperial_official" and unit.order == "idle": _assign_official(unit)
		elif unit.kind == "fishing_boat" and unit.order == "idle":
			var fish: RtsResource = game.find_nearest_resource(unit.position, "food", INF, owner_id, true)
			if fish != null: unit.issue_command("gather", Vector2.INF, fish)
		elif unit.kind == "monk" and unit.order == "idle": _assign_monk(unit)
	_resume_construction(workers)
	# The snapshot from tick() stays valid through both halves of the think;
	# _resume_construction keeps it in sync when it retires a stalled building.
	var gathering := {"food": 0, "wood": 0, "gold": 0, "stone": 0}
	for worker in workers:
		if worker.order == "gather" and is_instance_valid(worker.target):
			var gathered_kind: String = "food" if worker.target is RtsBuilding else worker.target.kind
			if gathering.has(gathered_kind): gathering[gathered_kind] += 1
	for worker in workers:
		if worker.order == "gather" and is_instance_valid(worker.target):
			var reach: float = worker.target.radius + worker.radius() + 2.0 if worker.target is RtsResource else worker.target.size().x * 0.5 + worker.radius() + 2.0
			if worker.position.distance_to(worker.target.position) > reach + 5.0 and worker.route.is_empty(): worker.order_stop()
	# Idle assignment pathfinds per candidate resource; spread it over several
	# thinks so a large idle burst cannot turn one think into a long frame.
	var idle_workers: Array[RtsUnit] = []
	for worker in workers:
		if worker.order == "idle": idle_workers.append(worker)
	if idle_workers.is_empty():
		_idle_worker_cursor = 0
	else:
		var start := _idle_worker_cursor % idle_workers.size()
		var assignments: int = mini(IDLE_ASSIGNMENTS_PER_THINK, idle_workers.size())
		for offset in assignments:
			economic_explorers += _assign_idle_worker(idle_workers[(start + offset) % idle_workers.size()], workers, gathering, economic_explorers)
		_idle_worker_cursor = (start + assignments) % idle_workers.size()
	if game.players[owner_id]["age"] == 1:
		if game._player_center(owner_id) != null: game.advance_age(owner_id, RtsLandmarkCatalog.preferred_landmark(game.civilizations[owner_id], 1, game.map_style))
		if army.is_empty(): return
	var center: RtsBuilding = game._player_center(owner_id)
	var age: int = game.players[owner_id]["age"]
	var plan := EconomyPlan.new(age, game.map_style, _unit_count("battering_ram"), _has_building("monastery"))
	if center != null and not workers.is_empty() and age < RtsTechTree.MAX_AGE and not game.is_age_queued(owner_id):
		var timing: float = float(Profile.for_difficulty(difficulty)["age_timing"])
		var should_advance: bool = game.highest_enemy_age(owner_id) > age or army.size() >= attack_threshold() + 2 or game.match_statistics.elapsed >= timing * float(age - 1)
		if should_advance and game.can_afford(owner_id, RtsTechTree.age_cost(age)):
			game.advance_age(owner_id, RtsLandmarkCatalog.preferred_landmark(game.civilizations[owner_id], age, game.map_style))
	if game.civilizations[owner_id] == "Chinese" and not game.is_age_queued(owner_id):
		for choice in RtsLandmarkCatalog.choices_for("Chinese", age, game.players[owner_id]["landmarks"]):
			if choice["age"] > age or not game.can_afford(owner_id, choice["cost"]): continue
			if game.construct_landmark(owner_id, choice["id"]): break
	if center != null and _unit_count("villager") < worker_goal(): _train_unit(center, "villager")
	if center != null and game.civilizations[owner_id] == "Chinese" and age >= 2 and _unit_count("imperial_official") < (2 if age >= 3 else 1) and not plan.reserving_strategic_wood:
		_train_unit(center, "imperial_official")
	if not workers.is_empty() and game.population_cap(owner_id) - game.population_used(owner_id) <= 4 and not _has_unfinished_house():
		_construct("house", workers[0])
	if not workers.is_empty() and age >= 2 and not plan.reserving_strategic_wood and game.players[owner_id]["food"] < 450 and _building_count("farm") < mini(12, maxi(2, workers.size() / 3)) and not _has_unfinished_building("farm"):
		_construct("farm", workers[0])
	if not workers.is_empty() and not plan.reserving_strategic_wood:
		for kind in _production_order():
			if not _has_building(kind):
				_construct(kind, workers[0])
				break
	if not workers.is_empty() and age >= 3 and game.civilizations[owner_id] == "French" and game.map_style != "islands" and not _has_building("keep") and game.can_afford(owner_id, GameData.BUILDINGS["keep"]["cost"]):
		_economy._construct_french_keep()
	if not workers.is_empty() and plan.wants_siege and not _has_building("siege_workshop") and game.can_afford(owner_id, GameData.BUILDINGS["siege_workshop"]["cost"]):
		_construct("siege_workshop", workers[0])
	_expand_production(workers, army.size(), age)
	if not workers.is_empty() and not plan.reserving_strategic_wood and age >= 2 and not _has_building("outpost") and game.can_afford(owner_id, GameData.BUILDINGS["outpost"]["cost"]):
		_construct("outpost", workers[0])
	if not workers.is_empty() and not plan.reserving_strategic_wood and age >= 2 and not _has_building("market") and game.can_afford(owner_id, GameData.BUILDINGS["market"]["cost"]):
		_construct("market", workers[0])
	if not workers.is_empty() and age >= 2 and game.map_style == "islands" and not _has_building("dock") and game.can_afford(owner_id, GameData.BUILDINGS["dock"]["cost"]):
		_construct_dock(workers[0])
	if not workers.is_empty() and plan.wants_monastery and game.can_afford(owner_id, GameData.BUILDINGS["monastery"]["cost"]):
		_construct("monastery", workers[0])
	_balance_market(age)
	plan.update_age_saving(age, game.is_age_queued(owner_id), game.match_statistics.elapsed, float(Profile.for_difficulty(difficulty)["age_timing"]), game.highest_enemy_age(owner_id))
	var enemy_profile := _enemy_profile()
	for building in game.buildings:
		if not is_instance_valid(building) or building.owner_id != owner_id or not building.is_complete(): continue
		if building.landmark_id == "fr_guild_hall" and int(building.landmark_stockpile.get("gold", 0)) >= 120: building.collect_stockpile()
		if building.landmark_id == "zh_imperial_palace" and building.landmark_ability_cooldown <= 0.0: building.activate_landmark_ability()
		if building.production_queue.size() >= int(Profile.for_difficulty(difficulty)["queue_limit"]): continue
		if not plan.allows_production(building.producer_kind(), game.match_statistics.elapsed): continue
		if plan.allows_research():
			for tech_id in RtsTechTree.all_researches(game.civilizations[owner_id], building.producer_kind()):
				if RtsTechTree.can_research(game.civilizations[owner_id], age, building.producer_kind(), tech_id, game.players[owner_id]["researched"]):
					if game.research_technology(building, tech_id): break
		if building.producer_kind() == "barracks":
			var infantry_kind := "spearman" if enemy_profile["cavalry"] >= enemy_profile["ranged"] or age < 3 else "man_at_arms"
			_train_unit(building, RtsUnitCatalog.replacement_for(game.civilizations[owner_id], infantry_kind))
		if building.producer_kind() == "archery_range":
			var ranged_kind := RtsUnitCatalog.replacement_for(game.civilizations[owner_id], "crossbowman")
			if age < 3 or enemy_profile["heavy"] == 0: ranged_kind = RtsUnitCatalog.replacement_for(game.civilizations[owner_id], "archer")
			if game.civilizations[owner_id] == "Chinese" and game.players[owner_id].get("dynasty", "") in ["Song", "Yuan", "Ming"] and enemy_profile["heavy"] == 0: ranged_kind = "zhuge_nu"
			_train_unit(building, ranged_kind)
		if building.producer_kind() == "stable":
			var cavalry_kind := "horseman"
			if enemy_profile["ranged"] == 0 and not plan.saving_for_age:
				if game.civilizations[owner_id] == "French": cavalry_kind = "royal_knight"
				elif age >= 3: cavalry_kind = "knight"
			_train_unit(building, cavalry_kind)
		if building.producer_kind() == "siege_workshop" and _unit_count("battering_ram") < (1 if age == 3 else 2) and game.can_afford(owner_id, GameData.unit_cost("battering_ram")):
			_train_unit(building, "battering_ram")
		if building.producer_kind() == "white_tower":
			_train_unit(building, "spearman" if enemy_profile["cavalry"] > 0 else "longbow")
		if building.producer_kind() == "wynguard": _train_unit(building, "longbow")
		if building.producer_kind() == "town_center" and building != center and _unit_count("villager") < worker_goal(): _train_unit(building, "villager")
		if building.producer_kind() == "market" and _unit_count("trader") < 1:
			_train_unit(building, "trader")
		if building.kind == "dock" and _unit_count("fishing_boat") < 2:
			_train_unit(building, "fishing_boat")
		if building.kind == "dock" and _unit_count("fishing_boat") >= 1 and _unit_count("warship") < 1:
			_train_unit(building, "warship")
		if building.kind == "dock" and _unit_count("arrow_ship") < 2:
			_train_unit(building, "arrow_ship")
		if building.kind == "dock" and game.map_style == "islands" and _unit_count("transport_ship") < 1:
			_train_unit(building, "transport_ship")
		if building.kind == "monastery" and _unit_count("monk") < 3:
			_train_unit(building, "monk")
	_recover_stalled_attacks(army)
	if _tactical_orders(army): return
	_secure_sacred_site(army)
	_tactics.push(army, center, age)

func _production_order() -> Array[String]:
	if game.map_style == "islands": return ["archery_range", "barracks", "stable", "blacksmith"]
	match game.civilizations[owner_id]:
		"English": return ["archery_range", "barracks", "stable", "blacksmith"]
		"French":
			return ["archery_range", "stable", "barracks", "blacksmith"] if game.map_style in ["lakes", "highlands"] else ["stable", "archery_range", "barracks", "blacksmith"]
		"Chinese": return ["barracks", "archery_range", "stable", "blacksmith"] if game.map_style == "highlands" else ["archery_range", "barracks", "stable", "blacksmith"]
	return ["barracks", "archery_range", "stable", "blacksmith"]

# Returns 1 when the worker was sent exploring so the caller can cap explorers.
func _assign_idle_worker(worker: RtsUnit, workers: Array[RtsUnit], gathering: Dictionary, economic_explorers: int) -> int:
	var resource_kind := _needed_resource(gathering, workers.size())
	var resource: RtsResource = game.find_nearest_resource(worker.position, resource_kind, INF, owner_id, false, worker)
	if resource == null:
		for fallback in ["wood", "food", "gold"]:
			if fallback == resource_kind: continue
			resource = game.find_nearest_resource(worker.position, fallback, INF, owner_id, false, worker)
			if resource != null:
				resource_kind = fallback
				break
	if resource != null:
		worker.order_gather(resource)
		gathering[resource_kind] += 1
	elif resource_kind == "food":
		var farm: RtsBuilding = game.find_nearest_free_farm(owner_id, worker.position, 520.0, worker)
		if farm != null:
			worker.order_gather(farm)
			gathering["food"] += 1
	if worker.order == "idle" and economic_explorers < 2 and _explore_for_resources(worker, workers): return 1
	return 0

func _assign_official(official: RtsUnit) -> void:
	for other in game.units:
		if is_instance_valid(other) and other != official and other.owner_id == owner_id and other.kind == "imperial_official" and other.order == "supervise": return
	for building in game.buildings:
		if not is_instance_valid(building) or building.owner_id != owner_id or not building.is_complete() or building.production_queue.is_empty(): continue
		if building.producer_kind() not in ["town_center", "archery_range", "stable", "barracks", "siege_workshop"]: continue
		if game.navigation.path_to_range(official.position, building.position, building.supervise_distance(official), official).is_empty(): continue
		official.issue_command("supervise", Vector2.INF, building)
		return

func _reachable_trade_post(trader: RtsUnit) -> RtsTradePost:
	var best: RtsTradePost
	var best_distance := INF
	for post in game.trade_posts:
		if not is_instance_valid(post): continue
		var distance := trader.position.distance_squared_to(post.position)
		if distance >= best_distance or game.navigation.path_to_range(trader.position, post.position, 46.0, trader).is_empty(): continue
		best = post
		best_distance = distance
	return best

func _french_trade_resource() -> String:
	var bank: Dictionary = game.players[owner_id]
	if int(bank["wood"]) < 180: return "wood"
	if int(bank["food"]) < 160: return "food"
	return "gold"

func _assign_scout(scout: RtsUnit) -> void:
	var center: RtsBuilding = game.find_nearest_owned_building(owner_id, "town_center", scout.position)
	for sheep in game.resources:
		if is_instance_valid(sheep) and sheep.appearance == "sheep" and sheep.shepherd == scout and center != null and sheep.position.distance_to(center.position) > 120.0:
			scout.issue_command("move", center.position)
			return
	var nearest_sheep: RtsResource
	var sheep_distance := 800.0 * 800.0
	for sheep in game.resources:
		if not is_instance_valid(sheep) or sheep.appearance != "sheep" or sheep.claimed_by == owner_id or not game.fog.can_see(owner_id, sheep.position): continue
		var distance := scout.position.distance_squared_to(sheep.position)
		if distance < sheep_distance and not game.navigation.path_between(scout.position, sheep.position, scout).is_empty():
			nearest_sheep = sheep
			sheep_distance = distance
	if nearest_sheep != null:
		scout.issue_command("move", nearest_sheep.position)
		return
	var candidates: Array[Dictionary] = []
	for y in range(1, game.world_map.grid_size.y - 1, 4):
		for x in range(1, game.world_map.grid_size.x - 1, 4):
			var point: Vector2 = game.world_map.cell_center(Vector2i(x, y))
			if not game.world_map.is_walkable(point) or game.fog.is_explored(owner_id, point): continue
			var distance := scout.position.distance_squared_to(point)
			if distance > 180.0 * 180.0:
				var exploration_score := point.distance_squared_to(game.world_size * 0.5) + distance * 0.2
				candidates.append({"point": point, "distance": exploration_score})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	for candidate in candidates.slice(0, mini(24, candidates.size())):
		if not game.navigation.path_between(scout.position, candidate["point"], scout).is_empty():
			scout.issue_command("move", candidate["point"])
			return

func _explore_for_resources(worker: RtsUnit, workers: Array[RtsUnit]) -> bool:
	var base: Vector2 = game.spawn_point_for(owner_id)
	var candidates: Array[Dictionary] = []
	for y in range(1, game.world_map.grid_size.y - 1, 4):
		for x in range(1, game.world_map.grid_size.x - 1, 4):
			var point: Vector2 = game.world_map.cell_center(Vector2i(x, y))
			if not game.world_map.is_walkable(point) or game.fog.is_explored(owner_id, point): continue
			var home_distance := point.distance_to(base)
			if home_distance < 350.0 or home_distance > 1250.0: continue
			var reserved := false
			for ally in workers:
				if ally != worker and ally.order == "move" and ally.destination.distance_to(point) < 230.0:
					reserved = true
					break
			if reserved: continue
			var distance := worker.position.distance_squared_to(point)
			var exploration_score := point.distance_squared_to(game.world_size * 0.5) + distance * 0.2
			candidates.append({"point": point, "distance": exploration_score})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	for candidate in candidates:
		if game.navigation.path_between(worker.position, candidate["point"], worker).is_empty(): continue
		worker.order_move(candidate["point"])
		return true
	return false

func _assign_transport(boat: RtsUnit) -> void:
	if not boat.passengers.is_empty():
		var waiting := 0
		for soldier in game.units:
			if is_instance_valid(soldier) and soldier.order == "board_transport" and soldier.target == boat: waiting += 1
		var boat_id := boat.get_instance_id()
		if waiting > 0 and boat.passengers.size() < 4:
			transport_wait[boat_id] = int(transport_wait.get(boat_id, 0)) + 1
			if int(transport_wait[boat_id]) < 5: return
		transport_wait.erase(boat_id)
		var target: Node2D = game.strategic_target_for(owner_id)
		var landing: Vector2 = target.position if target != null else game.world_size * 0.5
		for passenger in boat.passengers:
			if is_instance_valid(passenger) and passenger.kind == "monk":
				landing = game.objectives.sacred_sites[1]["position"]
				break
		boat.issue_command("unload", landing)
		return
	if game.map_style != "islands": return
	var boarded := 0
	for monk in game.units:
		if not is_instance_valid(monk) or monk.owner_id != owner_id or monk.kind != "monk" or monk.garrisoned_in != null or monk.order != "idle" or monk.position.distance_to(boat.position) > 700.0: continue
		if not _can_reach_boat(monk, boat): continue
		monk.issue_command("board_transport", Vector2.INF, boat)
		boarded += 1
	for soldier in game.units:
		if not is_instance_valid(soldier) or soldier.owner_id != owner_id or soldier.garrisoned_in != null or soldier.kind == "scout" or not soldier.stats.get("tags", []).has("military") or soldier.stats.get("tags", []).has("naval"): continue
		if soldier.position.distance_to(boat.position) > 700.0: continue
		if not _can_reach_boat(soldier, boat): continue
		soldier.issue_command("board_transport", Vector2.INF, boat)
		boarded += 1
		if boarded >= 6: break
	if boarded == 0:
		var home_shore: Dictionary = game.find_landing_pair(boat, game.spawn_point_for(owner_id))
		if not home_shore.is_empty() and boat.position.distance_to(home_shore["water"]) > 25.0: boat.order_move(home_shore["water"])

func _can_reach_boat(unit: RtsUnit, boat: RtsUnit) -> bool:
	var origin: Vector2i = game.world_map.cell_at(boat.position)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var cell := origin + Vector2i(dx, dy)
			if cell.x < 0 or cell.y < 0 or cell.x >= game.world_map.grid_size.x or cell.y >= game.world_map.grid_size.y: continue
			var shore: Vector2 = game.world_map.cell_center(cell)
			if not game.world_map.is_walkable(shore) or shore.distance_to(boat.position) > 95.0: continue
			if not game.world_map.path_between(unit.position, shore).is_empty(): return true
	return false

func _enemy_profile() -> Dictionary:
	var profile := {"cavalry": 0, "ranged": 0, "heavy": 0}
	for unit in game.units:
		if not is_instance_valid(unit) or not game.is_enemy(owner_id, unit.owner_id) or unit.kind == "villager": continue
		if game.fog.active and not game.fog.can_detect_unit(owner_id, unit): continue
		for tag in profile:
			if unit.stats.get("tags", []).has(tag): profile[tag] += 1
	return profile

func _needed_resource(gathering: Dictionary, worker_count: int) -> String:
	return _economy._needed_resource(gathering, worker_count)

func _expand_production(workers: Array[RtsUnit], army_size: int, age: int) -> void:
	_economy._expand_production(workers, army_size, age)

func _secure_sacred_site(army: Array[RtsUnit]) -> void:
	_tactics._secure_sacred_site(army)

func _recover_stalled_attacks(army: Array[RtsUnit]) -> void:
	_tactics._recover_stalled_attacks(army)

func _tactical_orders(army: Array[RtsUnit]) -> bool:
	return _tactics._tactical_orders(army)

func _has_building(kind: String) -> bool:
	return _economy._has_building(kind)

func _building_count(kind: String) -> int:
	return _economy._building_count(kind)

func _has_unfinished_building(kind: String) -> bool:
	return _economy._has_unfinished_building(kind)

func _unit_count(kind: String) -> int:
	return _economy._unit_count(kind)

func _balance_market(age: int) -> void:
	_economy._balance_market(age)

func _assign_monk(monk: RtsUnit) -> void:
	if monk.carried_relic != null:
		var monastery: RtsBuilding = game.find_nearest_owned_building(owner_id, "monastery", monk.position)
		if monastery != null: monk.issue_command("deposit_relic", Vector2.INF, monastery)
		return
	var site_index := _sacred_site_for(monk)
	if site_index >= 0:
		monk.issue_command("move", game.objectives.sacred_sites[site_index]["position"])
		return
	for relic in game.relics:
		if is_instance_valid(relic) and relic.available() and monk.position.distance_to(relic.position) < 460.0 and not game.navigation.path_to_range(monk.position, relic.position, 20.0 + monk.radius(), monk).is_empty():
			monk.issue_command("relic", Vector2.INF, relic)
			return

func _sacred_site_for(monk: RtsUnit) -> int:
	var best_index := -1
	var best_score := INF
	for index in game.objectives.sacred_sites.size():
		var site: Dictionary = game.objectives.sacred_sites[index]
		if site["owner_id"] >= 0 and not game.is_enemy(owner_id, site["owner_id"]): continue
		if game.navigation.path_between(monk.position, site["position"], monk).is_empty(): continue
		var reservations := 0
		for ally in game.units:
			if not is_instance_valid(ally) or ally == monk or ally.owner_id != owner_id or ally.kind != "monk" or ally.order != "move": continue
			if ally.destination.distance_to(site["position"]) < 80.0: reservations += 1
		var score: float = monk.position.distance_to(site["position"]) + reservations * 520.0
		if index == 1: score += 250.0
		if owner_id % 2 == 0 and index == 2 or owner_id % 2 == 1 and index == 0: score += 180.0
		if score < best_score:
			best_score = score
			best_index = index
	return best_index

func _resume_construction(workers: Array[RtsUnit]) -> void:
	_economy._resume_construction(workers)

func _construct(kind: String, _worker: RtsUnit) -> void:
	_economy._construct(kind, _worker)

func _construct_dock(_worker: RtsUnit) -> void:
	_economy._construct_dock(_worker)

func _train_unit(building: RtsBuilding, kind: String) -> bool:
	var trained: bool = game.train_unit(building, kind)
	if trained and snapshot != null: snapshot.add_unit(kind)
	return trained
