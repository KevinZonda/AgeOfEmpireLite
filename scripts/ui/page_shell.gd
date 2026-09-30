extends RefCounted

const SCENE = preload("res://scenes/ui/page_shell.tscn")

static func create(parent: Control, backdrop: Color, panel_style: StyleBox, insets := Vector4.ZERO, scene: PackedScene = SCENE) -> ColorRect:
	var overlay: ColorRect = scene.instantiate()
	overlay.color = backdrop
	parent.add_child(overlay)
	configure(overlay, panel_style, insets)
	return overlay

static func attach_to(overlay: ColorRect, panel_style: StyleBox, insets := Vector4.ZERO) -> PanelContainer:
	var shell: ColorRect = SCENE.instantiate()
	var panel: PanelContainer = shell.get_node("Panel")
	shell.remove_child(panel)
	panel.owner = null
	for child in panel.get_children(): child.owner = null
	overlay.add_child(panel)
	overlay.theme = shell.theme
	shell.free()
	configure(overlay, panel_style, insets)
	return panel

static func configure(overlay: ColorRect, panel_style: StyleBox, insets: Vector4) -> void:
	var panel: PanelContainer = overlay.get_child(0)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.offset_left = insets.x
	panel.offset_top = insets.y
	panel.offset_right = -insets.z
	panel.offset_bottom = -insets.w

static func layout(overlay: ColorRect) -> VBoxContainer:
	return overlay.get_child(0).get_child(0)
