class_name RtsMatchStatistics
extends RefCounted

const SAMPLE_INTERVAL := 5.0
const CONTROL_COLUMNS := 10
const CONTROL_ROWS := 6

var game: Node2D
var elapsed := 0.0
var until_sample := SAMPLE_INTERVAL
var samples: Array[Dictionary] = []
var events: Array[Dictionary] = []
var collected: Array[Dictionary] = []

func reset(game_ref: Node2D) -> void:
	game = game_ref
	elapsed = 0.0
	until_sample = SAMPLE_INTERVAL
	samples.clear()
	events.clear()
	collected.clear()
	for owner_id in game.players.size():
		collected.append({"food": 0, "wood": 0, "gold": 0, "stone": 0})
	sample()

func tick(delta: float) -> void:
	elapsed += delta
	until_sample -= delta
	if until_sample <= 0.0:
		until_sample += SAMPLE_INTERVAL
		sample()

func record_income(owner_id: int, kind: String, amount: int) -> void:
	if owner_id >= 0 and owner_id < collected.size() and collected[owner_id].has(kind):
		collected[owner_id][kind] += amount

func record_event(owner_id: int, label: String) -> void:
	events.append({"time": elapsed, "owner": owner_id, "label": label})

func sample() -> void:
	if game == null or game.players.is_empty(): return
	var players: Array[Dictionary] = []
	var unit_states: Array[Dictionary] = []
	var building_states: Array[Dictionary] = []
	for owner_id in game.players.size():
		var player: Dictionary = game.players[owner_id]
		var stock := 0
		var total_income := 0
		for kind in GameData.RESOURCE_NAMES:
			stock += int(player.get(kind, 0))
			total_income += int(collected[owner_id].get(kind, 0))
		players.append({"stock": stock, "income": total_income, "population": 0, "military": 0, "technology": player.get("researched", []).size(), "control": 0})
	for unit in game.units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.garrisoned_in != null: continue
		if unit.owner_id < 0 or unit.owner_id >= players.size(): continue
		players[unit.owner_id]["population"] += RtsBalanceData.population_cost(unit.kind)
		if unit.stats.get("tags", []).has("military"): players[unit.owner_id]["military"] += 1
		unit_states.append({"position": unit.position, "owner": unit.owner_id, "kind": unit.kind, "hp": unit.hp / maxf(1.0, unit.max_hp)})
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		building_states.append({"position": building.position, "owner": building.owner_id, "kind": building.kind, "hp": building.hp / maxf(1.0, building.max_hp)})
	for cy in CONTROL_ROWS:
		for cx in CONTROL_COLUMNS:
			var center := Vector2((cx + 0.5) / CONTROL_COLUMNS * game.world_size.x, (cy + 0.5) / CONTROL_ROWS * game.world_size.y)
			var owner := -1
			var nearest := 250.0 * 250.0
			for unit in unit_states:
				if not GameData.UNITS.get(unit["kind"], {}).get("tags", []).has("military"): continue
				var distance: float = center.distance_squared_to(unit["position"])
				if distance < nearest:
					nearest = distance
					owner = unit["owner"]
			for building in building_states:
				var distance: float = center.distance_squared_to(building["position"])
				if distance < nearest:
					nearest = distance
					owner = building["owner"]
			if owner >= 0: players[owner]["control"] += 100.0 / (CONTROL_COLUMNS * CONTROL_ROWS)
	samples.append({"time": elapsed, "players": players, "units": unit_states, "buildings": building_states})

func nearest_sample_index(time_seconds: float) -> int:
	if samples.is_empty(): return -1
	var best := 0
	var distance := INF
	for index in samples.size():
		var candidate := absf(float(samples[index]["time"]) - time_seconds)
		if candidate < distance:
			distance = candidate
			best = index
	return best
