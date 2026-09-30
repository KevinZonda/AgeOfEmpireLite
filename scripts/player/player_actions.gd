extends RefCounted

# Actions carry callbacks and gameplay availability, never Control instances.
# IDs expire on rebuild so a stale button cannot execute a new selection's action.
var game: Node2D
var actions: Dictionary = {}
var hotkeys: Dictionary = {}
var generation := 0
var selection_ids: Array[int] = []

func _init(game_ref: Node2D) -> void:
	game = game_ref

func clear() -> void:
	actions.clear()
	hotkeys.clear()
	generation += 1
	selection_ids = _selection_ids()

func register(action_type: String, kind: String, keycode: int, callback: Callable) -> String:
	var id := "%d:%s:%s:%d" % [generation, action_type, kind, actions.size()]
	actions[id] = {"type": action_type, "kind": kind, "callback": callback, "active": true}
	if keycode != KEY_NONE: hotkeys[keycode] = id
	return id

func set_active(action_id: String, active: bool) -> void:
	if actions.has(action_id): actions[action_id]["active"] = active

func has_hotkey(keycode: int) -> bool:
	return hotkeys.has(keycode)

func execute_hotkey(keycode: int) -> bool:
	return execute(hotkeys[keycode]) if hotkeys.has(keycode) else false

func execute(action_id: String) -> bool:
	if not actions.has(action_id) or not actions[action_id]["active"]: return false
	if not game.started or game.paused or game.game_over: return false
	if game.age_choice_overlay != null or game.unit_preview_page != null or game.tech_tree_overlay != null or (game.settings_overlay != null and game.settings_overlay.visible): return false
	if selection_ids != _selection_ids(): return false
	var action: Dictionary = actions[action_id]
	if not availability(action["type"], action["kind"])["available"]: return false
	var callback: Callable = action["callback"]
	if not callback.is_valid(): return false
	callback.call()
	return true

func _selection_ids() -> Array[int]:
	var ids: Array[int] = []
	for entity in game.selected:
		if is_instance_valid(entity) and not entity.is_queued_for_deletion(): ids.append(entity.get_instance_id())
	return ids

func availability(action_type: String, action_kind: String, context: Dictionary = {}) -> Dictionary:
	if game.players.is_empty(): return {"available": false, "reason": "对局尚未开始", "cost": {}}
	var producer: RtsBuilding
	if not game.selected.is_empty() and is_instance_valid(game.selected[0]) and game.selected[0] is RtsBuilding:
		producer = game.selected[0]
	if context.is_empty(): context = RtsActionAvailability.context_for(game, 0, producer)
	var status: Dictionary
	if action_type in ["train", "research"]:
		status = RtsActionAvailability.production(game, producer, action_type, action_kind, context)
		var found_producer := false
		for candidate in game.selected:
			if not is_instance_valid(candidate) or not candidate is RtsBuilding or candidate.owner_id != 0: continue
			# A union of selected producers supplies the visible actions. Pick failure
			# details from a producer that actually offers this action as well.
			var offered: Array = RtsTechTree.all_train_units(game.civilizations[0], candidate.producer_kind()) if action_type == "train" else RtsTechTree.all_researches(game.civilizations[0], candidate.producer_kind())
			if not offered.has(action_kind): continue
			var candidate_status := RtsActionAvailability.production(game, candidate, action_type, action_kind, context)
			if not found_producer or candidate_status["available"]: status = candidate_status
			found_producer = true
			if candidate_status["available"]: break
	elif action_type == "unit_ability":
		status = _selected_ability_availability(action_kind)
	else:
		status = RtsActionAvailability.evaluate(action_type, action_kind, context)
	return status

func _selected_ability_availability(ability_id: String) -> Dictionary:
	var status := {"available": false, "reason": "没有可使用此技能的单位", "cost": {}}
	var found := false
	for ability in game.UNIT_ABILITY_ACTIONS:
		if ability["id"] != ability_id: continue
		for candidate in game.selected:
			if not is_instance_valid(candidate) or not candidate is RtsUnit or candidate.owner_id != 0: continue
			if not ability["kinds"].has(candidate.kind): continue
			if ability.has("civilization") and game.civilizations[0] != ability["civilization"]: continue
			if ability.has("producer_landmark") and candidate.producer_landmark_id != ability["producer_landmark"]: continue
			var candidate_status: Dictionary = candidate.ability_availability(ability_id)
			if not found or candidate_status["available"]: status = candidate_status
			found = true
			if candidate_status["available"]: return status
	return status

