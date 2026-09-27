class_name SelectionDragOverlay
extends Control

# The four borders stay allocated for the lifetime of the match. Moving them
# avoids rebuilding the game's world-space draw list for every pointer event.
const BORDER_WIDTH := 2.0
const BORDER_COLOR := Color("f5e597")

var drag_start := Vector2.ZERO
var drag_current := Vector2.ZERO
var active := false
var borders: Array[ColorRect] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _index in 4:
		var border := ColorRect.new()
		border.color = BORDER_COLOR
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(border)
		borders.append(border)
	hide()

func begin(screen_point: Vector2) -> void:
	drag_start = screen_point
	drag_current = screen_point
	active = false
	hide()

func update_drag(screen_point: Vector2, should_show: bool) -> void:
	drag_current = screen_point
	active = should_show
	visible = active
	if not active: return
	var rect := screen_rect()
	_set_border(borders[0], rect.position, Vector2(maxf(rect.size.x, BORDER_WIDTH), BORDER_WIDTH))
	_set_border(borders[1], Vector2(rect.position.x, rect.end.y - BORDER_WIDTH), Vector2(maxf(rect.size.x, BORDER_WIDTH), BORDER_WIDTH))
	_set_border(borders[2], rect.position, Vector2(BORDER_WIDTH, maxf(rect.size.y, BORDER_WIDTH)))
	_set_border(borders[3], Vector2(rect.end.x - BORDER_WIDTH, rect.position.y), Vector2(BORDER_WIDTH, maxf(rect.size.y, BORDER_WIDTH)))

func finish() -> void:
	active = false
	hide()

func screen_rect() -> Rect2:
	return Rect2(drag_start, drag_current - drag_start).abs()

func _set_border(border: ColorRect, at: Vector2, extent: Vector2) -> void:
	border.position = at
	border.size = extent
