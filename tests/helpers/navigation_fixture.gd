extends Node2D

# Minimal world for deterministic movement tests without UI or AI updates.
var players := [{}, {}]
var started := true
var paused := false
var game_over := false
var formation_mode := "balanced"
var formation_width := 5
var selected: Array[Node2D] = []
var units: Array[RtsUnit] = []
var resources: Array[RtsResource] = []
var buildings: Array[RtsBuilding] = []
var world_size := Vector2.ZERO
var view_mode_25d := false
var world_map: RtsWorldMap
var navigation: RtsNavigation

func is_enemy(first: int, second: int) -> bool:
	return first != second

func initialize(size: Vector2) -> void:
	world_size = size
	world_map = RtsWorldMap.new()
	world_map.world_size = size
	world_map.grid_size = Vector2i(size / RtsWorldMap.CELL_SIZE)
	world_map.cells.resize(world_map.grid_size.x * world_map.grid_size.y)
	world_map.cells.fill(RtsWorldMap.Terrain.GRASS)
	add_child(world_map)
	world_map.hide()
	navigation = RtsNavigation.new(self, world_map)
	navigation.refresh()

func spawn_unit(point: Vector2) -> RtsUnit:
	var unit := RtsUnit.new()
	unit.game = self
	unit.stats = {"radius": 12.0, "speed": 80.0}
	unit.order = "move"
	unit.position = point
	add_child(unit)
	unit.set_process(false)
	unit.hide()
	units.append(unit)
	navigation.invalidate_spatial_index()
	return unit

func nearest_enemy(_unit: RtsUnit, _reach: float) -> Node2D:
	return null
