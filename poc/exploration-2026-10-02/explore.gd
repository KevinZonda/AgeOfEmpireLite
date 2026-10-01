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
	"pavise_stop", "wall_vertical_gate", "transport_deep_death", "construction_completion_damage",
	"trade_return_market", "supervise_town_center", "supervise_barracks", "rally_dead_tree", "rally_dead_farm",
	"rally_queued_target", "selection_after_garrison", "garrison_double_host", "hidden_attack_tracking",
	"field_siege_unfinished_attack", "field_siege_unfinished_boarding", "sacred_eliminated_wins",
	"ally_gate", "enemy_gate", "siege_tower_docking", "farm_builder_followup", "mill_builder_followup",
	"pause_production", "restart_projectiles", "conversion_selection", "trade_garrison_resume", "depleted_resource_queue",
	"queued_farm_frees_later", "queued_farm_alternative", "construction_real_worker",
	"allied_forest_visibility", "allied_scout_detection", "own_scout_detection", "monk_heal_teammate", "monk_heal_own",
	"french_keep_influence_snap"
]
const OBSERVATIONS := ["trade_overlap", "monk_garrison", "naval_garrison", "conversion_official_limit", "conversion_wall", "population_house_loss", "dead_garrison_slot", "dead_passenger_slot", "garrison_double_host", "garrison_builders", "trade_garrison_resume", "team_sacred_elimination"]

func _initialize() -> void: call_deferred("_run")

func record(id: String, ok: bool, evidence: Dictionary) -> void:
	results.append({"id": id, "status": "pass" if ok else "observation" if OBSERVATIONS.has(id) else "bug", "evidence": evidence})
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

func free_site(kind: String, near := Vector2(900, 650)) -> Vector2:
	for ring in range(0, 1000, 40):
		for i in 32:
			var point: Vector2 = game.snap_build_point(kind, near + Vector2.from_angle(TAU * i / 32.0) * ring)
			if game.can_place(kind, point): return point
	return Vector2.INF

func tick_units(units: Array, count := 300) -> void:
	for i in count:
		game.navigation.simulation_frame += 1
		for u in units:
			if is_instance_valid(u) and not u.is_queued_for_deletion(): u._process(0.05)


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
	var path := OS.get_environment("RTS_POC_RESULTS")
	if path.is_empty(): path = "res://poc/exploration-2026-10-02/results.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
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
			game.match_mode = "team2"
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
			var u := soldier("archer", 0, wall.position)
			u.wall_host = wall
			var before: float = RtsCivilizationRules.wall_ranged_multiplier(game, u)
			landmark.take_damage(99999.0)
			var after: float = RtsCivilizationRules.wall_ranged_multiplier(game, u)
			record(id, before > after and after == 1.0, {"multiplier_before": before, "multiplier_after": after})
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
		"trade_return_market":
			var market: RtsBuilding = game.spawn_building(0, "market", free_site("market"))
			var post: RtsTradePost = game.trade_posts[0]
			var u := soldier("trader", 0, market.position + Vector2(100, 0))
			u.issue_command("trade", Vector2.INF, post)
			u.position = post.position
			u._process_trade_order(0.01)
			u.position = game.navigation.nearest_walkable_point(market.position + Vector2(market.size().x * 0.5 + u.radius() + 1.0, 0), u.radius(), u)
			var before: int = game.players[0]["gold"]
			tick_units([u], 600)
			record(id, game.players[0]["gold"] > before, {"income_on_return": game.players[0]["gold"] - before, "distance_to_market": u.position.distance_to(market.position), "market_half_width": market.size().x * 0.5, "trader_radius": u.radius(), "order": u.order, "returning": u.trade_returning})
		"supervise_town_center", "supervise_barracks":
			game.civilizations[0] = "Chinese"
			var b: RtsBuilding = game._player_center(0) if id == "supervise_town_center" else game.spawn_building(0, "barracks", free_site("barracks"))
			var u := soldier("imperial_official", 0, b.position + Vector2(140, 0))
			u.issue_command("supervise", Vector2.INF, b)
			tick_units([u], 200)
			game.train_unit(b, "villager" if b.kind == "town_center" else "spearman")
			b._process(0.1)
			record(id, b.supervise_work_rate > 1.0, {"work_rate": b.supervise_work_rate, "distance": u.position.distance_to(b.position), "official_order": u.order, "radius": u.radius(), "building_size": str(b.size())})
		"rally_dead_tree", "rally_dead_farm", "rally_queued_target":
			var center: RtsBuilding = game._player_center(0)
			var target_ref: Node2D = game.spawn_building(0, "farm", free_site("farm")) if id == "rally_dead_farm" else game.resources.filter(func(r): return r.kind == "wood")[0]
			center.set_rally(target_ref.position, target_ref)
			game.train_unit(center, "villager")
			var before: int = game.units.size()
			target_ref.queue_free()
			if id != "rally_queued_target": await process_frame
			center._process(center.production_remaining + 0.1)
			record(id, game.units.size() == before + 1, {"units_before": before, "units_after": game.units.size(), "queue_after": center.production_queue.size()})
		"selection_after_garrison":
			var center: RtsBuilding = game._player_center(0)
			var u := soldier("villager", 0, center.position + Vector2(0, 95))
			game.selected.assign([u])
			u.issue_command("garrison", Vector2.INF, center)
			tick_units([u], 50)
			game._rebuild_actions()
			var enabled_builds: int = game.command_buttons.filter(func(b): return b.get_meta("action_type", "") == "build" and not b.disabled).size()
			var site := free_site("house", center.position + Vector2(200, 0))
			game.build_mode = "house"
			var before: int = game.players[0]["wood"]
			game._confirm_build(site)
			record(id, not game.selected.has(u) or game.players[0]["wood"] == before, {"garrisoned": u.garrisoned_in == center, "selected": game.selected.has(u), "enabled_build_buttons": enabled_builds, "wood_spent": before - game.players[0]["wood"], "worker_order": u.order})
		"garrison_double_host":
			var a: RtsBuilding = game._player_center(0)
			var b: RtsBuilding = game.spawn_building(0, "outpost", free_site("outpost"))
			var u := soldier("villager")
			a.garrison_unit(u)
			var second: bool = b.garrison_unit(u)
			record(id, not second, {"admitted_to_second": second, "first_slots": a.garrisoned_units.size(), "second_slots": b.garrisoned_units.size()})
		"hidden_attack_tracking":
			game.fog.active = true
			var u := soldier("longbow", 0, Vector2(1000, 650))
			var enemy := soldier("spearman", 1, u.position + Vector2(100, 0))
			game.fog.update_visibility()
			u.issue_command("attack", Vector2.INF, enemy)
			enemy.position = game.world_map.nearest_walkable_point(Vector2(2000, 1900))
			game.fog.update_visibility()
			var seen: bool = game.fog.can_detect_unit(0, enemy)
			tick_units([u], 2)
			record(id, u.target != enemy or u.route_goal.distance_to(enemy.position) > 50.0, {"enemy_detected": seen, "enemy_position": str(enemy.position), "live_route_goal": str(u.route_goal), "order": u.order, "still_tracks_enemy": u.target == enemy})
		"field_siege_unfinished_attack", "field_siege_unfinished_boarding":
			var ram := soldier("battering_ram")
			ram.field_build_remaining = 10.0
			if id == "field_siege_unfinished_attack":
				var enemy: RtsBuilding = game._player_center(1)
				ram.issue_command("attack", Vector2.INF, enemy)
				var before := enemy.hp
				tick_units([ram], 10)
				record(id, enemy.hp == before, {"enemy_damage": before - enemy.hp, "remaining_construction": ram.field_build_remaining})
			else:
				var u := soldier("spearman", 0, ram.position + Vector2(30, 0))
				var boarded: bool = ram.garrison_unit(u)
				record(id, not boarded, {"boarded": boarded, "remaining_construction": ram.field_build_remaining})
		"sacred_eliminated_wins":
			game.match_mode = "ffa3"
			game.start_game("English", 431, "French")
			game.fog.active = false
			for site in game.objectives.sacred_sites: site["owner_id"] = 1
			game.objectives._process(0.1)
			game._player_center(1).take_damage(99999.0)
			game.objectives._process(91.0)
			record(id, not game.game_over, {"defeated": game.defeated_players, "game_over": game.game_over, "sacred_holder": game.objectives.sacred_holder, "remaining": game.objectives.sacred_remaining})
		"ally_gate", "enemy_gate":
			game.match_mode = "team2"
			game.start_game("English", 431, "French")
			var gate: RtsBuilding = game.spawn_building(2, "palisade_gate", free_site("palisade_gate"))
			var u := soldier("spearman", 0 if id == "ally_gate" else 1, gate.position + Vector2(120, 0))
			game.navigation.refresh()
			var occupied: bool = game.navigation.can_occupy(gate.position, u.radius(), u, false, false)
			record(id, occupied if id == "ally_gate" else not occupied, {"can_cross": occupied, "enemy": game.is_enemy(u.owner_id, gate.owner_id), "position": str(gate.position)})
		"siege_tower_docking":
			var wall: RtsBuilding = game.spawn_building(1, "stone_wall", free_site("stone_wall"))
			var tower := soldier("siege_tower", 0, wall.position + Vector2(140, 0))
			tower.issue_command("assault_wall", Vector2.INF, wall)
			tick_units([tower], 150)
			record(id, tower.order == "siege_tower_docked", {"order": tower.order, "distance": tower.position.distance_to(wall.position), "wall_width": wall.size().x, "tower_radius": tower.radius()})
		"farm_builder_followup", "mill_builder_followup":
			var kind := "farm" if id == "farm_builder_followup" else "mill"
			var site := free_site(kind)
			var b: RtsBuilding = game.spawn_building(0, kind, site, true)
			var u := soldier("villager", 0, site + Vector2(100, 0))
			var target_ref: RtsResource
			if kind == "mill": target_ref = game.spawn_resource("food", site + Vector2(0, 100), 1000, "berries")
			u.issue_command("build", Vector2.INF, b)
			tick_units([u], 400)
			record(id, b.is_complete() and u.order == "gather", {"complete": b.is_complete(), "worker_order": u.order, "gathering_farm": u.target == b, "gathering_berries": u.target == target_ref})
		"pause_production":
			var b: RtsBuilding = game._player_center(0)
			game.train_unit(b, "villager")
			var before := b.production_remaining
			game._set_paused(true)
			b._process(10.0)
			record(id, b.production_remaining == before, {"remaining_before": before, "remaining_after": b.production_remaining})
		"restart_projectiles":
			var bolt := RtsProjectile.new()
			bolt.setup_point(game, 0, Vector2(400, 400), Vector2(800, 800), 100.0, 100.0, 100.0, {}, {})
			game.add_child(bolt)
			game.start_game("English", 432, "French")
			record(id, bolt.is_queued_for_deletion(), {"old_projectile_queued_for_deletion": bolt.is_queued_for_deletion()})
		"conversion_selection":
			var monk := soldier("monk")
			carry(monk)
			var u := soldier("spearman", 1, monk.position + Vector2(30, 0))
			game.selected.assign([u])
			game._rebuild_actions()
			game._update_hud()
			var before: int = game.command_buttons.size()
			monk._finish_conversion()
			game._update_hud()
			var after: int = game.command_buttons.size()
			record(id, after > 0, {"new_owner": u.owner_id, "commands_before": before, "commands_after": after})
		"trade_garrison_resume":
			var center: RtsBuilding = game._player_center(0)
			game.spawn_building(0, "market", free_site("market"))
			var u := soldier("trader", 0, center.position + Vector2(100, 0))
			u.issue_command("trade", Vector2.INF, game.trade_posts[0])
			u.remember_work()
			var boarded: bool = center.garrison_unit(u)
			center.ungarrison_all(true)
			record(id, boarded and u.order == "trade", {"boarded": boarded, "resumed_order": u.order})
		"depleted_resource_queue":
			var u := soldier("villager")
			var resource: RtsResource = game.spawn_resource("wood", u.position + Vector2(25, 0), 1)
			u.issue_command("gather", Vector2.INF, resource)
			u.issue_command("move", Vector2(1200, 650), null, true)
			u._process_gather_order(0.1)
			record(id, u.order == "move", {"order": u.order, "queue_size": u.command_queue.size()})
		"queued_farm_frees_later", "queued_farm_alternative":
			var farm: RtsBuilding = game.spawn_building(0, "farm", free_site("farm"))
			var current := soldier("villager", 0, farm.position + Vector2(55, 0))
			current.order_gather(farm)
			var other: RtsBuilding
			if id == "queued_farm_alternative": other = game.spawn_building(0, "farm", free_site("farm", farm.position + Vector2(0, 100)))
			var u := soldier("villager", 0, farm.position + Vector2(-400, 0))
			u.issue_command("move", farm.position + Vector2(-180, 0))
			u.issue_command("gather", Vector2.INF, farm, true)
			var queued := u.command_queue.size()
			if id == "queued_farm_frees_later": current.order_stop()
			u._advance_command()
			record(id, queued == 1 and u.order == "gather", {"queued_gather_commands": queued, "order_after_activation": u.order, "alternative_exists": other != null, "alternative_distance": other.position.distance_to(farm.position) if other != null else -1.0})
		"construction_real_worker":
			var site := free_site("house")
			var b: RtsBuilding = game.spawn_building(0, "house", site, true)
			var u := soldier("villager", 0, site + Vector2(100, 0))
			u.issue_command("build", Vector2.INF, b)
			tick_units([u], 12)
			b.take_damage(40.0)
			var before := b.hp
			var remaining := b.build_remaining
			tick_units([u], 20)
			var expected: float = before + b.max_hp * 0.7 * (remaining - b.build_remaining) / b.build_total
			record(id, is_equal_approx(b.hp, expected), {"hp_before": before, "hp_after": b.hp, "expected": expected, "construction_progress_seconds": remaining - b.build_remaining, "worker_order": u.order})
		"allied_forest_visibility", "allied_scout_detection", "own_scout_detection":
			game.match_mode = "team2"
			game.start_game("English", 431, "French")
			game.fog.active = true
			var patch: Dictionary = game.world_map.stealth_patches[0]
			# Keep human observers away; only the specified scout grants detection.
			for u in game.units:
				if u.owner_id == 0: u.position = game.spawn_point_for(0); u.order_stop()
			var point: Vector2 = patch["position"]
			var u := soldier("spearman", 2 if id == "allied_forest_visibility" else 1, point)
			u.position = point
			if id != "allied_forest_visibility":
				var scout := soldier("scout", 0 if id == "own_scout_detection" else 2, point + Vector2(0, 55))
				scout.position = point + Vector2(0, 55)
			game.navigation.invalidate_spatial_index()
			game.fog.update_visibility()
			var detected: bool = game.fog.can_detect_unit(0, u)
			record(id, detected and u.visible, {"detected": detected, "visible": u.visible, "terrain_visible": game.fog.can_see(0, u.position), "unit_owner": u.owner_id, "patch_position": str(point), "teams": game.teams})
		"monk_heal_teammate", "monk_heal_own":
			game.match_mode = "team2"
			game.start_game("English", 431, "French")
			var monk := soldier("monk")
			var u := soldier("spearman", 0 if id == "monk_heal_own" else 2, monk.position + Vector2(35, 0))
			u.hp -= 30.0
			var before := u.hp
			monk._heal_ally(1.0)
			record(id, u.hp > before, {"hp_before": before, "hp_after": u.hp, "same_team": not game.is_enemy(monk.owner_id, u.owner_id), "unit_owner": u.owner_id})
		"french_keep_influence_snap":
			var base: Vector2 = game.spawn_point_for(1)
			var stable_point := Vector2.INF
			for radius in [200.0, 270.0, 340.0]:
				for i in 16:
					var point: Vector2 = base + Vector2.from_angle(TAU * i / 16.0) * radius
					if game.can_place("stable", point): stable_point = point; break
				if stable_point != Vector2.INF: break
			var stable: RtsBuilding = game.spawn_building(1, "stable", stable_point)
			game.ai._economy._construct_french_keep()
			var keeps: Array = game.buildings.filter(func(b): return b.owner_id == 1 and b.kind == "keep")
			if keeps.is_empty():
				record(id, false, {"keeps": 0, "stable_position": str(stable.position)})
				return
			var keep: RtsBuilding = keeps[0]
			keep.advance_construction(100.0)
			var distance := keep.position.distance_to(stable.position)
			record(id, distance <= 180.0 and RtsCivilizationRules.french_keep_influence(game, stable), {"distance": distance, "influence_limit": 180.0, "keep_position": str(keep.position), "stable_position": str(stable.position), "bonus_active": RtsCivilizationRules.french_keep_influence(game, stable)})
