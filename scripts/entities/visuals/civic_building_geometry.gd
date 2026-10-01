extends "res://scripts/entities/visuals/landmark_visual.gd"

const Academic = preload("res://scripts/entities/visuals/academic_building_visual.gd")
var flat_faces: Array[Dictionary] = []

static func handles(kind: String) -> bool:
	return Academic.handles(kind)

func _init(kind: String, size: Vector2, civilization: String, player: Color, colors: Dictionary) -> void:
	set_world_dimensions(size)
	palette = colors.duplicate()
	base_z = 2.0
	Academic.populate(self, kind, civilization, player)
	translate_faces(Vector3(0, 0, -base_z))
	base_z = 0.0
	prepare()
	# Looking straight down requires height order rather than the iso BSP order.
	var surfaces := faces.duplicate()
	surfaces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _average_height(a) < _average_height(b))
	for polygon in surfaces:
		var points := PackedVector2Array()
		for p in polygon["points"]: points.append(Vector2(p.x, p.y))
		if not Geometry2D.triangulate_polygon(points).is_empty(): flat_faces.append({"points": points, "color": polygon["color"]})

func _average_height(polygon: Dictionary) -> float:
	var height := 0.0
	for p in polygon["points"]: height += p.z
	return height / polygon["points"].size()
