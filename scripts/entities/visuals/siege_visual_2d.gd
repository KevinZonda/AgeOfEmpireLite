extends RefCounted
class_name RtsSiegeVisual2D
const Renderer = preload("res://scripts/entities/visuals/siege_visual.gd")

# Compatibility entry point; battlefield rendering passes the full snapshot.
static func draw(unit: Node2D, kind: String, radius: float, color: Color, swing := 0.0) -> void:
	var renderer := Renderer.new()
	renderer.draw(unit, Renderer.legacy_state(kind, radius, color, swing, false))
