extends RefCounted

# One target query and one priority table serve both preview and execution.
static func targets(game: Node2D, point: Vector2) -> Dictionary:
	return {"entity": game._entity_at(point), "resource": game._resource_at(point),
		"post": game._trade_post_at(point), "relic": game._relic_at(point),
		"ground_point": RtsIsoProjection.ground_point(game, point)}

static func kind_for_unit(game: Node2D, subject: RtsUnit, context: Dictionary) -> String:
	var entity: Node2D = context["entity"]
	var resource: RtsResource = context["resource"]
	var post: RtsTradePost = context["post"]
	var relic: RtsRelic = context["relic"]
	if entity is RtsBuilding and entity.kind == "stone_wall" and subject.kind == "siege_tower" and game.is_enemy(subject.owner_id, entity.owner_id):
		return "assault_wall"
	elif entity is RtsBuilding and entity.kind == "stone_wall" and RtsSiegeRules.wall_entry(game, subject, entity) != null:
		return "board_wall"
	elif entity is RtsUnit and entity.kind in ["transport_ship", "battering_ram", "siege_tower"] and entity.owner_id == 0 and subject != entity and not subject.stats.get("tags", []).has("naval") and not subject.stats.get("tags", []).has("siege"):
		return "board_transport"
	elif subject.kind == "transport_ship" and game.world_map.is_walkable(context["ground_point"]) and not subject.passengers.is_empty():
		return "unload"
	elif post != null and subject.kind == "trader":
		return "trade"
	elif relic != null and subject.kind == "monk":
		return "relic"
	elif entity is RtsBuilding and entity.owner_id == 0 and entity.kind == "monastery" and subject.kind == "monk" and subject.carried_relic != null:
		return "deposit_relic"
	elif entity != null and game.is_enemy(0, entity.owner_id):
		return "attack"
	elif resource != null and resource.appearance == "boar" and resource.wildlife_hp > 0.0 and subject.attack_damage() > 0.0:
		return "attack"
	elif entity is RtsBuilding and entity.owner_id == 0 and not entity.is_complete() and subject.kind == "villager":
		return "build"
	elif entity != null and entity.owner_id == 0 and subject.kind == "villager" and (entity is RtsBuilding or entity is RtsUnit and entity.stats.get("tags", []).has("siege")) and entity.hp < entity.max_hp:
		return "repair"
	elif resource != null and (subject.kind == "villager" and resource.appearance != "fish" or subject.kind == "fishing_boat" and resource.appearance == "fish"):
		return "gather"
	elif entity is RtsBuilding and entity.owner_id == 0 and entity.kind == "farm" and subject.kind == "villager":
		return "gather"
	elif entity is RtsBuilding and entity.owner_id == 0 and entity.is_complete() and subject.kind == "imperial_official":
		return "supervise"
	elif entity is RtsBuilding and entity.owner_id == 0 and entity.is_complete() and (RtsSiegeRules.can_garrison(subject.stats, entity.kind) or entity.kind == "landmark" and entity.garrison_capacity() > 0 and not subject.stats.get("tags", []).has("siege")):
		return "garrison"
	else:
		return "move"

const CURSORS := {"assault_wall": "board", "board_wall": "board", "board_transport": "board", "unload": "unload", "trade": "trade", "relic": "relic", "deposit_relic": "relic", "attack": "attack", "build": "construct", "repair": "construct", "gather": "gather", "supervise": "construct", "garrison": "board", "move": "move"}
const CURSOR_PRIORITY := ["attack", "board", "construct", "gather", "trade", "relic", "unload", "move"]

static func for_unit(game: Node2D, subject: RtsUnit, context: Dictionary) -> Dictionary:
	var kind := kind_for_unit(game, subject, context)
	var target: Node2D = context["entity"]
	if kind == "trade": target = context["post"]
	elif kind == "relic": target = context["relic"]
	elif kind == "gather":
		var resource: RtsResource = context["resource"]
		if resource != null and (subject.kind == "villager" and resource.appearance != "fish" or subject.kind == "fishing_boat" and resource.appearance == "fish"): target = resource
	elif kind == "attack" and (target == null or not game.is_enemy(0, target.owner_id)):
		target = context["resource"]
	elif kind in ["move", "unload"]: target = null
	return {"type": kind, "point": context["ground_point"] if kind in ["move", "unload"] else Vector2.INF,
		"target": target, "hunt": kind == "attack" and target is RtsResource and subject.kind == "villager"}

static func cursor_for(game: Node2D, context: Dictionary) -> String:
	var chosen := "default"
	var rank := 99
	var producer := false
	for subject in game.selected:
		if not is_instance_valid(subject): continue
		if subject is RtsUnit and subject.owner_id == 0:
			var cursor: String = CURSORS[kind_for_unit(game, subject, context)]
			var priority := CURSOR_PRIORITY.find(cursor)
			if priority >= 0 and priority < rank:
				chosen = cursor
				rank = priority
				if rank == 0: return chosen
		elif subject is RtsBuilding and subject.can_set_rally(0): producer = true
	if chosen != "default": return chosen
	var entity: Node2D = context["entity"]
	if entity != null or context["resource"] != null: return "select"
	return "rally" if producer else "default"
