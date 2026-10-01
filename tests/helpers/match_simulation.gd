extends RefCounted

# Fast-forward a real match at a fixed simulation delta. Automatic processing
# stays disabled; an actual SceneTree frame drains deletion/deferred queues and
# advances the epoch used by movement groups and navigation services.
var game: Node2D
var tree: SceneTree
var previous_process_mode: int
var previous_max_fps: int
var override_modes: Dictionary = {}
var uses_runtime := false

func _init(match_game: Node2D) -> void:
	game = match_game
	tree = game.get_tree()
	previous_process_mode = game.process_mode
	previous_max_fps = Engine.max_fps
	game.process_mode = Node.PROCESS_MODE_DISABLED
	Engine.max_fps = 0
	uses_runtime = game.has_method("step")
	if not uses_runtime: _suspend_overrides(game)

func step(delta: float) -> void:
	if uses_runtime:
		game.step(delta)
		# Runtime owns match actors. This frame only drains deferred work/deletion;
		# it is not needed to advance simulation, group or navigation clocks.
		await tree.process_frame
		return
	_tick_subtree(game, delta, Node.PROCESS_MODE_PAUSABLE)
	# Generic Actor fixtures retain their original override-mode behavior.
	_suspend_overrides(game)
	for id in override_modes.keys():
		if override_modes[id].node.get_ref() == null: override_modes.erase(id)
	var epoch := Engine.get_process_frames()
	await tree.process_frame
	# During SceneTree startup the next process_frame signal can precede
	# the first frame-counter increment. Complete an actual epoch change.
	if Engine.get_process_frames() == epoch: await tree.process_frame
	_suspend_overrides(game)

func _tick_subtree(node: Node, delta: float, inherited_mode: int) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion(): return
	var mode := _original_mode(node)
	if mode == Node.PROCESS_MODE_INHERIT: mode = inherited_mode
	var enabled := mode == Node.PROCESS_MODE_ALWAYS or mode == Node.PROCESS_MODE_PAUSABLE and not tree.paused or mode == Node.PROCESS_MODE_WHEN_PAUSED and tree.paused
	# Honor explicit disabled subtrees such as fog memory ghosts, while allowing
	# a child with its own process mode to override its parent's mode as usual.
	if enabled and node.is_processing() and node.has_method("_process"): node.call("_process", delta)
	for child in node.get_children(): _tick_subtree(child, delta, mode)

func _original_mode(node: Node) -> int:
	if node == game: return previous_process_mode
	var id := node.get_instance_id()
	if override_modes.has(id):
		var saved: Dictionary = override_modes[id]
		if saved.node.get_ref() == node: return saved.mode
		override_modes.erase(id)
	var mode := node.process_mode
	if mode not in [Node.PROCESS_MODE_INHERIT, Node.PROCESS_MODE_DISABLED]:
		override_modes[id] = {"node": weakref(node), "mode": mode}
		node.process_mode = Node.PROCESS_MODE_DISABLED
	return mode

func _suspend_overrides(node: Node) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion(): return
	_original_mode(node)
	if node != game and override_modes.has(node.get_instance_id()): node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children(): _suspend_overrides(child)

func finish() -> void:
	for saved in override_modes.values():
		var node: Node = saved.node.get_ref()
		if is_instance_valid(node): node.process_mode = saved.mode
	override_modes.clear()
	if is_instance_valid(game): game.process_mode = previous_process_mode
	Engine.max_fps = previous_max_fps
