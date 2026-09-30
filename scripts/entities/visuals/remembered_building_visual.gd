extends Node2D

const BuildingVisual = preload("res://scripts/entities/visuals/building_visual.gd")
const BuildingVisualState = preload("res://scripts/entities/visuals/building_visual_state.gd")

# Display-only node. It is never registered as an entity and owns no simulation state.
var game: Node2D
var state: BuildingVisualState
var renderer := BuildingVisual.new()

func _draw() -> void:
	if state == null: return
	state.update_view(game)
	renderer.draw(self, state)
