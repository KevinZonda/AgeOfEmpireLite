extends SceneTree

const Session = preload("res://scripts/match/match_session.gd")
const EntityQueries = preload("res://scripts/match/match_entity_queries.gd")
const Economy = preload("res://scripts/match/match_economy.gd")
const Production = preload("res://scripts/match/match_production.gd")

# Deliberately not RtsBuilding or a scene node. This is the complete producer
# contract used by the transactions and the narrow registry queries.
class Producer extends RefCounted:
	var owner_id := 0
	var kind := "town_center"
	var landmark_id := ""
	var position := Vector2.ZERO
	var complete := true
	var landmark_ability_cooldown := 0.0
	var landmark_stockpile := {}
	var production_queue: Array[Dictionary] = []
	var refreshes := 0
	func producer_kind() -> String: return kind
	func is_complete() -> bool: return complete
	func definition() -> Dictionary: return {"pop": 10 if kind == "town_center" else 0}
	func enqueue(unit_kind: String, paid_cost: Dictionary) -> void:
		production_queue.append({"type": "train", "kind": unit_kind, "cost": paid_cost.duplicate(true)})
	func enqueue_research(tech_id: String, time: float, paid_cost: Dictionary) -> void:
		production_queue.append({"type": "research", "kind": tech_id, "time": time, "cost": paid_cost.duplicate(true)})
	func cancel_queue_entry(index: int) -> Dictionary:
		if index >= production_queue.size(): return {}
		var job := production_queue[index]
		production_queue.remove_at(index)
		return job
	func queued_population_cost() -> int:
		var count := 0
		for job in production_queue:
			if job["type"] == "train": count += RtsBalanceData.population_cost(job["kind"])
		return count
	func queued_unit_count(unit_kind: String) -> int:
		var count := 0
		for job in production_queue:
			if job["type"] == "train" and job["kind"] == unit_kind: count += 1
		return count
	func queued_research_ids() -> Array[String]:
		var ids: Array[String] = []
		for job in production_queue:
			if job["type"] == "research": ids.append(job["kind"])
		return ids
	func refresh_stats() -> void: refreshes += 1

class Unit extends RefCounted:
	var owner_id := 0
	var kind := "spearman"
	var refreshes := 0
	func refresh_stats() -> void: refreshes += 1

class Registry extends RefCounted:
	var units: Array = []
	var buildings: Array = []

class Fixture extends RefCounted:
	var session = Session.new()
	var registry = Registry.new()
	var queries = EntityQueries.new(registry)
	var economy = Economy.new(session, queries)
	var production = Production.new(session, economy, queries)
	var commits: Array[Dictionary] = []
	func _init(civilization := "French") -> void:
		session.configure_players(civilization, "English", "duel", [], 1)
		for resource in GameData.RESOURCE_NAMES: session.player(0).credit(resource, 5000)
		session.changes.changed.connect(func(owner_id: int, domains: Array[StringName]) -> void:
			commits.append({"owner": owner_id, "domains": domains, "bank": session.player(owner_id).bank.duplicate(true),
				"population": economy.population_used(owner_id), "market": session.market_supply.duplicate(true),
				"refreshes": registry.buildings[0].refreshes if not registry.buildings.is_empty() else 0}))
	func dispose() -> void:
		for connection in session.changes.changed.get_connections(): session.changes.changed.disconnect(connection["callable"])
		for connection in production.unit_spawn_requested.get_connections(): production.unit_spawn_requested.disconnect(connection["callable"])
	func producer(kind: String) -> Producer:
		var result := Producer.new()
		result.kind = kind
		registry.buildings.append(result)
		return result

func _initialize() -> void:
	_test_training_discount_and_refund()
	_test_market_commit()
	_test_progression_and_research_reward()
	_test_population_and_official_limits()
	print("MATCH_SERVICES_OK")
	quit()

func _test_training_discount_and_refund() -> void:
	var f := Fixture.new()
	f.production.complete_age(0, 2)
	f.producer("town_center")
	var stable := f.producer("stable")
	var keep := f.producer("keep")
	var status: Dictionary = f.production.availability(stable, "train", "royal_knight")
	assert(status["available"] and status["cost"] == {"food": 112, "gold": 80})
	var food: int = f.session.players[0]["food"]
	f.commits.clear()
	assert(f.production.train_unit(stable, "royal_knight"))
	assert(f.commits.size() == 1 and f.commits[0]["bank"]["food"] == food - 112 and f.commits[0]["population"] == 1)
	assert(f.commits[0]["domains"].has(&"resources") and f.commits[0]["domains"].has(&"production"))
	keep.position = Vector2(500, 0)
	assert(f.production.availability(stable, "train", "royal_knight")["cost"]["food"] == 140)
	assert(f.production.cancel_job(stable, 0))
	assert(f.commits.size() == 2 and f.commits[-1]["bank"]["food"] == food and f.commits[-1]["population"] == 0, "refund uses the paid discounted cost, not today's full cost")
	assert(not f.production.cancel_job(stable, 0) and f.commits.size() == 2)
	var replacement: Dictionary = f.session.players[0].duplicate(true)
	f.session.players[0] = replacement
	assert(is_same(f.session.player(0).bank, replacement))
	var before: Dictionary = f.session.player(0).bank.duplicate(true)
	assert(not f.economy.spend(0, {"food": 1, "gold": int(before["gold"]) + 1}))
	assert(f.session.player(0).bank == before and f.commits.size() == 2, "unaffordable multi-resource spending must reject without a partial payment")
	f.session.game_over = true
	assert(not f.production.train_unit(stable, "royal_knight") and f.commits.size() == 2)

	f.dispose()

func _test_market_commit() -> void:
	var f := Fixture.new()
	assert(not f.economy.exchange_resource(0, "food", true) and f.commits.is_empty())
	var market := f.producer("market")
	market.complete = false
	var before: Dictionary = f.session.player(0).bank.duplicate(true)
	assert(not f.economy.exchange_resource(0, "food", true) and f.commits.is_empty(), "an unfinished market cannot exchange resources")
	assert(f.session.player(0).bank == before and f.session.market_supply["food"] == 0)
	market.complete = true
	var gold: int = f.session.players[0]["gold"]
	var food: int = f.session.players[0]["food"]
	assert(f.economy.market_quote("food", true, 0) == 95)
	assert(f.economy.exchange_resource(0, "food", true))
	assert(f.commits.size() == 1 and f.commits[0]["bank"]["gold"] == gold - 95 and f.commits[0]["bank"]["food"] == food + 100 and f.commits[0]["market"]["food"] == -1)
	assert(f.commits[0]["domains"].has(&"market") and f.commits[0]["domains"].has(&"resources"))
	assert(f.economy.exchange_resource(0, "food", false))
	assert(f.session.players[0]["gold"] == gold - 20 and f.session.market_supply["food"] == 0)
	f.session.players[0]["gold"] = 0
	assert(not f.economy.exchange_resource(0, "food", true) and f.commits.size() == 2)
	assert(not f.economy.exchange_resource(0, "gold", true) and f.commits.size() == 2)

	f.dispose()

func _test_progression_and_research_reward() -> void:
	var f := Fixture.new()
	var center := f.producer("town_center")
	var unit := Unit.new()
	f.registry.units.append(unit)
	var bank: Dictionary = f.session.players[0]
	f.production.complete_age(0, 3)
	assert(f.commits.is_empty(), "skipped ages do not mutate state")
	f.production.complete_age(0, 2, "fr_chamber_of_commerce")
	assert(is_same(bank, f.session.player(0).bank) and bank["age"] == 2 and bank["researched"].has("melee_attack_2"))
	assert(f.commits.size() == 1 and f.commits[0]["domains"].has(&"age") and f.commits[0]["domains"].has(&"research") and f.commits[0]["domains"].has(&"landmarks"))
	assert(center.refreshes == 1 and unit.refreshes == 1 and f.commits[0]["refreshes"] == 1)
	f.production.complete_age(0, 2, "fr_chamber_of_commerce")
	assert(f.commits.size() == 1)
	var chamber := f.producer("market")
	chamber.landmark_id = "fr_chamber_of_commerce"
	f.production.unit_spawn_requested.connect(func(owner_id: int, kind: String, producer: Object) -> void:
		assert(owner_id == 0 and kind == "trader" and producer == chamber)
		var trader := Unit.new()
		trader.kind = kind
		f.registry.units.append(trader)
		f.session.changes.mark(owner_id, &"entities"))
	var mill := f.producer("mill")
	assert(f.production.research_technology(mill, "horticulture"))
	assert(mill.production_queue[0]["cost"] == {"food": 70, "gold": 53}, "French economy research discount must apply")
	assert(not f.production.research_technology(mill, "horticulture"))
	f.commits.clear()
	f.production.complete_research(0, "horticulture")
	assert(f.commits.size() == 1 and f.commits[0]["population"] == 2 and f.commits[0]["domains"].has(&"entities") and f.commits[0]["domains"].has(&"research"))
	f.production.complete_research(0, "horticulture")
	assert(f.commits.size() == 1 and f.registry.units.size() == 2)
	var chinese := Fixture.new("Chinese")
	chinese.producer("town_center")
	chinese.production.complete_age(0, 2, "zh_imperial_academy")
	chinese.production.complete_age(0, 2, "zh_barbican")
	assert(chinese.session.players[0]["age"] == 2 and chinese.session.players[0]["dynasty"] == "Song")
	assert(chinese.commits.size() == 2 and chinese.commits[-1]["domains"].has(&"dynasty") and chinese.commits[-1]["domains"].has(&"landmarks"))
	chinese.production.complete_age(0, 2, "zh_barbican")
	assert(chinese.commits.size() == 2)

	f.dispose()
	chinese.dispose()

func _test_population_and_official_limits() -> void:
	var f := Fixture.new("Chinese")
	var center := f.producer("town_center")
	for index in 4: assert(f.production.train_unit(center, "imperial_official"))
	assert(not f.production.train_unit(center, "imperial_official"))
	assert(f.production.cancel_job(center, 0) and f.production.train_unit(center, "imperial_official"))
	for index in 6: assert(f.production.train_unit(center, "villager"))
	assert(f.economy.population_used(0) == 10 and not f.production.train_unit(center, "villager"))
	assert(f.production.cancel_job(center, 0) and f.production.train_unit(center, "villager"))
	center.complete = false
	assert(not f.production.train_unit(center, "villager"))
	f.dispose()
