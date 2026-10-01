extends SceneTree

const VisualState = preload("res://scripts/entities/visuals/unit_visual_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _arrows(game: Node2D) -> Array:
	return game.get_children().filter(func(node: Node) -> bool: return node is RtsProjectile and not node.is_queued_for_deletion())

func _clear_arrows(game: Node2D) -> void:
	for arrow in _arrows(game): arrow.free()

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.fog.active = false
	game.navigation.route_budget_enabled = false
	var boar: RtsResource = game.spawn_resource("food", Vector2(1050, 650), 420, "boar")
	var hunter: RtsUnit = game.spawn_unit(0, "villager", boar.position + Vector2(80, 0))
	game.selected.assign([hunter])
	game._issue_order(boar.position)
	assert(hunter.order == "attack" and hunter.target == boar, "right-clicking a living boar must enter combat")
	var origin := hunter.position
	var initial_hp := boar.wildlife_hp
	hunter._process_attack_order(0.01)
	assert(hunter.position == origin and hunter.visual_action == "hunt", "villager must draw a bow at hunting range without closing to melee")
	assert(_arrows(game).is_empty() and boar.wildlife_hp == initial_hp, "bow windup must not deal instant damage")
	hunter._process_attack_order(0.4)
	assert(_arrows(game).size() == 1, "hunting a boar must launch an arrow")
	var arrow: RtsProjectile = _arrows(game)[0]
	assert(arrow.attack_profile.get("hunting", false) and arrow.impact_damage == hunter.stats["profiles"]["hunt_ranged"]["damage"])
	assert(VisualState.capture(hunter).hunting, "the villager must visibly use the bow")
	arrow._process(0.4)
	assert(boar.wildlife_hp == initial_hp - arrow.impact_damage, "only the arrow impact damages the boar")
	var after_arrow := boar.wildlife_hp
	# A boar entering melee reach must cancel a pending draw, without resetting cooldown.
	hunter.attack_timer = 0.0
	hunter._process_attack_order(0.01)
	assert(hunter.hunt_windup > 0.0)
	hunter.position = boar.position + Vector2(30, 0)
	hunter.attack_timer = 0.5
	hunter._process_attack_order(0.1)
	assert(hunter.hunt_windup < 0.0 and not VisualState.capture(hunter).hunting, "contact must cancel the bow and restore the melee tool")
	assert(boar.wildlife_hp == after_arrow and _arrows(game).is_empty(), "switching weapons must preserve cooldown and cancel the stale arrow")
	hunter.attack_timer = 0.0
	hunter._process_attack_order(0.01)
	assert(boar.wildlife_hp == after_arrow - hunter.stats["profiles"]["hunt_melee"]["damage"], "contact must use hunting melee damage rather than ordinary combat damage")
	assert(_arrows(game).is_empty() and hunter.attack_timer == hunter.stats["profiles"]["hunt_melee"]["cooldown"])
	hunter.position = origin
	hunter.attack_timer = 0.0
	hunter._process_attack_order(0.01)
	assert(hunter.visual_action == "hunt", "separation must switch back to bow")
	hunter.order_stop()
	assert(hunter.hunt_windup < 0.0 and hunter.visual_action != "hunt", "stop must cancel the hunting shot")
	hunter.order_attack(boar)
	hunter.issue_command("move", origin + Vector2(120, 0), null, true)
	hunter._process_attack_order(0.01)
	boar.take_damage(100.0)
	hunter.orders.tick(hunter, 0.5)
	assert(hunter.order == "move" and hunter.hunt_windup < 0.0 and _arrows(game).is_empty(), "a boar killed during draw must advance the queued command without a stale shot")
	# Explicit gathering orders must also kill living boars before harvesting meat.
	var next_boar: RtsResource = game.spawn_resource("food", Vector2(1400, 650), 420, "boar")
	hunter.position = next_boar.position + Vector2(80, 0)
	hunter.order_gather(next_boar)
	var food_before: int = game.players[0]["food"]
	hunter._process_gather_order(0.01)
	hunter._process_gather_order(0.4)
	assert(_arrows(game).size() == 1 and next_boar.amount == 420 and game.players[0]["food"] == food_before, "gather order must hunt first, not harvest living boar")
	_clear_arrows(game)
	next_boar.take_damage(100.0)
	hunter._tick_visual(1.0)
	hunter.position = next_boar.position + Vector2(next_boar.radius + hunter.radius(), 0)
	hunter._process_gather_order(0.01)
	assert(next_boar.amount < 420 and game.players[0]["food"] > food_before, "gathering must resume after the kill")
	# Scouts have a hunting bow too, but keep their melee weapon against soldiers.
	var scout: RtsUnit = game.spawn_unit(0, "scout", next_boar.position + Vector2(80, 0))
	var scout_boar: RtsResource = game.spawn_resource("food", next_boar.position, 420, "boar")
	scout.order_attack(scout_boar)
	scout._process_attack_order(0.01)
	scout._process_attack_order(0.4)
	assert(_arrows(game).size() == 1 and VisualState.capture(scout).hunting, "scout must use its bow against distant wildlife")
	_clear_arrows(game)
	scout.position = scout_boar.position + Vector2(25, 0)
	scout.attack_timer = 0.0
	scout._process_attack_order(0.01)
	assert(scout_boar.wildlife_hp < 90.0 and _arrows(game).is_empty() and not VisualState.capture(scout).hunting)
	var defender: RtsUnit = game.spawn_unit(1, "spearman", Vector2(1800, 1400))
	assert(RtsStatResolver.attack_profile(scout.stats, defender.stats, false, 80.0) == scout.stats["profiles"]["melee"], "scout bow must remain a hunting weapon")
	var melee: RtsUnit = game.spawn_unit(0, "spearman", defender.position + Vector2(1, 0))
	melee.position = defender.position + Vector2(1, 0)
	melee.order_attack(defender)
	var hp_before := defender.hp
	melee._process_attack_order(0.01)
	assert(defender.hp < hp_before and melee.position == defender.position + Vector2(1, 0), "melee units must also attack at contact without an invented minimum range")
	# Every current ranged unit must fire from range, and zero-minimum-range
	# weapons must also fire at overlapping targets instead of trying to retreat.
	var ranged_count := 0
	for kind in GameData.UNITS:
		var stats := RtsStatResolver.unit("English", kind, 4)
		if RtsStatResolver.primary_attack_type(stats) != "ranged": continue
		var ranged: RtsUnit = game.spawn_unit(0, kind, defender.position + Vector2(100, 0))
		ranged.stats = stats
		var profile := RtsStatResolver.primary_attack(stats)
		var min_range: float = float(profile.get("min_range", stats.get("min_range", 0.0)))
		var firing_distance: float = (min_range + float(profile["range"])) * 0.5 + defender.radius()
		ranged.position = defender.position + Vector2(firing_distance, 0)
		ranged.order_attack(defender)
		origin = ranged.position
		ranged._process_attack_order(0.01)
		assert(ranged.position == origin and _arrows(game).size() == 1, "%s must fire without walking into melee" % kind)
		assert(_arrows(game)[0].attack_profile == profile, "%s must launch its ranged attack profile" % kind)
		_clear_arrows(game)
		ranged.position = defender.position + Vector2(1, 0)
		ranged.attack_timer = 0.0
		origin = ranged.position
		ranged._process_attack_order(0.01)
		if min_range <= 0.0:
			assert(ranged.position == origin and _arrows(game).size() == 1, "%s must not invent a minimum range at contact" % kind)
		else:
			assert(_arrows(game).is_empty(), "%s must respect its real minimum firing range" % kind)
		_clear_arrows(game)
		ranged_count += 1
	# The shared selector also supports definitions with both combat weapons.
	var dual := RtsStatResolver.unit("English", "archer", 4)
	dual["profiles"]["melee"] = hunter.stats["profiles"]["melee"].duplicate(true)
	assert(RtsStatResolver.attack_profile(dual, defender.stats, false, 80.0) == dual["profiles"]["ranged"])
	assert(RtsStatResolver.attack_profile(dual, defender.stats, false, 1.0) == dual["profiles"]["melee"])
	var building := {"tags": ["structure"]}
	assert(RtsStatResolver.attack_profile(hunter.stats, building, false, 1.0) == hunter.stats["profiles"]["torch"], "building attacks must keep their dedicated profile")
	assert(ranged_count >= 10, "the regression must cover the ranged roster")
	for voice in game.feedback_audio.voices:
		voice.stop()
		voice.stream = null
	await process_frame
	game.free()
	print("ATTACK_WEAPON_SELECTION_OK ranged_units=", ranged_count)
	quit()
