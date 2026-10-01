extends SceneTree

const Context = preload("res://scripts/player/context_order.gd")
var results: Array[Dictionary] = []
var game: Node2D
var cases := [
	"construction_damage", "construction_zero", "construction_repair", "trade_reissue", "trade_overlap",
	"elimination_relic", "death_relic", "destroy_monastery", "dead_garrison_slot", "dead_passenger_slot",
	"naval_garrison", "monk_garrison", "conversion_projectile", "conversion_trader", "conversion_official_limit",
	"conversion_wall", "ground_min_range", "ground_artillery_ability", "population_house_loss",
	"rally_full_farm", "rally_dead_fish", "garrison_builders", "farm_exclusive", "cancel_refund",
	"market_roundtrip", "queued_invalid_target", "team_sacred_elimination", "gatehouse_destroyed",
	"pavise_stop", "wall_vertical_gate", "transport_deep_death", "construction_completion_damage"
]

func _initialize() -> void: call_deferred("_run")

func record(id: String, ok: bool, evidence: Dictionary) -> void:
	results.append({"id": id, "status": "pass" if ok else "bug", "evidence": evidence})
	print("CASE ", JSON.stringify(results.back()))

func setup_case() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.start_game("English", 431, "French")
	game.fog.active = false
	game.ai_controllers.clear()
	for owner in game.players.size():
		game.players[owner]["age"] = 4
		for resource in ["food", "wood", "gold", "stone"]: game.players[owner][resource] = 10000
	for unit in game.units: unit.order_stop()

func soldier(kind := "spearman", owner := 0, point := Vector2(1000, 600)) -> RtsUnit:
	var unit: RtsUnit = game.spawn_unit(owner, kind, point)
	unit.engagement = "passive"
	return unit

func carry(monk: RtsUnit) -> RtsRelic:
	var relic: RtsRelic = game.relics[0]
	monk.carried_relic = relic
	relic.carried_by = monk
	relic.position = monk.position
	return relic

func projectiles() -> Array:
	return game.get_children().filter(func(n): return n is RtsProjectile and not n.is_queued_for_deletion())

func _run() -> void:
	Engine.max_fps = 0
	var chosen := OS.get_cmdline_user_args()
	for id in cases:
		if not chosen.is_empty() and not chosen.has(id): continue
		setup_case()
		var previous_count := results.size()
		await run_case(id)
		if results.size() == previous_count: record(id, false, {"runtime_error": "Case aborted; see explore.log for stack trace"})
		game.navigation.shutdown_jobs()
		game.queue_free()
		await process_frame
	var file := FileAccess.open("res://poc/exploration-2026-10-02/results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	print("EXPLORATION_COMPLETE cases=", results.size(), " bugs=", results.filter(func(r): return r.status == "bug").size())
	quit()

func run_case(id: String) -> void:
	match id:
		"construction_damage", "construction_zero", "construction_repair", "construction_completion_damage":
			var b: RtsBuilding = game.spawn_building(0, "house", Vector2(950, 700), true)
			b.advance_construction(2.0)
			var expected_full: float = b.hp
			b.take_damage(100.0)
			var before: float = b.hp
			var dt := 0.0 if id == "construction_zero" else 0.1
			if id == "construction_completion_damage": dt = b.build_remaining
			if id == "construction_repair":
				b.hp += 40.0
				before = b.hp
			b.advance_construction(dt)
			var growth: float = b.max_hp * 0.7 * dt / b.build_total
			record(id, is_equal_approx(b.hp, before + growth), {"hp_before": before, "hp_after": b.hp, "expected": before + growth, "undamaged_before": expected_full, "dt": dt})
		"trade_reissue", "trade_overlap":
			var trader := soldier("trader")
			var market: RtsBuilding = game.spawn_building(0, "market", Vector2(750, 600))
			var post: RtsTradePost = game.trade_posts[0]
			post.position = Vector2(1200, 600)
			trader.position = post.position
			var before: int = game.players[0]["gold"]
			if id == "trade_overlap":
				post.position = market.position
				trader.position = post.position
				trader.issue_command("trade", Vector2.INF, post)
			for i in 10:
				if id == "trade_reissue": trader.issue_command("trade", Vector2.INF, post)
				trader._process_trade_order(1.0 / 30.0)
			record(id, game.players[0]["gold"] - before <= 15, {"gold_gain_in_10_ticks": game.players[0]["gold"] - before, "position": str(trader.position), "home": str(market.position), "post": str(post.position)})
		"elimination_relic", "death_relic":
			var monk := soldier("monk", 1)
			var relic := carry(monk)
			if id == "elimination_relic": game._eliminate_player(1)
			else: monk.take_damage(99999.0)
			await process_frame
			record(id, relic.available(), {"available": relic.available(), "carrier_valid": is_instance_valid(relic.carried_by)})
		"destroy_monastery":
			var monastery: RtsBuilding = game.spawn_building(1, "monastery", Vector2(1050, 800))
			var relic: RtsRelic = game.relics[0]
			relic.stored_in = monastery
			monastery.relics.append(relic)
			monastery.take_damage(99999.0)
			await process_frame
			record(id, relic.available(), {"available": relic.available(), "position": str(relic.position)})
		"dead_garrison_slot":
			var b: RtsBuilding = game._player_center(0)
			var unit := soldier("villager", 0, b.position + Vector2(0, 80))
			var admitted := b.garrison_unit(unit)
			unit.take_damage(99999.0)
			await process_frame
			record(id, b.garrisoned_units.is_empty(), {"admitted": admitted, "slots_after_death": b.garrisoned_units.size(), "capacity": b.garrison_capacity()})
		"dead_passenger_slot":
			var ram := soldier("battering_ram")
			var unit := soldier("spearman", 0, ram.position + Vector2(0, 50))
			var admitted := ram.garrison_unit(unit)
			unit.take_damage(99999.0)
			await process_frame
			record(id, ram.passengers.is_empty(), {"admitted": admitted, "slots_after_death": ram.passengers.size()})
		"naval_garrison", "monk_garrison":
			var b: RtsBuilding = game._player_center(0)
			var unit := soldier("warship" if id == "naval_garrison" else "monk")
			var admitted := b.garrison_unit(unit)
			record(id, not admitted if id == "naval_garrison" else admitted, {"kind": unit.kind, "admitted": admitted, "tags": unit.stats.get("tags", [])})
		"conversion_projectile":
			var monk := soldier("monk")
			carry(monk)
			var enemy := soldier("spearman", 1, monk.position + Vector2(40, 0))
			var bolt := RtsProjectile.new()
			bolt.setup(game, 0, monk.position, enemy, 10.0)
			game.add_child(bolt)
			monk._finish_conversion()
			var before := enemy.hp
			bolt._process(0.2)
			record(id, enemy.hp == before, {"new_owner": enemy.owner_id, "hp_before": before, "hp_after": enemy.hp})
		"conversion_trader":
			var monk := soldier("monk")
			carry(monk)
			var enemy := soldier("trader", 1, monk.position + Vector2(20, 0))
			var market: RtsBuilding = game.spawn_building(1, "market", Vector2(750, 600))
			enemy.issue_command("trade", Vector2.INF, game.trade_posts[0])
			monk._finish_conversion()
			var resumed: bool = enemy._start_command({"type": "trade", "target": game.trade_posts[0]})
			record(id, not resumed or enemy.trade_home.owner_id == enemy.owner_id, {"converted_owner": enemy.owner_id, "home_owner": enemy.trade_home.owner_id, "resumed_without_own_market": resumed, "original_market": market.owner_id})
		"conversion_official_limit":
			game.civilizations[0] = "Chinese"
			game.civilizations[1] = "Chinese"
			var monk := soldier("monk")
			carry(monk)
			for i in 4: soldier("imperial_official", 0, Vector2(300, 700 + i * 25))
			soldier("imperial_official", 1, monk.position + Vector2(20, 0))
			monk._finish_conversion()
			var count: int = game.units.filter(func(u): return u.owner_id == 0 and u.kind == "imperial_official").size()
			record(id, count <= 4, {"official_count_after_conversion": count})
		"conversion_wall":
			var monk := soldier("monk")
			carry(monk)
			var wall: RtsBuilding = game.spawn_building(1, "stone_wall", monk.position + Vector2(40, 0))
			var enemy := soldier("spearman", 1, wall.position)
			enemy.wall_host = wall
			enemy.position = wall.position
			monk._finish_conversion()
			record(id, enemy.wall_host == null, {"new_owner": enemy.owner_id, "still_on_enemy_wall": enemy.wall_host == wall, "wall_owner": wall.owner_id})
		"ground_min_range":
			var siege := soldier("trebuchet")
			var profile := RtsStatResolver.primary_attack(siege.stats)
			var point := siege.position + Vector2(20, 0)
			siege.issue_command("attack_ground", point)
			siege._process_attack_ground(1.0 / 30.0)
			record(id, projectiles().is_empty(), {"range": profile.get("range"), "min_range": profile.get("min_range", siege.stats.get("min_range")), "distance": siege.position.distance_to(point), "shots": projectiles().size()})
		"ground_artillery_ability":
			game.civilizations[0] = "French"
			var cannon := soldier("cannon")
			cannon.producer_landmark_id = "fr_college_of_artillery"
			var activated := cannon.activate_ability("artillery_shot")
			cannon.issue_command("attack_ground", cannon.position + Vector2(160, 0))
			cannon._process_attack_ground(0.1)
			record(id, not cannon.artillery_shot_ready and cannon.artillery_shot_cooldown > 0.0, {"activated": activated, "shots": projectiles().size(), "ready_after_shot": cannon.artillery_shot_ready, "cooldown": cannon.artillery_shot_cooldown})
		"population_house_loss":
			var center: RtsBuilding = game._player_center(0)
			var house: RtsBuilding = game.spawn_building(0, "house", Vector2(700, 500))
			for i in 8: game.train_unit(center, "villager")
			house.take_damage(99999.0)
			var units_before: int = game.units.size()
			center._process(center.production_remaining + 0.01)
			record(id, game.units.size() == units_before, {"used": game.population_used(0), "cap": game.population_cap(0), "unit_count_before": units_before, "unit_count_after": game.units.size()})
		"rally_full_farm":
			var center: RtsBuilding = game._player_center(0)
			var farm: RtsBuilding = game.spawn_building(0, "farm", Vector2(850, 650))
			var worker := soldier("villager", 0, farm.position + Vector2(0, 45))
			worker.order_gather(farm)
			center.set_rally(farm.position, farm)
			var trained: RtsUnit = game.spawn_unit(0, "villager", center.position + Vector2(0, 90), center.rally_point, center.rally_target, center.rally_resource_kind)
			record(id, trained.order != "idle", {"trained_order": trained.order, "original_worker": worker.order})
		"rally_dead_fish":
			var fish: RtsResource
			for resource in game.resources:
				if resource.appearance == "fish": fish = resource; break
			var point := fish.position
			var dock: RtsBuilding = game.spawn_building(0, "dock", point + Vector2(70, 0))
			dock.set_rally(point, fish)
			game.train_unit(dock, "fishing_boat")
			var before: int = game.units.size()
			fish.queue_free()
			await process_frame
			dock._process(dock.production_remaining + 0.1)
			record(id, game.units.size() == before + 1, {"units_before": before, "units_after": game.units.size(), "queue_size": dock.production_queue.size()})
		"garrison_builders":
			var center: RtsBuilding = game._player_center(0)
			var workers: Array[RtsUnit] = []
			for u in game.units:
				if u.owner_id == 0 and u.kind == "villager": center.garrison_unit(u); workers.append(u)
			var site := Vector2(800, 700)
			for y in range(400, 1100, 40):
				for x in range(400, 1100, 40):
					if game.can_place("house", Vector2(x, y)): site = Vector2(x, y); break
			var before: int = game.players[0]["wood"]
			var placed: bool = game.place_building(0, "house", site, workers)
			var builders: int = game.count_builders(game.buildings.back()) if placed else 0
			record(id, not placed, {"placed": placed, "wood_spent": before - game.players[0]["wood"], "builders": builders})
		"farm_exclusive":
			var farm: RtsBuilding = game.spawn_building(0, "farm", Vector2(900, 650))
			var a := soldier("villager")
			var b := soldier("villager")
			a.order_gather(farm)
			b.order_gather(farm)
			record(id, not (a.target == farm and b.target == farm), {"first": a.order, "second": b.order})
		"cancel_refund":
			var center: RtsBuilding = game._player_center(0)
			var before: int = game.players[0]["food"]
			var admitted: bool = game.train_unit(center, "villager")
			game.cancel_production_job(center)
			var twice: bool = game.cancel_production_job(center)
			record(id, admitted and game.players[0]["food"] == before and not twice, {"before": before, "after": game.players[0]["food"], "double_cancel": twice})
		"market_roundtrip":
			game.spawn_building(0, "market", Vector2(800, 650))
			var before: int = game.players[0]["gold"]
			for i in 10:
				game.exchange_resource(0, "wood", true)
				game.exchange_resource(0, "wood", false)
			record(id, game.players[0]["gold"] < before, {"gold_delta": game.players[0]["gold"] - before})
		"queued_invalid_target":
			var u := soldier()
			var enemy := soldier("spearman", 1)
			u.issue_command("move", Vector2(1100, 650))
			u.issue_command("attack", Vector2.INF, enemy, true)
			u.issue_command("move", Vector2(1200, 650), null, true)
			enemy.take_damage(99999.0)
			await process_frame
			u._advance_command()
			record(id, u.order == "move" and u.destination.distance_to(Vector2(1200, 650)) < 60.0, {"order": u.order, "destination": str(u.destination)})
		"team_sacred_elimination":
			game.match_mode = "teams"
			game.start_game("English", 431, "French")
			game.process_mode = Node.PROCESS_MODE_DISABLED
			game.fog.active = false
			for site in game.objectives.sacred_sites: site["owner_id"] = 1
			var center: RtsBuilding = game._player_center(1)
			center.take_damage(99999.0)
			game.objectives._process(0.1)
			record(id, game.objectives.sacred_sites[0]["owner_id"] == -1, {"teams": game.teams, "defeated": game.defeated_players, "site_owner_after_elimination": game.objectives.sacred_sites[0]["owner_id"], "holder": game.objectives.sacred_holder})
		"gatehouse_destroyed":
			game.civilizations[0] = "Chinese"
			var landmark: RtsBuilding = game.spawn_building(0, "landmark", Vector2(850, 650), false, "zh_gatehouse")
			game.complete_age(0, 2, "zh_gatehouse")
			var wall: RtsBuilding = game.spawn_building(0, "stone_wall", Vector2(1000, 650))
			var before := wall.max_hp
			landmark.take_damage(99999.0)
			record(id, wall.max_hp < before, {"hp_with_landmark": before, "hp_after_destroy": wall.max_hp, "base_hp": GameData.BUILDINGS["stone_wall"]["hp"]})
		"pavise_stop":
			game.civilizations[0] = "French"
			var u := soldier("arbaletrier")
			u.activate_ability("pavise")
			var before: float = u.stats["armor"]["ranged"]
			u.order_stop()
			record(id, u.shield_timer > 0.0, {"shield_timer_after_stop": u.shield_timer, "armor_before": before, "armor_after": u.stats["armor"]["ranged"]})
		"wall_vertical_gate":
			var wall: RtsBuilding = game.spawn_building(0, "stone_wall", Vector2(1000, 650), false, "", true)
			var before := wall.position
			var converted: bool = game.convert_wall_to_gate(wall)
			record(id, converted and wall.wall_vertical and wall.position == before, {"converted": converted, "vertical": wall.wall_vertical, "position_unchanged": wall.position == before})
		"transport_deep_death":
			var ship := soldier("transport_ship")
			var u := soldier()
			# Boarding itself is covered elsewhere; set a legal occupied transport state.
			ship.passengers.append(u)
			u.enter_garrison(ship)
			ship.take_damage(99999.0)
			await process_frame
			record(id, not is_instance_valid(u), {"passenger_survived": is_instance_valid(u)})
