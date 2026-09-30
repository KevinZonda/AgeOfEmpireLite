extends RefCounted

const Clock = preload("res://scripts/match/match_clock.gd")
enum Phase { WORLD, ENTITIES, VISIBILITY }
var clock := Clock.new()
var stepping := false
var actors: Dictionary = {}
var _game: WeakRef

func _init(game: Node2D) -> void:
	_game = weakref(game)

# Only live match actors are managed. UI, previews and remembered fog visuals
# keep their own presentation callbacks. Entries retain insertion order within
# each phase; births during actor processing start on the following step.
func register(node: Node) -> void:
	var phase := -1
	if node is RtsWeather or node is RtsObjectiveManager: phase = Phase.WORLD
	elif node is RtsUnit or node is RtsBuilding or node is RtsResource or node is RtsProjectile or node is RtsRelic: phase = Phase.ENTITIES
	elif node is RtsFogOfWar: phase = Phase.VISIBILITY
	if phase < 0 or actors.has(node.get_instance_id()): return
	# Godot enables scripted callbacks during tree entry. Take ownership only
	# after ready, otherwise it would overwrite set_process(false).
	if not node.is_node_ready():
		node.ready.connect(_register_ready.bind(node, phase), CONNECT_ONE_SHOT)
	else:
		_register_ready(node, phase)

func _register_ready(node: Node, phase: int) -> void:
	var id := node.get_instance_id()
	actors[id] = {"node": weakref(node), "phase": phase, "enabled": node.is_processing()}
	node.set_process(false)
	node.tree_exiting.connect(unregister.bind(id), CONNECT_ONE_SHOT)

func unregister(id: int) -> void:
	actors.erase(id)

func set_actor_enabled(node: Node, enabled: bool) -> void:
	if actors.has(node.get_instance_id()): actors[node.get_instance_id()].enabled = enabled

func dispose_projectiles() -> void:
	# Projectiles are transient actors, not EntityRegistry members. End/restart
	# must retire them before a new match can resume fixed-target splash damage.
	for id in actors.keys():
		var node: Node = actors[id].node.get_ref()
		if node is RtsProjectile:
			node.queue_free()
			actors.erase(id)

func reset() -> void:
	assert(not stepping, "cannot reset a running simulation step")
	clock.reset()
	var game: Node2D = _game.get_ref()
	if game != null: game.navigation.simulation_frame = -1

func step(delta: float) -> bool:
	var game: Node2D = _game.get_ref()
	if game == null or stepping or not is_finite(delta) or delta <= 0.0: return false
	if not game.started or game.paused or game.game_over or game.get_tree().paused:
		if game.game_over: dispose_projectiles()
		game.navigation.tick_jobs(false)
		return false
	stepping = true
	clock.advance(delta)
	game.navigation.simulation_frame = clock.tick_id
	game.navigation.tick_jobs(true, clock.tick_id)
	game._tick_match_logic(delta)
	# Snapshot once: a projectile born during combat cannot get an accidental
	# partial first tick based on which unit happens to attack first.
	var current := actors.values()
	for phase in [Phase.WORLD, Phase.ENTITIES, Phase.VISIBILITY]:
		for entry in current:
			if entry.phase != phase or not entry.enabled: continue
			var node: Node = entry.node.get_ref()
			if node == null or node.is_queued_for_deletion() or not actors.has(node.get_instance_id()): continue
			if node.process_mode in [Node.PROCESS_MODE_DISABLED, Node.PROCESS_MODE_WHEN_PAUSED]: continue
			if game.game_over: break
			node.call("_process", delta)
	# Presentation reuses the final step epoch rather than rebuilding the same
	# spatial snapshot again under a renderer frame. reset restores standalone mode.
	stepping = false
	return true
