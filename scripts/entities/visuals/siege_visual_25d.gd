extends RefCounted
const Renderer = preload("res://scripts/entities/visuals/siege_visual.gd")

# Compatibility entry point; battlefield rendering passes the full snapshot.
static func draw(unit: Node2D, kind: String, radius: float, color: Color, swing := 0.0) -> void:
	var renderer := Renderer.new()
	renderer.draw(unit, Renderer.legacy_state(kind, radius, color, swing, true))

static func overlay_y(kind: String) -> float:
	var renderer := Renderer.new()
	return renderer.overlay_y(Renderer.legacy_state(kind, 20.0, Color.WHITE, 0.0, true))
