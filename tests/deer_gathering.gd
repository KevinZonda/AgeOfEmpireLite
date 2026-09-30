extends SceneTree

const VisualState = preload("res://scripts/entities/visuals/unit_visual_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _arrows(game: Node2D) -> Array:
	return game.get_children().filter(func(node: Node) -> bool: return node is RtsProjectile and not node.is_queued_for_deletion())

func _step(game: Node2D, worker: RtsUnit, delta: float) -> void:
	worker._tick_visual(delta)
	worker._tick_status(delta)
	if worker.order == "gather": worker._process_gather_order(delta)
	for arrow in _arrows(game): arrow._process(delta)

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 44127, "French")
	game.fog.active = false
	# Advance only the hunter and arrows, so timing assertions are deterministic.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.navigation.route_budget_enabled = false
	var worker: RtsUnit = game.units.filter(func(unit: RtsUnit) -> bool: return unit.owner_id == 0 and unit.kind == "villager")[0]
	worker.order_stop()
	var deer: RtsResource = game.spawn_resource("food", worker.position + Vector2(40, 0), 170, "deer")
	worker.position = deer.position + Vector2(80, 0)
	game.selected.assign([worker])
	assert(deer.harvest(10) == 0, "living deer must not yield food")
	game._issue_order(deer.position)
	assert(worker.order == "gather" and worker.target == deer, "right-clicking deer should start hunting")
	var food_before: int = game.players[0]["food"]
	var initial_hp := deer.wildlife_hp
	var origin := worker.position
	worker._process_gather_order(0.01)
	assert(worker.position == origin and worker.visual_action == "hunt", "hunter should raise the bow within hunting range")
	assert(not worker.facing_right, "hunter must face the deer before drawing the bow")
	assert(deer.wildlife_hp == initial_hp and _arrows(game).is_empty(), "windup must not deal damage or spawn an arrow")
	_step(game, worker, 0.2)
	var drawn = VisualState.capture(worker)
	assert(drawn.hunting and drawn.hunt_draw > 0.0, "visual snapshot must expose the pulled bowstring")
	assert(not drawn.action_released, "the hunting pose must keep its arrow during windup")
	assert(deer.wildlife_hp == initial_hp and _arrows(game).is_empty(), "drawing the bow must leave the deer alive")
	worker._tick_visual(0.2)
	worker._process_gather_order(0.2)
	assert(_arrows(game).size() == 1 and deer.wildlife_hp == initial_hp, "releasing the arrow must defer damage until impact")
	var arrow: RtsProjectile = _arrows(game)[0]
	assert(arrow.target == deer and arrow.attack_profile.get("hunting", false), "hunting must create a visible arrow aimed at the deer")
	assert(arrow.impact_damage == worker.stats["profiles"]["hunt_ranged"]["damage"], "hunting must use the ranged hunting profile")
	assert(worker.attack_timer == worker.stats["profiles"]["hunt_ranged"]["cooldown"], "shots must respect the hunting cooldown")
	assert(VisualState.capture(worker).hunt_draw == 0.0, "bowstring must release when the arrow launches")
	assert(VisualState.capture(worker).action_released and not drawn.action_released, "the release pose must coincide with the real projectile and preserve earlier snapshots")
	assert(drawn.hunt_draw > 0.0, "captured bow pose must remain independent of the live hunter")
	arrow._process(0.05)
	assert(arrow.position != origin and deer.wildlife_hp == initial_hp, "the arrow must visibly travel before impact")
	arrow._process(0.3)
	assert(deer.wildlife_hp == initial_hp - arrow.impact_damage and not game.hit_lines.is_empty(), "arrow impact must damage the deer and show hit feedback")
	worker._process_gather_order(0.01)
	assert(_arrows(game).is_empty(), "cooldown must prevent another immediate shot")
	for frame in 240:
		_step(game, worker, 0.05)
		assert(game.players[0]["food"] == food_before and deer.amount == 170, "hunter must not gather meat before the kill")
		if deer.wildlife_hp <= 0.0: break
	assert(deer.wildlife_hp == 0.0, "successive hunting arrows must kill the deer")
	if worker.visual_action_timer > 0.0:
		worker._process_gather_order(0.01)
		assert(worker.visual_action == "hunt" and deer.amount == 170, "gathering must not overwrite the release animation")
	for frame in 100:
		_step(game, worker, 0.05)
		if deer.amount < 170: break
	assert(game.players[0]["food"] > food_before and deer.amount < 170, "hunter must approach the carcass and gather meat")
	assert(not VisualState.capture(worker).hunting, "carcass gathering must restore the gathering tool")
	# Cancelling or changing a command during windup must never release a stale shot.
	var next_deer: RtsResource = game.spawn_resource("food", worker.position + Vector2(60, 0), 170, "deer")
	worker.attack_timer = 0.0
	worker.order_gather(next_deer)
	worker._process_gather_order(0.01)
	_step(game, worker, 0.2)
	worker.order_stop()
	assert(worker.hunt_windup < 0.0 and worker.visual_action != "hunt", "stopping must cancel the drawn bow")
	_step(game, worker, 0.6)
	assert(_arrows(game).is_empty() and next_deer.wildlife_hp == 12.0, "cancelled windup must not damage its old target")
	worker.order_gather(next_deer)
	worker._process_gather_order(0.01)
	worker.order_gather(deer)
	assert(worker.hunt_windup < 0.0, "retargeting must cancel the pending hunting shot")
	worker.order_gather(next_deer)
	worker._process_gather_order(0.01)
	next_deer.take_damage(12.0)
	_step(game, worker, 0.5)
	assert(_arrows(game).is_empty(), "a deer killed during windup must not receive another shot")
	for pending_arrow in game.get_children():
		if pending_arrow is RtsProjectile: pending_arrow.free()
	game.free()
	print("DEER_GATHERING_OK")
	quit()
