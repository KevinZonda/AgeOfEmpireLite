extends "res://scripts/entities/visuals/western_landmark_details.gd"

# Landmark-specific masses and courts, backed by the shared face ordering and
# selection mesh. Normalized footprints keep all simulation dimensions intact.
const EnglishCourt = preload("res://scripts/entities/visuals/english_court_landmark_visual.gd")
const FrenchTradeArtillery = preload("res://scripts/entities/visuals/french_trade_artillery_landmark_visual.gd")

static func handles(id: String) -> bool:
	return id.begins_with("eng_") or id.begins_with("fr_")

static func _layout(id: String) -> Array:
	if EnglishCourt.handles(id): return EnglishCourt.layout(id)
	if FrenchTradeArtillery.handles(id): return FrenchTradeArtillery.layout(id)
	match id:
		"eng_kings_mill": return [[0.50, 0.40, 0.37, 0.62, 31, "gable"], [0.29, 0.71, 0.18, 0.20, 44, "spire"], [0.71, 0.71, 0.18, 0.20, 44, "spire"]]
		"eng_white_tower": return [[0.50, 0.46, 0.61, 0.60, 52, "flat"], [0.20, 0.17, 0.15, 0.16, 58, "hip"], [0.80, 0.17, 0.15, 0.16, 58, "hip"], [0.20, 0.75, 0.15, 0.16, 58, "hip"], [0.80, 0.75, 0.15, 0.16, 58, "hip"]]
		"eng_abbey": return [[0.50, 0.29, 0.74, 0.30, 33, "hip"], [0.19, 0.58, 0.22, 0.40, 23, "gable"], [0.81, 0.58, 0.22, 0.40, 23, "gable"], [0.50, 0.53, 0.22, 0.18, 39, "hip"], [0.50, 0.72, 0.30, 0.18, 14, "gable"]]
		"eng_berkshire_fortress": return [[0.50, 0.38, 0.43, 0.44, 42, "flat"], [0.17, 0.19, 0.21, 0.21, 45, "flat"], [0.83, 0.19, 0.21, 0.21, 45, "flat"], [0.17, 0.81, 0.21, 0.21, 38, "flat"], [0.83, 0.81, 0.21, 0.21, 38, "flat"]]
		"fr_school_of_cavalry": return [[0.18, 0.47, 0.23, 0.71, 23, "hip"], [0.82, 0.47, 0.23, 0.71, 23, "hip"], [0.50, 0.20, 0.43, 0.23, 30, "hip"]]
		"fr_royal_institute": return [[0.50, 0.31, 0.41, 0.38, 39, "dome"], [0.20, 0.49, 0.29, 0.48, 24, "hip"], [0.80, 0.49, 0.29, 0.48, 24, "hip"], [0.50, 0.64, 0.38, 0.20, 19, "gable"]]
		"fr_guild_hall": return [[0.50, 0.33, 0.71, 0.37, 30, "hip"], [0.50, 0.59, 0.20, 0.25, 51, "clock_spire"], [0.18, 0.60, 0.21, 0.27, 20, "hip"], [0.82, 0.60, 0.21, 0.27, 20, "hip"]]
		"fr_red_palace": return [[0.50, 0.35, 0.46, 0.46, 39, "hip"], [0.17, 0.18, 0.23, 0.23, 43, "spire"], [0.83, 0.18, 0.23, 0.23, 43, "spire"], [0.17, 0.81, 0.23, 0.23, 39, "spire"], [0.83, 0.81, 0.23, 0.23, 39, "spire"]]
	return []

static func populate(g, id: String, player: Color) -> bool:
	if EnglishCourt.handles(id): return EnglishCourt.populate(g, id, player)
	if FrenchTradeArtillery.handles(id): return FrenchTradeArtillery.populate(g, id, player)
	if not handles(id): return false
	g.palette = g.palette.duplicate()
	g.palette["wall"] = Color("c1b79d") if id.begins_with("eng_") else Color("cfc3a7")
	g.palette["trim"] = Color("ded4b9")
	g.palette["roof"] = Color("57636b") if id.begins_with("eng_") else Color("556e80")
	g.palette["roof_dark"] = Color("38464c")
	if id == "eng_white_tower": g.palette["wall"] = Color("c8c9bc")
	if id == "fr_red_palace": g.palette["roof"] = Color("8f5145")
	for form in _layout(id): _hall(g, form, player)
	match id:
		"eng_kings_mill":
			for v in [0.19, 0.37, 0.55]:
				_buttress(g, 0.29, v, 23)
				_buttress(g, 0.71, v, 23)
			_arch(g, 0.50, 0.722, 5, 6, 15, false)
			_cross(g, 0.50, 0.13, 43)
		"eng_white_tower":
			_steps(g, 0.50, 0.79, 0.16)
			_arch(g, 0.50, 0.763, 3, 6, 12, false)
			_banner(g, 0.64, 0.764, 30, player)
		"eng_abbey":
			for u in [0.40, 0.50, 0.60]: _column(g, u, 0.815, 11)
			_steps(g, 0.50, 0.86, 0.24)
			_banner(g, 0.58, 0.442, 28, player)
		"eng_berkshire_fortress", "fr_red_palace":
			_curtains(g, player)
		"fr_school_of_cavalry":
			# Horseshoe arch bays face the open working yard.
			for v in [0.37, 0.56, 0.74]: _arch(g, 0.307, v, 2, 4, 12, true)
			_cargo(g, 0.67, 0.81)
			_banner(g, 0.49, 0.321, 24, player)
		"fr_royal_institute":
			for u in [0.36, 0.44, 0.56, 0.64]: _column(g, u, 0.75, 16)
			_steps(g, 0.50, 0.79, 0.33)
		"fr_guild_hall":
			var clock := _p(g, 0.50, 0.723, 40)
			g.disc(clock, 4.0, g.palette["trim"])
			g.disc(clock + Vector3(0, 0.025, 0), 3.1, Color("394b50"))
			_ribbon(g, clock + Vector3(0, 0.05, 0), clock + Vector3(1.9, 0.05, 1.2), 0.5, g.palette["trim"])
			_banner(g, 0.40, 0.521, 26, player)
	return true

static func draw_topdown(c: CanvasItem, bounds: Rect2, id: String, palette: Dictionary, player: Color) -> bool:
	if EnglishCourt.handles(id): return EnglishCourt.draw_topdown(c, bounds, id, palette, player)
	if FrenchTradeArtillery.handles(id): return FrenchTradeArtillery.draw_topdown(c, bounds, id, palette, player)
	if not handles(id): return false
	draw_layout_topdown(c, bounds, _layout(id), id, palette, player)
	if id in ["eng_berkshire_fortress", "fr_red_palace"]:
		for u in [0.12, 0.88]:
			c.draw_rect(Rect2(bounds.position + bounds.size * Vector2(u, 0.22), Vector2(3, bounds.size.y * 0.5)), palette["trim"])
	return true
