extends RefCounted

# Owns live entity collections and the lifecycle operations that maintain them.
# Presentation and defeat policy stay explicit; all registrations go here.
const UNIT_SCENE = preload("res://scripts/entities/unit.gd")
const BUILDING_SCENE = preload("res://scripts/entities/building.gd")
const RESOURCE_SCENE = preload("res://scripts/entities/resource_node.gd")
var _game: WeakRef
var game: Node2D:
	get: return _game.get_ref()
var units: Array[RtsUnit] = []
var buildings: Array[RtsBuilding] = []
var resources: Array[RtsResource] = []
var trade_posts: Array[RtsTradePost] = []
var relics: Array[RtsRelic] = []

func _init(game_ref: Node2D) -> void:
	_game = weakref(game_ref)

func clear() -> void:
	for collection in [units, buildings, resources, trade_posts, relics]:
		for entity in collection:
			if is_instance_valid(entity): entity.queue_free()
		collection.clear()

func register(entity: Node2D) -> void:
	var collection: Array = _collection_for(entity)
	if collection.has(entity): return
	collection.append(entity)
	if entity is RtsUnit:
		game.navigation.invalidate_spatial_index()
		if game.fog.active: game.fog.update_unit_display(entity)
	elif entity is RtsBuilding:
		game.navigation.invalidate_obstacles()
		if game.fog.active: game.fog.update_building_display(entity)
	elif entity is RtsResource:
		game.navigation.invalidate_obstacles()
	entity.tree_exiting.connect(unregister.bind(entity), CONNECT_ONE_SHOT)

func unregister(entity: Node2D) -> void:
	var collection: Array = _collection_for(entity)
	if not collection.has(entity): return
	collection.erase(entity)
	if game == null or game.is_queued_for_deletion(): return
	game.selected.erase(entity)
	if entity is RtsUnit: game.navigation.invalidate_spatial_index()
	elif entity is RtsBuilding or entity is RtsResource: game.navigation.invalidate_obstacles()

func _collection_for(entity: Node2D) -> Array:
	if entity is RtsUnit: return units
	if entity is RtsBuilding: return buildings
	if entity is RtsResource: return resources
	if entity is RtsTradePost: return trade_posts
	return relics

func spawn_resource(kind: String, world_point: Vector2, amount: int, appearance := "") -> RtsResource:
	var resource: RtsResource = RESOURCE_SCENE.new()
	resource.position = world_point
	resource.game = game
	game.add_child(resource)
	resource.setup(kind, amount, appearance)
	register(resource)
	return resource

func spawn_unit(owner_id: int, kind: String, world_point: Vector2, rally := Vector2.INF, rally_target: Node2D = null, rally_resource_kind := "") -> RtsUnit:
	var unit: RtsUnit = UNIT_SCENE.new()
	unit.position = game.world_map.nearest_water_point(world_point) if GameData.UNITS[kind]["tags"].has("naval") else game.world_map.nearest_walkable_point(world_point)
	game.add_child(unit)
	unit.setup(game, owner_id, kind)
	unit.position = game.navigation.nearest_walkable_point(unit.position, unit.radius(), unit)
	register(unit)
	if rally != Vector2.INF:
		if kind == "trader" and rally_target is RtsTradePost:
			unit.issue_command("trade", Vector2.INF, rally_target)
		elif kind == "fishing_boat" and rally_target is RtsResource and rally_target.appearance == "fish":
			unit.issue_command("gather", Vector2.INF, rally_target)
		elif kind == "villager" and is_instance_valid(rally_target) and not rally_target.is_queued_for_deletion() and (rally_target is RtsResource or rally_target is RtsBuilding and rally_target.kind == "farm" and rally_target.is_complete()):
			unit.issue_command("gather", Vector2.INF, rally_target)
		elif kind == "villager" and rally_resource_kind != "":
			var replacement: RtsResource = game.find_nearest_resource(rally, rally_resource_kind, 220.0, owner_id)
			if replacement != null: unit.issue_command("gather", Vector2.INF, replacement)
			else: unit.issue_command("move", rally)
		else: unit.issue_command("move", rally)
	game._update_hud()
	return unit

func spawn_building(owner_id: int, kind: String, world_point: Vector2, under_construction := false, landmark_id := "", vertical := false) -> RtsBuilding:
	var building: RtsBuilding = BUILDING_SCENE.new()
	building.position = game.snap_build_point(kind, world_point, vertical)
	building.wall_vertical = vertical
	game.add_child(building)
	building.setup(game, owner_id, kind, under_construction, landmark_id)
	register(building)
	game._update_hud()
	return building

func entity_destroyed(entity: Node2D) -> void:
	if not is_instance_valid(entity) or entity.is_queued_for_deletion(): return
	if not game.fog.active or game.fog.can_see(0, entity.position):
		game.world_effects.append({"point": entity.position, "kind": "death" if entity is RtsUnit else "collapse", "color": game.player_color(entity.owner_id), "time": 0.9})
		if entity.owner_id == 0 and entity is RtsUnit: game.play_feedback("alert")
	game.selected.erase(entity)
	if entity is RtsUnit:
		if not entity.passengers.is_empty(): entity.ungarrison_all()
		units.erase(entity)
		game.navigation.invalidate_spatial_index()
	elif entity is RtsBuilding:
		if entity.kind in ["town_center", "landmark", "wonder", "keep"]:
			game.match_statistics.record_event(entity.owner_id, "%s被摧毁" % entity.display_label())
		for unit in units:
			if is_instance_valid(unit) and unit.wall_host == entity: unit.leave_wall()
		for relic in entity.relics:
			if is_instance_valid(relic):
				relic.stored_in = null
				relic.position = game.world_map.nearest_walkable_point(entity.position + Vector2(65, 0))
		entity.relics.clear()
		entity.ungarrison_all()
		game.objectives.on_building_destroyed(entity)
		buildings.erase(entity)
		game.navigation.invalidate_obstacles()
		if entity.landmark_id == "zh_gatehouse":
			for building in buildings:
				if is_instance_valid(building) and building.owner_id == entity.owner_id and building.kind in ["stone_wall", "stone_gate"]: building.refresh_stats()
		if entity.kind == "town_center" or entity.kind == "landmark":
			var has_landmark := false
			for building in buildings:
				if is_instance_valid(building) and building.owner_id == entity.owner_id and building.is_complete() and (building.kind == "town_center" or building.kind == "landmark"):
					has_landmark = true
					break
			if not has_landmark:
				game.defeated_players.append(entity.owner_id)
				eliminate_player(entity.owner_id)
				game._check_match_end()
	entity.queue_free()
	game._rebuild_actions()
	game._update_hud()

func eliminate_player(owner_id: int) -> void:
	for unit in units.duplicate():
		if is_instance_valid(unit) and unit.owner_id == owner_id:
			game.selected.erase(unit)
			units.erase(unit)
			unit.queue_free()
	for building in buildings.duplicate():
		if is_instance_valid(building) and building.owner_id == owner_id:
			for relic in building.relics:
				if is_instance_valid(relic):
					relic.stored_in = null
					relic.position = game.world_map.nearest_walkable_point(building.position + Vector2(60, 0))
			building.relics.clear()
			game.objectives.on_building_destroyed(building)
			game.selected.erase(building)
			buildings.erase(building)
			building.queue_free()
	game.navigation.refresh()
	if game.fog.active: game.fog.update_visibility()

func spawn_neutral_sites() -> void:
	for desired in game.world_map.trade_post_positions():
		var post := RtsTradePost.new()
		post.game = game
		post.position = desired
		game.add_child(post)
		register(post)
	for site in game.objectives.sacred_sites:
		var relic := RtsRelic.new()
		relic.position = game.world_map.nearest_walkable_point(site["position"] + Vector2(70, 45))
		relic.game = game
		game.add_child(relic)
		register(relic)
