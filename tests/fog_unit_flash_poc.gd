extends SceneTree

# Reproduces a soldier drawing over explored fog at the edge of vision.
# A spearman's head is centered 10 world pixels above its ground anchor in 2D.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 12345)
	var scout: RtsUnit
	for unit in game.units:
		if unit.owner_id == 0 and unit.kind == "scout":
			scout = unit
			break
	scout.position = game.world_map.nearest_walkable_point(Vector2(900, 430))
	game.fog.update_visibility()
	scout.position = game.world_map.nearest_walkable_point(Vector2(900, 850))
	game.fog.update_visibility()

	var candidate := Vector2.INF
	for y in range(5, game.world_map.grid_size.y - 5):
		for x in range(5, game.world_map.grid_size.x - 5):
			var point: Vector2 = game.world_map.cell_center(Vector2i(x, y)) + Vector2(0, -23)
			var head := point + Vector2(0, -10)
			if not game.fog.can_see(0, point) or game.fog.can_see(0, head) or not game.fog.is_explored(0, head): continue
			if game.world_map.forest_patch_at(point) >= 0 or not game.navigation.can_occupy(point, 14.0, null, false, false): continue
			candidate = point
			break
		if candidate != Vector2.INF: break
	if candidate == Vector2.INF:
		push_error("FOG_UNIT_FLASH_POC_SETUP_FAILED: no visible/fog boundary found")
		quit(2)
		return

	var enemy: RtsUnit = game.spawn_unit(1, "spearman", candidate)
	var hidden_point := candidate + Vector2(0, -50)
	enemy.position = hidden_point
	game.fog.update_visibility()
	if enemy.visible or not game.fog.is_explored(0, hidden_point) or game.fog.can_see(0, hidden_point):
		push_error("FOG_UNIT_FLASH_POC_SETUP_FAILED: soldier must begin in explored fog")
		quit(2)
		return
	enemy.position = candidate
	game.fog.update_visibility()
	var head_point := enemy.position + Vector2(0, -10)
	var head_cell: Vector2i = game.world_map.cell_at(head_point)
	var alpha: float = game.fog.mask_image.get_pixelv(head_cell).a
	if not game.fog.can_detect_unit(0, enemy) or not game.fog.is_explored(0, head_point) or game.fog.can_see(0, head_point) or alpha <= 0.6:
		push_error("FOG_UNIT_FLASH_POC_SETUP_FAILED: anchor must be seen while head is in explored fog")
		quit(2)
		return
	if enemy.visible or game._entity_at(enemy.position) == enemy:
		print("FOG_UNIT_FLASH_REPRODUCED anchor=%s head=%s fog_alpha=%.2f" % [str(enemy.position), str(head_point), alpha])
		quit(1)
		return
	scout.position = enemy.position + Vector2(0, -50)
	game.fog.update_visibility()
	if not enemy.visible:
		push_error("FOG_UNIT_FLASH_REGRESSION: enemy stays hidden after its whole figure enters vision")
		quit(3)
		return
	print("FOG_UNIT_FLASH_FIXED")
	quit()
