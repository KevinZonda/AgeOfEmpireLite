extends RefCounted

const PlayerState = preload("res://scripts/match/player_state.gd")
const EntityRegistry = preload("res://scripts/match/entity_registry.gd")
const MatchChanges = preload("res://scripts/match/match_changes.gd")
const INITIAL_RESOURCES := [
	{"food": 200, "wood": 220, "gold": 100, "stone": 0},
	{"food": 340, "wood": 360, "gold": 150, "stone": 100},
	{"food": 700, "wood": 700, "gold": 400, "stone": 300},
]

var entities: EntityRegistry
var changes := MatchChanges.new()
var world_size := Vector2(2400, 2400)
var civilizations := ["English", "French"]
var teams: Array[int] = [0, 1]
var match_mode := "duel"
var defeated_players: Array[int] = []
var players: Array[Dictionary] = []
var player_states: Array[PlayerState] = []
var market_supply := {"food": 0, "wood": 0, "stone": 0}
var map_seed := 0
var map_style := "balanced"
var started := false
var game_over := false
var paused := false

func _init(game_ref: Node2D = null) -> void:
	if game_ref != null: entities = EntityRegistry.new(game_ref)

func configure_players(civ: String, opponent: String, mode: String, lobby: Array, resource_preset: int) -> void:
	match_mode = mode
	teams.clear()
	civilizations.clear()
	players.clear()
	player_states.clear()
	defeated_players.clear()
	market_supply = {"food": 0, "wood": 0, "stone": 0}
	var ids := GameData.CIVILIZATIONS.keys()
	var count := lobby.size() if not lobby.is_empty() else 2 if mode == "duel" else 3 if mode == "ffa3" else 4
	for owner_id in count:
		teams.append(int(lobby[owner_id].get("team", owner_id + 1)) - 1 if not lobby.is_empty() else 0 if owner_id == 0 or mode == "team2" and owner_id == 2 else 1 if mode == "team2" else owner_id)
		civilizations.append(lobby[owner_id]["civilization"] if not lobby.is_empty() else civ if owner_id == 0 else ids[(ids.find(opponent) + owner_id - 1) % ids.size()])
		var bank := {"food": 340 if owner_id == 0 else 420, "wood": 360 if owner_id == 0 else 420, "gold": 150 if owner_id == 0 else 170, "stone": 100, "age": 1, "researched": [], "landmarks": [], "dynasty": "Tang" if civilizations[owner_id] == "Chinese" else ""}
		if not lobby.is_empty(): bank.merge(INITIAL_RESOURCES[clampi(resource_preset, 0, 2)], true)
		players.append(bank)
		player_states.append(PlayerState.new(bank))

func player(owner_id: int) -> PlayerState:
	# Accommodate legacy fixtures that replace the compatibility bank array.
	if player_states.size() != players.size():
		player_states.clear()
		for bank in players: player_states.append(PlayerState.new(bank))
	elif not is_same(player_states[owner_id].bank, players[owner_id]):
		player_states[owner_id] = PlayerState.new(players[owner_id])
	return player_states[owner_id]

func is_enemy(first: int, second: int) -> bool:
	return first >= 0 and second >= 0 and first < teams.size() and second < teams.size() and teams[first] != teams[second]
