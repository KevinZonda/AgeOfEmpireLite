extends SceneTree

const Session = preload("res://scripts/match/match_session.gd")
const Economy = preload("res://scripts/match/match_economy.gd")
const Production = preload("res://scripts/match/match_production.gd")
const Changes = preload("res://scripts/match/match_changes.gd")

# No HUD, notifications, camera, or scene setup. Real queue/rule/accounting code
# must execute against match state alone.
class MatchFixture extends Node2D:
	var session = Session.new(self)
	var players: Array[Dictionary]:
		get: return session.players
	var civilizations := ["English"]
	var units: Array[RtsUnit] = []
	var buildings: Array[RtsBuilding] = []
	var game_over := false
	func population_used(owner_id: int) -> int: return Economy.population_used(self, owner_id)
	func population_cap(owner_id: int) -> int: return Economy.population_cap(self, owner_id)
	func active_landmark_id(_owner_id: int) -> String: return ""
	func queued_research(owner_id: int) -> Array[String]: return Production.queued_research(self, owner_id)
	func spend(owner_id: int, cost: Dictionary) -> bool: return Economy.spend(self, owner_id, cost)

var events: Array[Dictionary] = []
var view_refreshes := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	_test_without_view()
	_test_nested_and_reentrant_notifications()
	await _test_view_coalescing()
	print("MATCH_CHANGES_OK")
	quit()

func _test_without_view() -> void:
	var game := MatchFixture.new()
	game.session.players.append({"food": 500, "wood": 500, "gold": 500, "stone": 500, "age": 2, "researched": [], "landmarks": [], "dynasty": ""})
	var center := RtsBuilding.new()
	center.game = game
	center.kind = "town_center"
	center.owner_id = 0
	game.buildings.append(center)
	var on_commit := func(owner_id: int, domains: Array[StringName]) -> void:
		events.append({"owner_id": owner_id, "domains": domains, "food": game.players[0]["food"], "queued": center.production_queue.size(), "population": game.population_used(0)})
	game.session.changes.changed.connect(on_commit)
	assert(Production.train_unit(game, center, "villager"))
	assert(events.size() == 1 and events[0]["food"] == 450 and events[0]["queued"] == 1 and events[0]["population"] == 1, "observer must see payment and population reservation together")
	assert(events[0]["domains"].has(&"resources") and events[0]["domains"].has(&"production"))
	assert(Production.cancel_job(game, center, 0))
	assert(events.size() == 2 and events[-1]["food"] == 500 and events[-1]["population"] == 0, "refund and population release must be one committed change")
	assert(not Production.cancel_job(game, center, 0) and events.size() == 2)
	game.players[0]["food"] = 0
	assert(not Production.train_unit(game, center, "villager") and events.size() == 2 and center.production_queue.is_empty(), "rejected orders must not publish mutations")
	game.players[0]["food"] = 500
	center.kind = "barracks"
	assert(Production.research_technology(game, center, "forged_weapons"))
	assert(events.size() == 3 and game.queued_research(0) == ["forged_weapons"])
	assert(not Production.research_technology(game, center, "forged_weapons") and events.size() == 3)
	assert(Production.cancel_job(game, center, 0) and game.queued_research(0).is_empty())
	assert(game.players[0]["wood"] == 500 and game.players[0]["gold"] == 500)
	Production.complete_research(game, 0, "forged_weapons")
	assert(events[-1]["domains"].has(&"research") and game.players[0]["researched"] == ["forged_weapons"])
	var count := events.size()
	Production.complete_research(game, 0, "forged_weapons")
	assert(events.size() == count, "duplicate completion must be silent")
	game.session.changes.changed.disconnect(on_commit)
	center.free()
	game.free()

func _test_nested_and_reentrant_notifications() -> void:
	var changes := Changes.new()
	var notifications: Array[String] = []
	var on_changed := func(owner_id: int, domains: Array[StringName]) -> void:
		notifications.append("%s:%s" % [owner_id, domains[0]])
		if domains.has(&"production"): changes.mark(1, &"entities")
	changes.changed.connect(on_changed)
	changes.begin_transaction()
	changes.mark(0, &"production")
	changes.begin_transaction()
	changes.mark(0, &"production")
	changes.end_transaction()
	assert(notifications.is_empty(), "nested transaction must remain private until outer commit")
	changes.end_transaction()
	assert(notifications == ["0:production", "1:entities"], "observer mutation must not corrupt or replay the original pending batch")
	changes.changed.disconnect(on_changed)

func _test_view_coalescing() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.paused = true
	await process_frame
	var center: RtsBuilding = game._player_center(0)
	game.players[0]["food"] = 1000
	game._update_hud()
	game.hud_ui.match_view_refreshed.connect(func() -> void: view_refreshes += 1)
	assert(game.train_unit(center, "villager") and game.train_unit(center, "villager"))
	game.credit_resource(0, "food", 7)
	assert(view_refreshes == 0 and game.resource_readouts["food"].text == "1000", "transactions must not synchronously render intermediate state")
	await process_frame
	await process_frame
	assert(view_refreshes == 1 and game.resource_readouts["food"].text == "907", "same-frame mutations must coalesce into one final view")
	game._toggle_global_queue()
	var row: Node = game.hud_ui.global_queue_list.get_child(1)
	var locator: Button = row.get_child(0)
	var old_text := locator.text
	center.production_remaining += 5.0
	game._refresh_global_queue_panel()
	assert(game.hud_ui.global_queue_list.get_child(1) == row and locator.text != old_text, "countdown update must preserve the row and its hover/focus")
	assert(game.cancel_production_job(center, 1))
	assert(game.cancel_production_job(center, 0))
	await process_frame
	assert(game.population_used(0) == 6 and game.resource_readouts["food"].text == "1007")
	# Unit creation and next-task initialization are one production completion.
	assert(game.train_unit(center, "villager") and game.train_unit(center, "villager"))
	var completions: Array[Dictionary] = []
	var on_completion := func(_owner_id: int, domains: Array[StringName]) -> void:
		completions.append({"domains": domains, "queued": center.production_queue.size(), "remaining": center.production_remaining})
	game.session.changes.changed.connect(on_completion)
	game.paused = false
	center._process(center.production_remaining + 0.01)
	game.paused = true
	game.session.changes.changed.disconnect(on_completion)
	assert(completions.size() == 1 and completions[0]["queued"] == 1 and completions[0]["remaining"] == center._training_time("villager"), "completion observer must see the next job fully initialized")
	assert(completions[0]["domains"].has(&"entities") and completions[0]["domains"].has(&"production"))
	assert(game.cancel_production_job(center))
	await process_frame
	# Entity changes refresh facts without expiring unrelated action callbacks.
	var generation: int = game.player_actions.generation
	var command: Node = game.command_buttons[0]
	game.spawn_unit(1, "spearman", Vector2(2000, 2000))
	game.spawn_unit(0, "spearman", center.position + Vector2(80, 0))
	await process_frame
	assert(game.player_actions.generation == generation and is_instance_valid(command), "ordinary spawns must preserve command tiles and pointer clicks")
	var before := view_refreshes
	game.credit_resource(1, "food", 13)
	await process_frame
	assert(view_refreshes == before, "enemy resource mutations must not refresh the player's HUD")
	assert(game.train_unit(center, "villager"))
	game.start_game("Chinese", 4242)
	game.paused = true
	await process_frame
	assert(game._player_center(0) != center and game._player_center(0).production_queue.is_empty(), "pending view refresh must read the restarted match, never retain an old producer")
	_test_queue_task_identity(game)
	game.free()

func _test_queue_task_identity(game: Node2D) -> void:
	game.players[0]["age"] = 2
	for resource in GameData.RESOURCE_NAMES: game.players[0][resource] = 10000
	var barracks: RtsBuilding = game.spawn_building(0, "barracks", game._player_center(0).position + Vector2(0, -180))
	game.selected.assign([barracks])
	game._rebuild_actions()
	for panel in ["global", "selected"]:
		assert(game.train_unit(barracks, "spearman"))
		assert(game.research_technology(barracks, "forged_weapons"))
		assert(game.train_unit(barracks, "spearman"))
		var third_job: Dictionary = barracks.production_queue[2]
		var first: Button
		var second: Button
		if panel == "global":
			game._refresh_global_queue_panel()
			first = game.hud_ui.global_queue_list.get_child(1).get_child(1)
			second = game.hud_ui.global_queue_list.get_child(2).get_child(1)
		else:
			game._update_hud()
			first = game.queue_controls.get_child(0)
			second = game.queue_controls.get_child(1)
		first.pressed.emit()
		second.pressed.emit()
		second.pressed.emit()
		assert(barracks.production_queue.size() == 1 and is_same(barracks.production_queue[0], third_job), "back-to-back stale row clicks must cancel their original tasks exactly once")
		assert(game.cancel_production_job(barracks))
