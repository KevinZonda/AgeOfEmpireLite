extends RefCounted

# Accounting depends only on session state and entity queries. The assembly
# subscribes to income facts; this service never addresses HUD or the game root.
signal resource_credited(owner_id: int, kind: String, amount: int)
var _session: RefCounted
var _entities: RefCounted

func _init(session: RefCounted, entities: RefCounted) -> void:
	_session = session
	_entities = entities

func credit_resource(owner_id: int, kind: String, amount: int) -> void:
	_session.changes.begin_transaction()
	_session.player(owner_id).credit(kind, amount)
	resource_credited.emit(owner_id, kind, amount)
	_session.changes.mark(owner_id, &"resources")
	_session.changes.end_transaction()

func market_quote(resource_kind: String, buy: bool, owner_id: int) -> int:
	if not _session.market_supply.has(resource_kind): return 0
	var sell_price := clampi(70 - int(_session.market_supply[resource_kind]) * 5, 35, 110)
	var spread := 25 if _session.civilizations[owner_id] == "French" else 40
	return sell_price + spread if buy else sell_price

func exchange_resource(owner_id: int, resource_kind: String, buy: bool) -> bool:
	if not _session.market_supply.has(resource_kind) or not _entities.has_building(owner_id, "market", true): return false
	var price := market_quote(resource_kind, buy, owner_id)
	var cost := {"gold": price} if buy else {resource_kind: 100}
	var state = _session.player(owner_id)
	if not state.can_afford(cost):
		_session.changes.feedback(owner_id, "黄金不足，无法买入" if buy else "%s不足 100" % GameData.RESOURCE_LABELS[resource_kind])
		return false
	_session.changes.begin_transaction()
	state.spend(cost)
	state.credit(resource_kind if buy else "gold", 100 if buy else price)
	_session.market_supply[resource_kind] = int(_session.market_supply[resource_kind]) + (-1 if buy else 1)
	_session.changes.mark(owner_id, &"resources")
	_session.changes.mark(owner_id, &"market")
	_session.changes.feedback(owner_id, "买入 100 %s" % GameData.RESOURCE_LABELS[resource_kind] if buy else "卖出 100 %s" % GameData.RESOURCE_LABELS[resource_kind])
	_session.changes.end_transaction()
	return true

func can_afford(owner_id: int, cost: Dictionary) -> bool:
	return _session.player(owner_id).can_afford(cost)

func spend(owner_id: int, cost: Dictionary) -> bool:
	if not _session.player(owner_id).spend(cost): return false
	_session.changes.mark(owner_id, &"resources")
	return true

func population_used(owner_id: int) -> int:
	return _entities.population_used(owner_id)

func population_cap(owner_id: int) -> int:
	return _entities.population_cap(owner_id)
