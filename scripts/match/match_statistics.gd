class_name RtsMatchStatistics
extends RefCounted

const SAMPLE_INTERVAL := 5.0
const CONTROL_COLUMNS := 10
const CONTROL_ROWS := 6
const CONTROL_RADIUS := 250.0
# Replay history is bounded: past this many samples the oldest half is
# decimated 2:1, so full 5s resolution covers the first 30 minutes and older
# history progressively thins (10s, 20s, ... spacing) instead of growing
# forever. Times stay on each sample, so the chart timeline remains correct.
const MAX_RETAINED_SAMPLES := 360

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
	# Control ownership is stamped in a single pass over entities: each military
	# unit and building only visits the handful of control cells whose center
	# can lie within CONTROL_RADIUS, instead of every cell scanning every entity.
	var control_nearest := PackedFloat32Array()
	control_nearest.resize(CONTROL_COLUMNS * CONTROL_ROWS)
	control_nearest.fill(CONTROL_RADIUS * CONTROL_RADIUS)
	var control_owner := PackedInt32Array()
	control_owner.resize(CONTROL_COLUMNS * CONTROL_ROWS)
	control_owner.fill(-1)
	for unit in game.units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.garrisoned_in != null: continue
		if unit.owner_id < 0 or unit.owner_id >= players.size(): continue
		players[unit.owner_id]["population"] += RtsBalanceData.population_cost(unit.kind)
		if unit.stats.get("tags", []).has("military"): players[unit.owner_id]["military"] += 1
		unit_states.append({"position": unit.position, "owner": unit.owner_id, "kind": unit.kind, "hp": unit.hp / maxf(1.0, unit.max_hp)})
		if GameData.UNITS.get(unit.kind, {}).get("tags", []).has("military"): _stamp_control(control_owner, control_nearest, unit.position, unit.owner_id)
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		building_states.append({"position": building.position, "owner": building.owner_id, "kind": building.kind, "hp": building.hp / maxf(1.0, building.max_hp)})
		_stamp_control(control_owner, control_nearest, building.position, building.owner_id)
	for index in control_owner.size():
		var owner := control_owner[index]
		if owner >= 0: players[owner]["control"] += 100.0 / (CONTROL_COLUMNS * CONTROL_ROWS)
	samples.append({"time": elapsed, "players": players, "units": unit_states, "buildings": building_states})
	_decimate_samples()

func _stamp_control(control_owner: PackedInt32Array, control_nearest: PackedFloat32Array, position: Vector2, owner: int) -> void:
	var cell_w: float = game.world_size.x / CONTROL_COLUMNS
	var cell_h: float = game.world_size.y / CONTROL_ROWS
	var first_x := clampi(floori((position.x - CONTROL_RADIUS) / cell_w - 0.5), 0, CONTROL_COLUMNS - 1)
	var last_x := clampi(floori((position.x + CONTROL_RADIUS) / cell_w - 0.5), 0, CONTROL_COLUMNS - 1)
	var first_y := clampi(floori((position.y - CONTROL_RADIUS) / cell_h - 0.5), 0, CONTROL_ROWS - 1)
	var last_y := clampi(floori((position.y + CONTROL_RADIUS) / cell_h - 0.5), 0, CONTROL_ROWS - 1)
	for cy in range(first_y, last_y + 1):
		for cx in range(first_x, last_x + 1):
			var center := Vector2((cx + 0.5) * cell_w, (cy + 0.5) * cell_h)
			var index := cy * CONTROL_COLUMNS + cx
			var distance: float = center.distance_squared_to(position)
			if distance < control_nearest[index]:
				control_nearest[index] = distance
				control_owner[index] = owner

# Keep replay memory bounded without dropping the timeline: once the cap is
# exceeded, thin the oldest half 2:1. Decimation always targets the oldest
# segment, so spacing there doubles each round while recent samples keep full
# resolution, and samples stay ordered by time for binary search.
func _decimate_samples() -> void:
	if samples.size() <= MAX_RETAINED_SAMPLES: return
	var half := samples.size() / 2
	var kept: Array[Dictionary] = []
	kept.resize(samples.size() - half / 2)
	var write := 0
	for index in range(0, half, 2):
		kept[write] = samples[index]
		write += 1
	for index in range(half, samples.size()):
		kept[write] = samples[index]
		write += 1
	samples = kept

func nearest_sample_index(time_seconds: float) -> int:
	if samples.is_empty(): return -1
	var low := 0
	var high := samples.size() - 1
	while low < high:
		var mid := (low + high) / 2
		if float(samples[mid]["time"]) < time_seconds: low = mid + 1
		else: high = mid
	if low > 0 and absf(float(samples[low - 1]["time"]) - time_seconds) <= absf(float(samples[low]["time"]) - time_seconds): return low - 1
	return low
