extends SceneTree

# Construct actual player commands without adding the main scene or any HUD.
# Both the availability check and command callbacks use the real game services.
const Game = preload("res://scripts/game.gd")
var blocked := false
var age_requests := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = Game.new()
	game.session.configure_players("English", "French", "duel", [], 0)
	game.started = true
	game.players[0].merge({"food": 5000, "wood": 5000, "gold": 5000, "stone": 5000, "age": 4}, true)
	var worker := _unit(game, "villager")
	var soldier := _unit(game, "spearman")
	game.selected.assign([worker])
	game._rebuild_actions()
	assert(game.hud_ui == null and game.get_child_count() == 0, "commands must not create a HUD or scene tree")
	assert(game.player_actions.descriptors.size() == 15, "worker catalog must retain all twelve slots and three controls")
	_assert_grid(game)
	assert(_command(game, "blacksmith")["keycode"] == KEY_Z and _command(game, "wonder")["keycode"] == KEY_V, "last-row commands must have shortcuts")
	var house := _command(game, "house")
	assert(not str(house["label"]).is_empty() and not str(house["description"]).is_empty())
	assert(game.execute_player_action(house["id"]) and game.build_mode == "house", "build execution must work without a HUD")
	game.build_mode = ""
	game.players[0]["wood"] = 0
	assert(not game.execute_player_action(house["id"]), "execution must recheck current resources")
	game.players[0]["wood"] = 5000
	game.selected.assign([soldier])
	assert(not game.execute_player_action(house["id"]), "stale selection must invalidate callbacks immediately")
	game._rebuild_actions()
	assert(not game.execute_player_action(house["id"]), "catalog rebuild must expire old IDs")
	_assert_grid(game)
	assert(_command(game, "attack_move")["keycode"] == KEY_E, "age IV field-building actions occupy the first two grid positions")
	var old_first_id: String = game.player_actions.hotkeys[KEY_Q]
	var hidden: Dictionary = {}
	for command in game.player_actions.descriptors:
		if command.get("view", "") == "command" and not command["visible"]:
			hidden = command
			break
	assert(not hidden.is_empty(), "military commands must exercise pagination")
	assert(not game.execute_player_action(hidden["id"]), "hidden page commands must not execute without HUD gating")
	assert(game.player_actions.execute_hotkey(KEY_E) and game.order_mode == "attack_move", "shortcuts must use the catalog alone")
	game.order_mode = ""
	game.player_actions.interaction_allowed = func() -> bool: return not blocked
	blocked = true
	assert(not game.player_actions.execute_hotkey(KEY_E), "injected interaction state must block both clicks and shortcuts")
	blocked = false
	var next: Dictionary = {}
	for command in game.player_actions.descriptors:
		if command.get("symbol", "") == "⋯": next = command
	assert(next["keycode"] == KEY_B)
	assert(game.player_actions.execute_hotkey(KEY_B) and game.player_actions.command_page == 1, "command paging must rebuild without a HUD")
	_assert_grid(game)
	assert(not game.execute_player_action(old_first_id), "paging must expire previous-page callbacks")
	assert(game.player_actions.hotkeys[KEY_Q] != old_first_id, "each page must rebind Q to its own first action")
	var width_before: int = game.formation_width
	assert(game.player_actions.execute_hotkey(KEY_Q) and game.formation_width == width_before + 1, "Q on page two must change width rather than build a ram")
	var selected_stop := _command(game, "stop")
	assert(selected_stop["visible"] and selected_stop["slot"] == 4 and selected_stop["keycode"] == KEY_T, "stop must remain available on later pages")
	# Age choice is a presentation request. Catalog execution needs no overlay.
	game.players[0]["age"] = 1
	game.selected.assign([worker])
	game._rebuild_actions()
	game.player_actions.age_choice_requested.connect(func() -> void: age_requests += 1)
	_assert_grid(game)
	assert(game.player_actions.execute_hotkey(KEY_F) and age_requests == 1, "age advancement belongs to its grid position")
	assert(game.player_actions.execute_hotkey(KEY_B) and game.build_page == 1)
	_assert_grid(game)
	assert(_command(game, "palisade_wall")["keycode"] == KEY_Z)
	assert(not game.player_actions.has_hotkey(KEY_D) and not game.player_actions.has_hotkey(KEY_F), "empty military-build slots must not retain economy shortcuts")
	assert(game.player_actions.execute_hotkey(KEY_G) and game.build_page == 0)
	_assert_grid(game)
	# Mixed producers retain the union while rejecting invalid owner selection.
	game.players[0]["age"] = 4
	var center := _building(game, "town_center")
	var barracks := _building(game, "barracks")
	var stable := _building(game, "stable")
	game.selected.assign([barracks, stable])
	game._rebuild_actions()
	_assert_grid(game)
	assert(not _command(game, "spearman").is_empty() and not _command(game, "horseman").is_empty(), "mixed selection must include each producer's commands")
	assert(game.execute_player_action(_command(game, "spearman")["id"]), "production must execute without a HUD")
	assert(barracks.production_queue.size() == 1 and stable.production_queue.is_empty(), "training must affect only compatible producers")
	game.selected.assign([barracks])
	barracks.owner_id = 1
	game._rebuild_actions()
	assert(game.player_actions.descriptors.is_empty(), "enemy inspection must never offer commands")
	# Leave paging/formation callbacks live and free a game that never entered
	# the tree. A weak observation must not keep the catalog alive itself.
	game.selected.assign([soldier])
	game._rebuild_actions()
	assert(not game.player_actions.actions.is_empty())
	var catalog_lifetime: WeakRef = weakref(game.player_actions)
	game.free()
	assert(catalog_lifetime.get_ref() == null, "scene-free destruction must release catalog callbacks without explicit cleanup")
	for entity in [worker, soldier, center, barracks, stable]: entity.free()
	print("PLAYER_COMMAND_CATALOG_OK")
	quit()

func _unit(game: Node2D, kind: String) -> RtsUnit:
	var unit := RtsUnit.new()
	unit.game = game
	unit.kind = kind
	unit.stats = GameData.UNITS[kind].duplicate(true)
	game.units.append(unit)
	return unit

func _building(game: Node2D, kind: String) -> RtsBuilding:
	var building := RtsBuilding.new()
	building.game = game
	building.kind = kind
	building.stats = GameData.BUILDINGS[kind].duplicate(true)
	game.buildings.append(building)
	return building

func _command(game: Node2D, kind: String) -> Dictionary:
	for command in game.player_actions.descriptors:
		if command.get("kind", "") == kind: return command
	return {}

func _assert_grid(game: Node2D) -> void:
	var expected := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B]
	var occupied: Dictionary = {}
	for command in game.player_actions.descriptors:
		if not command.get("visible", false):
			assert(command.get("keycode", KEY_NONE) == KEY_NONE, "hidden commands must have no shortcut")
			continue
		if not command.has("id"): continue
		var keycode: int = expected[command["slot"]]
		assert(command["keycode"] == keycode, "shortcut must match visible grid position")
		assert(game.player_actions.hotkeys[keycode] == command["id"])
		occupied[keycode] = true
	assert(game.player_actions.hotkeys.size() == occupied.size(), "only occupied visible slots may bind keys")
