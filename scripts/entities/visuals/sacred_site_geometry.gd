extends "res://scripts/entities/visuals/landmark_visual.gd"

# Ancient open-air ruins: a stepped stone podium, broken column enclosure and
# one ownership standard. Capture rules and ground overlays belong to the site.
const STONE := Color("a6a799")
const CAP := Color("bcbbae")
const DARK := Color("84877b")
var flat_faces: Array[Dictionary] = []

func _init(team: Color, variation: int = 0) -> void:
	dimensions = Vector2(92, 92)
	base_z = 0.0
	var form := clampi(variation, 0, 2)
	_ground_pavers(form)
	_podium()
	var centers := [Vector2(-30, -13), Vector2(-17, -29), Vector2(14, -29), Vector2(32, -8), Vector2(28, 23), Vector2(-28, 24)]
	var heights := [18.0, 11.0, 22.0, 14.0, 10.0, 21.0]
	for i in centers.size():
		var height: float = heights[i] + ([0.0, 1.5, -1.0][(i + form) % 3] if form else 0.0)
		_pillar(centers[i], height, i + form)
	# Remnants of the enclosure stay low and leave the entrance open.
	box(Vector2(-1, -33), Vector2(18, 4), 0.4, 3.3, DARK)
	box(Vector2(-6, -33), Vector2(6, 4.8), 3.7, 1.7, STONE)
	box(Vector2(2, -33), Vector2(4, 4.6), 3.7, 1.2, CAP)
	box(Vector2(-34, 3), Vector2(3.8, 15), 0.4, 3.0, STONE)
	box(Vector2(-34, 7), Vector2(4.5, 5.5), 3.4, 1.3, CAP)
	box(Vector2(34, 7), Vector2(4, 10), 0.4, 2.7, STONE)
	# Fallen column sections and separate chipped stones suggest a ruined ring.
	_fallen_column(Vector3(-27, 1 + form, 3.1), Vector3(-23, 12 + form, 3.1), 2.6)
	box(Vector2(18 + form, 32), Vector2(7, 4), 0.3, 2.5, DARK)
	box(Vector2(12 + form, 35), Vector2(3.6, 4.8), 0.3, 1.6, STONE)
	box(Vector2(-34, -23 + form), Vector2(5.2, 4.4), 0.3, 2.1, STONE)
	box(Vector2(29, -27 - form), Vector2(4.5, 5.6), 0.3, 1.8, CAP)
	_standard(team)
	prepare()
	_cache_overhead()

func _ground_pavers(form: int) -> void:
	var sites := [Vector2(-21, -18), Vector2(3, -25), Vector2(22, -17), Vector2(-24, 13), Vector2(22, 15), Vector2(-15, 32), Vector2(28, 33), Vector2(-37, -3)]
	for i in sites.size():
		var center: Vector2 = sites[i]
		var width := 8.0 + (i % 3) * 1.5
		var depth := 6.0 + ((i + form) % 2) * 2.0
		var top := 0.3 + (i % 2) * 0.08
		face([Vector3(center.x - width * 0.5, center.y - depth * 0.5, top), Vector3(center.x + width * 0.20, center.y - depth * 0.5, top), Vector3(center.x + width * 0.5, center.y - depth * 0.1, top), Vector3(center.x + width * 0.5, center.y + depth * 0.5, top), Vector3(center.x - width * 0.5, center.y + depth * 0.5, top)], STONE.darkened(0.03 * (i % 3)))

func _podium() -> void:
	box(Vector2.ZERO, Vector2(35, 33), 0.4, 4.6, STONE)
	box(Vector2.ZERO, Vector2(38, 36), 5.0, 1.2, CAP)
	# Broad front stairs lead to the platform, with four visible individual treads.
	for step in 4:
		box(Vector2(0, 19.5 + step * 3), Vector2(22, 3.3), 0.4, 4.9 - step * 1.15, CAP.darkened(0.035 * step))
	# A shorter broken side approach gives the ruin an asymmetrical outline.
	box(Vector2(-19, -2), Vector2(3, 15), 0.4, 3.7, STONE)
	box(Vector2(-22, -2), Vector2(3, 13), 0.4, 2.1, CAP.darkened(0.09))
	# Stone joints occupy the top surface, rather than drawing screen-space lines.
	for x in [-8.0, 8.0]: box(Vector2(x, 0), Vector2(0.35, 35), 6.21, 0.04, DARK.lightened(0.06))
	box(Vector2(0, -7), Vector2(37, 0.35), 6.21, 0.04, DARK.lightened(0.06))
	box(Vector2(0, 8), Vector2(37, 0.35), 6.21, 0.04, DARK.lightened(0.06))
	# A low square socket anchors the pole, without religious statuary.
	box(Vector2(-2, -1), Vector2(10, 10), 6.2, 1.6, STONE)
	box(Vector2(-2, -1), Vector2(11, 11), 7.8, 0.8, CAP)

func _pillar(center: Vector2, height: float, seed: int) -> void:
	box(center, Vector2(8, 8), 0.4, 1.7, STONE.darkened(0.08))
	box(center, Vector2(7, 7), 2.1, 1.0, CAP)
	var top: Array = []
	for i in 8:
		var angle := TAU * i / 8.0 + PI / 8
		var next := TAU * (i + 1) / 8.0 + PI / 8
		var foot := Vector3(center.x + cos(angle) * 2.75, center.y + sin(angle) * 2.75, 3.1)
		var foot_next := Vector3(center.x + cos(next) * 2.75, center.y + sin(next) * 2.75, 3.1)
		# The broken end is a shallow sloping plane, so every side stays planar.
		var tip := Vector3(center.x + cos(angle) * 2.75, center.y + sin(angle) * 2.75, height + cos(angle) * 0.6 + sin(angle) * 0.35)
		var tip_next := Vector3(center.x + cos(next) * 2.75, center.y + sin(next) * 2.75, height + cos(next) * 0.6 + sin(next) * 0.35)
		face([foot, foot_next, tip_next, tip], STONE.lightened(0.045) if i in [0, 1] else STONE.darkened(0.10 if i < 4 else 0.18))
		top.append(tip)
	face(top, CAP.darkened(0.06 * (seed % 2)))
	# One remaining collar provides the classical column silhouette.
	_octagonal_disc(center, 3.2, 3.15, 0.65, CAP.darkened(0.07))

func _octagonal_disc(center: Vector2, radius: float, z: float, height: float, color: Color) -> void:
	var top: Array = []
	for i in 8:
		var angle := TAU * i / 8.0 + PI / 8
		var next := TAU * (i + 1) / 8.0 + PI / 8
		var a := Vector3(center.x + cos(angle) * radius, center.y + sin(angle) * radius, z)
		var b := Vector3(center.x + cos(next) * radius, center.y + sin(next) * radius, z)
		face([a, b, b + Vector3(0, 0, height), a + Vector3(0, 0, height)], color.darkened(0.10 if i > 2 else 0.0))
		top.append(a + Vector3(0, 0, height))
	face(top, color.lightened(0.06))

func _fallen_column(a: Vector3, b: Vector3, radius: float) -> void:
	var along := (b - a).normalized()
	var across := along.cross(Vector3(0, 0, 1)).normalized()
	var up := along.cross(across).normalized()
	var front: Array = []
	for i in 8:
		var angle := TAU * i / 8.0
		var next := TAU * (i + 1) / 8.0
		var offset := (across * cos(angle) + up * sin(angle)) * radius
		var offset_next := (across * cos(next) + up * sin(next)) * radius
		face([a + offset, b + offset, b + offset_next, a + offset_next], STONE.darkened(0.05 * (i % 4)))
		front.append(b + offset)
	face(front, CAP)

func _standard(team: Color) -> void:
	var center := Vector2(-2, -1)
	box(center, Vector2.ONE * 1.0, 8.6, 37.5, Color("6c5840"))
	box(center, Vector2.ONE * 1.7, 45.8, 0.7, Color("c4bb91"))
	# Three attached vertical panels make a modest cloth fold; no floating flag.
	var edge := [Vector2(-1.5, -0.5), Vector2(3.2, 0.65), Vector2(7.5, -0.25), Vector2(12.4, 0.9)]
	for i in 3:
		var a: Vector2 = edge[i]
		var b: Vector2 = edge[i + 1]
		face([Vector3(a.x, a.y, 44.8), Vector3(b.x, b.y, 44.8), Vector3(b.x, b.y, 37.0 + (0.8 if i == 2 else 0)), Vector3(a.x, a.y, 37.0)], team.lightened(0.06) if i == 1 else team.darkened(0.04))
		# Thin cloth top edges let the physical standard remain visible overhead.
		face([Vector3(a.x, a.y - 0.12, 44.8), Vector3(b.x, b.y - 0.12, 44.8), Vector3(b.x, b.y + 0.12, 44.8), Vector3(a.x, a.y + 0.12, 44.8)], team)

func _cache_overhead() -> void:
	var source := faces.duplicate()
	source.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _average_height(a) < _average_height(b))
	for polygon in source:
		var points := PackedVector2Array()
		for at in polygon["points"]: points.append(Vector2(at.x, at.y))
		if not Geometry2D.triangulate_polygon(points).is_empty(): flat_faces.append({"points": points, "color": polygon["color"]})

func _average_height(polygon: Dictionary) -> float:
	var height := 0.0
	for at in polygon["points"]: height += at.z
	return height / polygon["points"].size()
