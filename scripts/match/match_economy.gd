extends RefCounted

# Resource accounting and population rules for a running match. Game keeps
# forwarding methods so entity, AI, and test callers retain their current API.
static func credit_resource(game: Node2D, owner_id: int, kind: String, amount: int) -> void:
	game.session.player(owner_id).credit(kind, amount)
	game.match_statistics.record_income(owner_id, kind, amount)
	game.session.changes.mark(owner_id, &"resources")

static func market_quote(game: Node2D, resource_kind: String, buy: bool, owner_id: int) -> int:
	if not game.market_supply.has(resource_kind): return 0
	var sell_price := clampi(70 - int(game.market_supply[resource_kind]) * 5, 35, 110)
	var spread := 25 if game.civilizations[owner_id] == "French" else 40
	return sell_price + spread if buy else sell_price

static func exchange_resource(game: Node2D, owner_id: int, resource_kind: String, buy: bool) -> bool:
	if not game.market_supply.has(resource_kind) or game.find_nearest_owned_building(owner_id, "market", game.spawn_point_for(owner_id)) == null: return false
	var price: int = game.market_quote(resource_kind, buy, owner_id)
	if buy:
		if game.players[owner_id]["gold"] < price:
			game.session.changes.feedback(owner_id, "黄金不足，无法买入")
			return false
		game.players[owner_id]["gold"] -= price
		game.players[owner_id][resource_kind] += 100
		game.market_supply[resource_kind] = int(game.market_supply[resource_kind]) - 1
	else:
		if game.players[owner_id][resource_kind] < 100:
			game.session.changes.feedback(owner_id, "%s不足 100" % GameData.RESOURCE_LABELS[resource_kind])
			return false
		game.players[owner_id][resource_kind] -= 100
		game.players[owner_id]["gold"] += price
		game.market_supply[resource_kind] = int(game.market_supply[resource_kind]) + 1
	game.session.changes.begin_transaction()
	game.session.changes.mark(owner_id, &"resources")
	game.session.changes.mark(owner_id, &"market")
	game.session.changes.feedback(owner_id, "买入 100 %s" % GameData.RESOURCE_LABELS[resource_kind] if buy else "卖出 100 %s" % GameData.RESOURCE_LABELS[resource_kind])
	game.session.changes.end_transaction()
	return true

static func can_afford(game: Node2D, owner_id: int, cost: Dictionary) -> bool:
	return game.session.player(owner_id).can_afford(cost)

static func spend(game: Node2D, owner_id: int, cost: Dictionary) -> bool:
	if not game.session.player(owner_id).spend(cost): return false
	game.session.changes.mark(owner_id, &"resources")
	return true

static func population_used(game: Node2D, owner_id: int) -> int:
	var used := 0
	for unit in game.units:
		if is_instance_valid(unit) and unit.owner_id == owner_id: used += RtsBalanceData.population_cost(unit.kind)
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == owner_id:
			used += building.queued_population_cost()
	return used

static func population_cap(game: Node2D, owner_id: int) -> int:
	var cap := 0
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.is_complete():
			cap += building.definition()["pop"]
	return cap
