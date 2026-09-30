extends SceneTree

const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")

func _initialize() -> void: call_deferred("_run")

func _arrows(game: Node2D) -> Array:
	return game.get_children().filter(func(node: Node) -> bool: return node is RtsProjectile and not node.is_queued_for_deletion())

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.feedback_audio.free()
	game.feedback_audio = null
	game.start_game("English", 4242)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.navigation.route_budget_enabled = false
	var defender: RtsUnit = game.spawn_unit(1, "spearman", game.units[0].position)
	defender.max_hp = 10000.0
	for kind in ["spearman", "archer", "longbow", "man_at_arms", "palace_guard", "crossbowman", "arbaletrier", "zhuge_nu", "handcannoneer", "grenadier", "scout", "horseman", "knight", "royal_knight", "fire_lancer"]:
		var attacker: RtsUnit = game.spawn_unit(0, kind, defender.position + Vector2(30, 0))
		# Spawn placement avoids earlier actors; this test needs a fixed in-range target.
		attacker.position = defender.position + Vector2(30, 0)
		attacker.order_attack(defender)
		attacker.attack_timer = 0.15
		defender.hp = defender.max_hp
		var initial_hp := defender.hp
		var profile := RtsStatResolver.attack_profile(attacker.stats, defender.stats)
		var expected_damage := RtsCombatRules.volley_damage(attacker.stats, defender.stats, profile)
		attacker._process_attack_order(0.01)
		var prepared = State.capture(attacker)
		assert(prepared.visual_action == "attack" and not prepared.action_released, "%s windup must hold the weapon before the real attack" % kind)
		assert(defender.hp == initial_hp and _arrows(game).is_empty(), "the new pose must not add an early hit")
		attacker._tick_visual(0.16)
		attacker._tick_status(0.16)
		attacker._process_attack_order(0.01)
		assert(State.capture(attacker).action_released and not prepared.action_released, "release must match the real attack and preserve earlier snapshots")
		assert(State.capture(attacker).release_elapsed == 0.0 and prepared.release_elapsed == -1.0, "flash age must start at actual launch, even after a windup")
		assert(attacker.attack_timer > 0.0)
		if profile.get("damage_kind", "melee") == "melee":
			assert(_arrows(game).is_empty() and is_equal_approx(defender.hp, initial_hp - expected_damage), "spear thrust must retain the original melee damage")
		else:
			assert(_arrows(game).size() == 1 and defender.hp == initial_hp, "bow release must create one arrow without immediate damage")
			var arrow: RtsProjectile = _arrows(game)[0]
			assert(is_equal_approx(arrow.impact_damage, expected_damage))
			arrow._process(1.0)
			assert(is_equal_approx(defender.hp, initial_hp - expected_damage), "arrow impact must retain the original ranged damage")
		attacker._tick_visual(0.1)
		assert(is_equal_approx(State.capture(attacker).release_elapsed, 0.1))
		attacker._tick_visual(1.0)
		assert(attacker.visual_action == "" and not State.capture(attacker).action_released and State.capture(attacker).release_elapsed == -1.0, "recovery must clear the release pose")
		attacker.order_stop()
		game.units.erase(attacker)
		attacker.free()
	# Actual charge contact persists visually after gameplay clears charging.
	# Use an unbraced defender; a stationary spearman correctly cancels charges.
	defender.kind = "archer"
	defender.stats = GameData.UNITS["archer"].duplicate(true)
	var knight: RtsUnit = game.spawn_unit(0, "knight", defender.position + Vector2(30, 0))
	knight.position = defender.position + Vector2(30, 0)
	knight.order_attack(defender)
	knight.charging = true
	knight.charge_distance = 80.0
	knight._process_attack_order(0.01)
	assert(not knight.charging and State.capture(knight).charge_impact)
	knight._tick_visual(1.0)
	assert(not State.capture(knight).charge_impact)
	knight.order_stop()
	# Healing and conversion follow real effects and timers, without extra healing.
	var monk: RtsUnit = game.spawn_unit(0, "monk", defender.position + Vector2(60, 0))
	monk.position = defender.position + Vector2(60, 0)
	knight.position = monk.position + Vector2(20, 0)
	knight.hp = knight.max_hp - 20.0
	monk._heal_ally(0.01)
	assert(is_equal_approx(knight.hp, knight.max_hp - 13.0) and State.capture(monk).healing)
	monk._heal_ally(0.5)
	assert(is_equal_approx(knight.hp, knight.max_hp - 13.0), "animation must not add healing ticks")
	var relic := RtsRelic.new()
	monk.carried_relic = relic
	assert(monk.activate_ability("convert") and State.capture(monk).converting)
	var phase := monk.visual_phase
	monk._tick_visual(0.7)
	assert(not State.capture(monk).healing and State.capture(monk).converting and monk.visual_phase > phase)
	monk._tick_status(3.1)
	assert(not State.capture(monk).converting and defender.owner_id == monk.owner_id)
	monk.carried_relic = null
	relic.free()
	# Tax credit and the brief writing pose occur only when collection succeeds.
	var official: RtsUnit = game.spawn_unit(0, "imperial_official", defender.position)
	var building: RtsBuilding = game.spawn_building(0, "mill", defender.position + Vector2(100, 0))
	official.position = building.position + Vector2(30, 0)
	official.target = building
	official.order = "collect_tax"
	building.tax_stockpile = 17
	var gold: int = game.players[0]["gold"]
	official.orders.tick(official, 0.01)
	assert(game.players[0]["gold"] == gold + 17 and building.tax_stockpile == 0)
	assert(State.capture(official).tax_active)
	phase = official.visual_phase
	official._tick_visual(0.1)
	assert(official.visual_phase > phase, "collection must keep writing after the order completes")
	official._tick_visual(1.0)
	assert(not State.capture(official).tax_active)
	for arrow in game.get_children():
		if arrow is RtsProjectile: arrow.free()
	game.free()
	print("HUMANOID_ACTIONS_OK")
	quit()
