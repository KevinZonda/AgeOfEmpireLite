extends RefCounted

# Common object-space models. Negative Y is the attacking end; Z is height.
# The shared geometry painter owns facing, projection, visibility and wheel spin.
static func build(g, state) -> void:
	match state.kind:
		"battering_ram": _ram(g, state)
		"siege_tower": _tower(g, state)

static func _ram(g, state) -> void:
	# Wide carriage, four wheels and two continuous runners carry the roof.
	g.box(Vector3(-15, -20, 6), Vector3(15, 20, 9), g.WOOD_DARK)
	for x in [-12.0, 12.0]:
		g.box(Vector3(x - 2, -21, 8), Vector3(x + 2, 21, 11), g.WOOD)
	for y in [-14.0, 14.0]:
		g.cylinder(Vector3(-18, y, 5), Vector3(18, y, 5), 1.6, g.IRON)
		for x in [-17.0, 17.0]:
			g.wheel(Vector3(x, y, 5), 5.0, 3.0)
	# Four posts and the ridge make the shelter a triangular volume.
	for x in [-13.0, 13.0]:
		g.beam(Vector3(x, -18, 21), Vector3(x, 18, 21), 2.3, g.WOOD_LIGHT)
		# Side shield boards stop short of the bottom: the wheels remain visible.
		g.box(Vector3(x - 0.8, -18, 11), Vector3(x + 0.8, 18, 19.5), g.WOOD)
		g.beam(Vector3(x * 1.04, -16, 12), Vector3(x * 1.04, 16, 18), 1.8, g.WOOD_DARK)
		for y in [-13.0, 13.0]:
			g.box(Vector3(x - 1, y - 1.1, 11), Vector3(x + 1, y + 1.1, 19.5), g.IRON)
	for y in [-18.0, 18.0]:
		# Posts, sill and gable share the same end plane and overlap at each
		# joint. Draw the frame together instead of letting a side panel cut it.
		g.begin_surface_group(Vector3(0, y, 16))
		for x in [-13.0, 13.0]:
			g.box(Vector3(x - 1.6, y - 1.5, 8), Vector3(x + 1.6, y + 1.5, 22.5), g.WOOD)
		g.beam(Vector3(-14, y, 9.5), Vector3(14, y, 9.5), 3.0, g.WOOD_LIGHT)
		g.beam(Vector3(-13, y, 21), Vector3(0, y, 27), 2.4, g.WOOD_LIGHT)
		g.beam(Vector3(0, y, 27), Vector3(13, y, 21), 2.4, g.WOOD_LIGHT)
		g.beam(Vector3(-14, y, 21.5), Vector3(14, y, 21.5), 3.0, g.WOOD_LIGHT)
		for x in [-13.0, 13.0]:
			g.box(Vector3(x - 1.8, y - 1.65, 18.5), Vector3(x + 1.8, y + 1.65, 21), g.IRON)
		g.end_surface_group()
	# The log is suspended independently. Only it lunges during an attack.
	var travel: float = -float(g.attack_motion(state)) * 5.5
	var log_height: float = 14.0 + absf(travel) * 0.06
	# Short axial spans keep the protruding wood in front of the end sill.
	# One long cylinder sorted at its midpoint hid the visible shaft outside.
	for ends in [[15.0, 8.0], [8.0, 0.0], [0.0, -8.0], [-8.0, -16.0], [-16.0, -24.0], [-24.0, -27.0]]:
		g.cylinder(Vector3(0, ends[0] + travel, log_height), Vector3(0, ends[1] + travel, log_height), 3.4, g.WOOD_DARK)
	g.cylinder(Vector3(0, -24 + travel, log_height), Vector3(0, -29 + travel, log_height), 4.0, g.IRON)
	# A faceted iron wedge gives the ram an unmistakable striking head.
	g.face([Vector3(-3.7, -29 + travel, log_height - 3), Vector3(3.7, -29 + travel, log_height - 3), Vector3(3.3, -32 + travel, log_height), Vector3(-3.3, -32 + travel, log_height)], g.IRON)
	g.face([Vector3(-3.7, -29 + travel, log_height + 3), Vector3(-3.3, -32 + travel, log_height), Vector3(3.3, -32 + travel, log_height), Vector3(3.7, -29 + travel, log_height + 3)], g.IRON_LIGHT)
	for y in [-10.0, 10.0]:
		for x in [-2.2, 2.2]:
			g.line(Vector3(x, y, 25), Vector3(x, y + travel, log_height + 2.6), g.IRON_LIGHT, 1.3)
		g.cylinder(Vector3(0, y + travel - 0.6, log_height), Vector3(0, y + travel + 0.6, log_height), 3.8, g.IRON)
	# Broad leather-clad roof planes, with a capped ridge and few iron straps.
	var hide: Color = g.WOOD.darkened(0.13)
	g.face([Vector3(-16, -21, 21), Vector3(0, -21, 28), Vector3(0, 21, 28), Vector3(-16, 21, 21)], hide)
	g.face([Vector3(0, -21, 28), Vector3(16, -21, 21), Vector3(16, 21, 21), Vector3(0, 21, 28)], hide.lightened(0.09))
	g.beam(Vector3(0, -22, 28), Vector3(0, 22, 28), 1.8, g.IRON)
	for y in [-14.0, 14.0]:
		g.beam(Vector3(-16, y, 21.4), Vector3(0, y, 28.4), 1.1, g.IRON)
		g.beam(Vector3(0, y, 28.4), Vector3(16, y, 21.4), 1.1, g.IRON)
	# Small hanging cloths carry the owner's color without recoloring the wood.
	for x in [-14.1, 14.1]:
		g.face([Vector3(x, -4, 20), Vector3(x, 4, 20), Vector3(x, 3, 13), Vector3(x, 0, 11.5), Vector3(x, -3, 13)], g.team_color)

static func _tower(g, state) -> void:
	# A flared base supports three floors and a fighting platform.
	g.box(Vector3(-17, -21, 6), Vector3(17, 21, 10), g.WOOD_DARK)
	for y in [-16.0, 16.0]:
		g.cylinder(Vector3(-19, y, 6), Vector3(19, y, 6), 2.0, g.IRON)
		for x in [-18.0, 18.0]:
			g.wheel(Vector3(x, y, 6), 6.0, 3.5)
	for z in [10.0, 23.0, 36.0, 49.0]:
		g.box(Vector3(-14.5, -16.5, z), Vector3(14.5, 16.5, z + 2), g.WOOD)
		g.beam(Vector3(-14.8, -16.8, z + 1.9), Vector3(14.8, -16.8, z + 1.9), 1.0, g.WOOD_LIGHT)
	for x in [-12.0, 12.0]:
		for y in [-14.0, 14.0]:
			g.box(Vector3(x - 1.6, y - 1.6, 10), Vector3(x + 1.6, y + 1.6, 54), g.WOOD_DARK)
			# Distinct diagonal feet widen the silhouette and show its load path.
			g.beam(Vector3(x * 1.28, y * 1.35, 10), Vector3(x, y, 26), 2.3, g.WOOD_LIGHT)
	# Solid protective walls have actual gaps, instead of painted black windows.
	for z in [12.0, 25.0, 38.0]:
		for x in [-13.0, 13.0]:
			g.box(Vector3(x - 0.7, -13, z), Vector3(x + 0.7, 13, z + 3), g.WOOD)
			g.box(Vector3(x - 0.7, -13, z + 3), Vector3(x + 0.7, -4, z + 8), g.WOOD)
			g.box(Vector3(x - 0.7, 4, z + 3), Vector3(x + 0.7, 13, z + 8), g.WOOD)
			g.box(Vector3(x - 0.7, -13, z + 8), Vector3(x + 0.7, 13, z + 11), g.WOOD)
			g.beam(Vector3(x * 1.07, -12, z + 1), Vector3(x * 1.07, 12, z + 10), 1.5, g.WOOD_LIGHT)
		# Front plates frame a central slit; the top opening leads onto the bridge.
		g.box(Vector3(-11, -15.2, z), Vector3(-4, -13.8, z + 11), g.WOOD)
		g.box(Vector3(4, -15.2, z), Vector3(11, -13.8, z + 11), g.WOOD)
		g.box(Vector3(-4, -15.2, z), Vector3(4, -13.8, z + 3), g.WOOD)
		if z < 38.0:
			g.box(Vector3(-4, -15.2, z + 8), Vector3(4, -13.8, z + 11), g.WOOD)
		# The rear stays open between crossbeams so the ladder reads clearly.
		g.beam(Vector3(-12, 14, z + 9), Vector3(12, 14, z + 9), 2.0, g.WOOD)
	# An exterior ladder climbs the back, with enough lean to read in plan view.
	var ladder_bottom := Vector3(0, 21, 10)
	var ladder_top := Vector3(0, 16.5, 50)
	for x in [-4.5, 4.5]:
		g.beam(ladder_bottom + Vector3(x, 0, 0), ladder_top + Vector3(x, 0, 0), 1.6, g.WOOD_LIGHT)
	for rung in range(1, 9):
		var center: Vector3 = ladder_bottom.lerp(ladder_top, float(rung) / 9.0)
		g.beam(center + Vector3(-4.5, 0, 0), center + Vector3(4.5, 0, 0), 1.3, g.WOOD_LIGHT)
	# Low parapets and separated merlons leave a visible top deck.
	for x in [-13.0, 13.0]:
		g.box(Vector3(x - 1, -16, 51), Vector3(x + 1, 16, 55), g.WOOD)
		for y in [-14.0, 0.0, 14.0]:
			g.box(Vector3(x - 1.1, y - 3, 55), Vector3(x + 1.1, y + 3, 58), g.WOOD_LIGHT)
	g.box(Vector3(-12, 14, 51), Vector3(12, 16, 55), g.WOOD)
	for x in [-9.0, 9.0]:
		g.box(Vector3(x - 3, -16, 51), Vector3(x + 3, -14, 57), g.WOOD)
	# Hinged assault bridge: vertical while travelling, forward at the wall.
	var deployed: bool = state.siege_deployed
	var hinge := Vector3(0, -16.0, 49.5)
	var end: Vector3 = hinge + (Vector3(0, -19, -1.8) if deployed else Vector3(0, -1, 18.5))
	var bridge_offset := Vector3(0, 0, -1.2) if deployed else Vector3(0, 1.2, 0)
	g.face([hinge + Vector3(-7, 0, 0), end + Vector3(-7, 0, 0), end + Vector3(7, 0, 0), hinge + Vector3(7, 0, 0)], g.WOOD_LIGHT)
	g.face([hinge + Vector3(-7, 0, 0) + bridge_offset, hinge + Vector3(7, 0, 0) + bridge_offset, end + Vector3(7, 0, 0) + bridge_offset, end + Vector3(-7, 0, 0) + bridge_offset], g.WOOD)
	for x in [-7.0, 7.0]:
		g.beam(hinge + Vector3(x, 0, 0), end + Vector3(x, 0, 0), 1.8, g.WOOD_DARK)
		g.line(Vector3(x * 1.35, -14, 57), end + Vector3(x, 0, 0), g.ROPE, 1.0)
	for step in [0.25, 0.5, 0.75]:
		var center: Vector3 = hinge.lerp(end, step)
		g.beam(center + Vector3(-7, 0, 0), center + Vector3(7, 0, 0), 0.7, g.WOOD)
	g.cylinder(Vector3(-9, -16, 49.5), Vector3(9, -16, 49.5), 1.4, g.IRON)
	# Colored side banners and a single high pennant identify ownership.
	for x in [-14.15, 14.15]:
		g.face([Vector3(x, -5, 45), Vector3(x, 5, 45), Vector3(x, 4, 34), Vector3(x, 0, 31), Vector3(x, -4, 34)], g.team_color)
	g.beam(Vector3(11, 12, 50), Vector3(11, 12, 67), 1.1, g.WOOD_LIGHT)
	g.face([Vector3(11, 12, 66), Vector3(19, 12, 63.5), Vector3(11, 12, 61)], g.team_color)
	if state.passenger_count > 0:
		# Occupants appear in the opening; the model stays entirely render-state driven.
		g.box(Vector3(-2.7, -13.5, 42), Vector3(2.7, -12.0, 44.5), g.team_color.darkened(0.15))
		g.cylinder(Vector3(0, -12.7, 44.7), Vector3(0, -12.7, 46.8), 2.1, Color("c0a484"), 8)
		# Infantry on the upper deck stay visible when the lowered bridge hides
		# the front window, without drawing occupants through the wooden walls.
		for x in [-5.0, 5.0]:
			g.box(Vector3(x - 1.8, -4, 53), Vector3(x + 1.8, -1, 57.5), g.team_color.darkened(0.1))
			g.cylinder(Vector3(x, -2.5, 58), Vector3(x, -2.5, 60.8), 1.8, g.IRON_LIGHT, 8)
