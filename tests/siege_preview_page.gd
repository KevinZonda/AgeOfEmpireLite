extends SceneTree

const Page = preload("res://scripts/ui/unit_preview_page.gd")
const Siege = preload("res://scripts/entities/visuals/siege_visual.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := Control.new()
	host.size = Vector2(1440, 960)
	root.add_child(host)
	var page = Page.new()
	page.build(host, "English", func(_button) -> void: pass)
	page.age = 4
	await process_frame
	page.preview_viewport.get_parent().stretch = false
	assert(page.preview_context.camera.zoom == Vector2.ONE)
	var renderer = Siege.new()
	var cases := 0
	for mode in [false, true]:
		page.preview_context.view_mode_25d = mode
		for viewport_size in [Vector2i(160, 180), Vector2i(350, 390), Vector2i(800, 900)]:
			page.preview_viewport.size = viewport_size
			for kind in Siege.KINDS:
				page.selected_kind = kind
				page._refresh_preview()
				assert(page.preview_unit.state.view_mode_25d == mode, "fit must use the active projection")
				var geometry = renderer.geometry(page.preview_unit.state)
				var margin: float = clampf(minf(viewport_size.x, viewport_size.y) * 0.06, 12.0, 28.0)
				var area := Rect2(Vector2.ONE * (margin - 0.1), Vector2(viewport_size) - Vector2.ONE * (margin - 0.1) * 2.0)
				for surface in geometry.surfaces:
					if surface.has("spokes"): continue
					for point in surface.points:
						var projected: Vector2 = page.preview_unit.position + point * page.preview_unit.scale
						assert(area.has_point(projected), "%s clipped at %s in projection %s: %s" % [kind, viewport_size, mode, projected])
				cases += 1
			# Existing humanoid and naval preview sizing stays unchanged.
			for kind in ["spearman", "warship"]:
				page.selected_kind = kind
				page._refresh_preview()
				var view_size := Vector2(viewport_size)
				var expected_position := Vector2(view_size.x * 0.5, view_size.y * (0.63 if mode else 0.52))
				var expected_scale: float = clampf(minf(view_size.x / 400.0, view_size.y / 420.0) * 4.0, 3.4, 6.0)
				assert(page.preview_unit.position.is_equal_approx(expected_position))
				assert(is_equal_approx(page.preview_unit.scale.x, expected_scale))
	host.free()
	print("SIEGE_PREVIEW_PAGE_OK: ", cases, " model/projection/size combinations fit with margins")
	quit()
