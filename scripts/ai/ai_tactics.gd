class_name RtsAiTactics
extends RefCounted

var _controller: WeakRef
var game: Node2D
var owner_id: int

func _init(ai: RefCounted) -> void:
	_controller = weakref(ai)
	game = ai.game
	owner_id = ai.owner_id

func _visible_enemy_units() -> Array[RtsUnit]:
	var enemies: Array[RtsUnit] = []
	for unit in game.units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.garrisoned_in != null or not game.is_enemy(owner_id, unit.owner_id): continue
		if game.fog.active and not game.fog.can_detect_unit(owner_id, unit): continue
		enemies.append(unit)
	return enemies

func _secure_sacred_site(army: Array[RtsUnit]) -> void:
	var controller = _controller.get_ref()
	if controller.site_cooldown > 0.0 or army.size() < controller.attack_threshold() + 3: return
	var best_site := -1
	var best_score := INF
	for index in game.objectives.sacred_sites.size():
		var site: Dictionary = game.objectives.sacred_sites[index]
		var needs_help: bool = site["contested"]
		if not needs_help and site["owner_id"] >= 0 and game.is_enemy(owner_id, site["owner_id"]):
			for unit in game.units:
				if not is_instance_valid(unit) or unit.owner_id != owner_id or unit.kind != "monk": continue
				if unit.position.distance_to(site["position"]) < 450.0 or unit.order == "move" and unit.destination.distance_to(site["position"]) < 80.0:
					needs_help = true
					break
		if not needs_help: continue
		var score: float = game.spawn_point_for(owner_id).distance_to(site["position"]) + (0.0 if site["contested"] else 250.0)
		if score < best_score:
			best_score = score
			best_site = index
	if best_site < 0: return
	var point: Vector2 = game.objectives.sacred_sites[best_site]["position"]
	var guards: Array[RtsUnit] = []
	var candidates := army.duplicate()
	candidates.sort_custom(func(a: RtsUnit, b: RtsUnit) -> bool: return a.position.distance_squared_to(point) < b.position.distance_squared_to(point))
	for soldier in candidates:
		if soldier.stats.get("tags", []).has("siege") or soldier.hp < soldier.max_hp * 0.45 or game.navigation.path_between(soldier.position, point, soldier).is_empty(): continue
		guards.append(soldier)
		if guards.size() >= 10: break
	if guards.size() < 4: return
	game.issue_group_order(guards, point, true)
	controller.last_tactic = "secure_site"
	controller.site_cooldown = 16.0

func _recover_stalled_attacks(army: Array[RtsUnit]) -> void:
	var controller = _controller.get_ref()
	var attack_watch: Dictionary = controller.attack_watch
	var now: float = game.match_statistics.elapsed
	var active_ids: Dictionary = {}
	for soldier in army:
		var id := soldier.get_instance_id()
		active_ids[id] = true
		if soldier.order != "attack" or not is_instance_valid(soldier.target):
			attack_watch.erase(id)
			continue
		if soldier.target is RtsUnit and game.fog.active and not game.fog.can_detect_unit(owner_id, soldier.target):
			soldier.order_stop()
			attack_watch.erase(id)
			continue
		var target_radius: float = 18.0
		if soldier.target is RtsUnit: target_radius = soldier.target.radius()
		elif soldier.target is RtsBuilding: target_radius = maxf(soldier.target.size().x, soldier.target.size().y) * 0.5 + soldier.radius()
		var reach: float = float(soldier.stats.get("range", 0.0)) + target_radius + 14.0
		if soldier.position.distance_to(soldier.target.position) <= reach:
			attack_watch.erase(id)
			continue
		var target_id := soldier.target.get_instance_id()
		var state: Dictionary = attack_watch.get(id, {})
		if state.is_empty() or int(state["target_id"]) != target_id or soldier.position.distance_to(state["position"]) > 14.0:
			attack_watch[id] = {"target_id": target_id, "position": soldier.position, "since": now}
			continue
		if now - float(state["since"]) < 9.0: continue
		var direction := (soldier.target.position - soldier.position).normalized()
		if direction.is_zero_approx(): direction = Vector2.RIGHT
		var lateral := Vector2(-direction.y, direction.x)
		var flank: Vector2 = Vector2.INF
		var side := 1.0 if id % 2 == 0 else -1.0
		for offset in [side * 85.0, -side * 85.0, side * 145.0]:
			var candidate: Vector2 = game.navigation.nearest_walkable_point(soldier.position + direction * 70.0 + lateral * offset, soldier.radius(), soldier, false)
			if candidate.distance_to(soldier.position) < 35.0: continue
			if game.navigation.path_between(soldier.position, candidate, soldier).is_empty(): continue
			flank = candidate
			break
		if flank != Vector2.INF:
			soldier.order_move(flank)
			controller.last_tactic = "flank"
		else:
			soldier.order_stop()
			controller.last_tactic = "retarget"
		attack_watch.erase(id)
	for id in attack_watch.keys():
		if not active_ids.has(id): attack_watch.erase(id)

func _tactical_orders(army: Array[RtsUnit]) -> bool:
	var controller = _controller.get_ref()
	if army.is_empty(): return false
	var center: RtsBuilding = game._player_center(owner_id)
	var home: Vector2 = center.position if center != null else game.spawn_point_for(owner_id)
	var visible := _visible_enemy_units()
	var threat: RtsUnit
	var threat_score := INF
	var raid_target: RtsUnit
	var raid_distance := INF
	for enemy in visible:
		var home_distance := enemy.position.distance_to(home)
		if enemy.kind != "villager" and home_distance < 390.0 and home_distance < threat_score:
			threat = enemy
			threat_score = home_distance
		if enemy.kind == "villager" and home_distance > 390.0:
			var distance := enemy.position.distance_to(home)
			if distance < raid_distance:
				raid_target = enemy
				raid_distance = distance
	for soldier in army:
		if soldier.hp > soldier.max_hp * 0.27 or soldier.order in ["move", "garrison"]: continue
		var nearby_enemy := false
		for enemy in visible:
			if soldier.position.distance_to(enemy.position) < 170.0:
				nearby_enemy = true
				break
		if nearby_enemy:
			soldier.order_move(home + Vector2.from_angle(float(soldier.get_instance_id() % 32) * TAU / 32.0) * 75.0)
			controller.last_tactic = "retreat"
	if controller.tactic_cooldown > 0.0: return threat != null
	if threat != null:
		var defenders: Array[RtsUnit] = []
		for soldier in army:
			if soldier.hp <= soldier.max_hp * 0.27 or soldier.position.distance_to(home) > 650.0: continue
			defenders.append(soldier)
			if defenders.size() >= 14: break
		if not defenders.is_empty():
			game.issue_group_order(defenders, threat.position, true)
			controller.last_tactic = "defend"
			controller.tactic_cooldown = 9.0
		return true
	if raid_target != null and army.size() >= controller.attack_threshold() + 4:
		var raiders: Array[RtsUnit] = []
		for soldier in army:
			if soldier.stats.get("tags", []).has("cavalry") and soldier.order == "idle" and soldier.hp > soldier.max_hp * 0.6:
				raiders.append(soldier)
				if raiders.size() >= 4: break
		if raiders.size() >= 2:
			game.issue_group_order(raiders, raid_target.position, true)
			controller.last_tactic = "raid"
			controller.tactic_cooldown = 12.0
	return false

func push(army: Array[RtsUnit], center: RtsBuilding, age: int) -> void:
	var controller = _controller.get_ref()
	if army.size() >= controller.attack_threshold():
		var target: Node2D = game.strategic_target_for(owner_id)
		if target == null:
			for building in game.buildings:
				if is_instance_valid(building) and game.is_enemy(owner_id, building.owner_id) and building.kind == "landmark":
					target = building
					break
		if target != null:
			var home: Vector2 = center.position if center != null else game.spawn_point_for(owner_id)
			var rally := home.move_toward(target.position, 180.0)
			var ready_army: Array[RtsUnit] = []
			for soldier in army:
				if soldier.hp <= soldier.max_hp * 0.4: continue
				if soldier.order == "idle" or soldier.order == "move" and soldier.destination.distance_to(rally) < 55.0:
					ready_army.append(soldier)
			var wave_size: int = controller.attack_threshold() + [2, 5, 8, 10][clampi(age - 1, 0, 3)]
			if ready_army.size() >= wave_size and controller.push_cooldown <= 0.0:
				game.issue_group_order(ready_army, target.position, true)
				controller.last_tactic = "push"
				controller.push_cooldown = 18.0
			else:
				for soldier in ready_army:
					if soldier.order != "idle": continue
					if soldier.position.distance_to(rally) > 95.0: soldier.order_move(rally)
				if not ready_army.is_empty(): controller.last_tactic = "regroup"
			if target is RtsBuilding and army.size() >= controller.attack_threshold() + 3:
				for soldier in army:
					if soldier.kind == "battering_ram" and soldier.order in ["idle", "move", "attack_move"] and soldier.position.distance_to(target.position) > 110.0:
						soldier.order_attack(target)
						controller.last_tactic = "siege_push"
