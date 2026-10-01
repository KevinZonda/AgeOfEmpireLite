extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# Destruction cues are unrelated to this headless HUD test.
	game.feedback_audio.free()
	game.feedback_audio = null
	game.start_game("English", 4242)
	game.paused = true
	var worker: RtsUnit = game.units[0]
	var center: RtsBuilding = game._player_center(0)
	_select(game, worker)
	var house_button := _button(game, "build", "house")
	assert(_count(house_button) == 0, "unowned building types should show zero")
	var site: RtsBuilding = game.spawn_building(0, "house", center.position + Vector2(180, 0), true)
	game.spawn_building(1, "house", center.position + Vector2(360, 0))
	await _settle()
	assert(_count(house_button) == 1, "construction sites count immediately; enemy buildings do not")
	game.entity_destroyed(site)
	await _settle()
	assert(_count(house_button) == 0, "destroyed buildings should disappear from the count without reselection")
	_select(game, center)
	var villager_button := _button(game, "train", "villager")
	var initial := _count(villager_button)
	center.enqueue("villager")
	game.session.changes.mark(0, &"production")
	await _settle()
	assert(_count(villager_button) == initial, "production queues are not existing units")
	var new_worker: RtsUnit = game.spawn_unit(0, "villager", center.position + Vector2(80, 0))
	game.spawn_unit(1, "villager", center.position + Vector2(160, 0))
	await _settle()
	assert(_count(villager_button) == initial + 1, "new owned units should update the count without reselection")
	assert(center.garrison_unit(new_worker), "fixture worker should be able to garrison")
	game.session.changes.mark(0, &"entities")
	await _settle()
	assert(_count(villager_button) == initial + 1, "garrisoned units remain owned")
	center.ungarrison_all()
	game.entity_destroyed(new_worker)
	await _settle()
	assert(_count(villager_button) == initial, "unit deaths should update the count without reselection")
	var blacksmith: RtsBuilding = game.spawn_building(0, "blacksmith", center.position + Vector2(180, 180))
	_select(game, blacksmith)
	for button in game.command_buttons:
		assert(not button.has_node("OwnedCountBadge"), "research icons should not show entity counts")
	_select(game, worker)
	for scales in [Vector2(1, 1), Vector2(1, 2), Vector2(1.5, 1.75)]:
		game.ui_scale = scales.x
		game.text_scale = scales.y
		game._apply_ui_scales()
		await _settle()
		var button := _button(game, "build", "house")
		var count_badge: Label = button.get_node("OwnedCountBadge")
		var shortcut: Label = button.get_node("ShortcutBadge")
		assert(count_badge.position.x >= 0 and count_badge.position.y >= 0, "count should stay inside the top-left corner")
		assert(count_badge.get_rect().end.x <= button.size.x and count_badge.get_rect().end.y <= button.size.y, "count overlay should fit at every text scale")
		assert(shortcut.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT and shortcut.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM, "shortcut should retain its bottom-right position")
	game.queue_free()
	await _settle()
	print("HUD_OWNED_COUNTS_OK")
	quit()

func _select(game: Node, item: Node2D) -> void:
	game.selected.clear()
	game.selected.append(item)
	game.build_page = 0
	game._rebuild_actions()
	game._update_hud()

func _button(game: Node, action_type: String, kind: String) -> RtsCommandButton:
	for button in game.command_buttons:
		if button.get_meta("action_type") == action_type and button.get_meta("action_kind") == kind: return button
	assert(false, "missing command: %s/%s" % [action_type, kind])
	return null

func _count(button: RtsCommandButton) -> int:
	return int(button.get_node("OwnedCountBadge").text)

func _settle() -> void:
	for frame in 4: await process_frame
