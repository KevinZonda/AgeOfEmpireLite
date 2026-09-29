extends RefCounted

# Base sizes at 100% text scale. Game._apply_ui_scales applies the user's scale.
const HERO := 42
const PAGE_TITLE := 28
const FEATURE_TITLE := 24
const SECTION_TITLE := 20
const SUBSECTION_TITLE := 18
const BODY := 16
const CAPTION := 14

static func world_caption_size(game: Node) -> int:
	var configured: Variant = game.get("text_scale") if game != null else null
	return maxi(1, roundi(CAPTION * (float(configured) if configured != null else 1.0)))
