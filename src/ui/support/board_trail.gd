extends Control
class_name BoardTrail

var from := Vector2.ZERO
var to := Vector2.ZERO
var color := Color.WHITE
var progress := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	if progress > 0.0 and progress < 1.0:
		queue_redraw()

func _draw() -> void:
	var end := from.lerp(to, progress)
	var glow := Color(color.r, color.g, color.b, 0.20)
	var core := Color(color.r, color.g, color.b, 0.68)
	draw_line(from, end, glow, 8.0, true)
	draw_line(from, end, core, 2.0, true)
	draw_circle(end, 5.0, core)

func set_path(start: Vector2, finish: Vector2, trail_color: Color) -> void:
	from = start
	to = finish
	color = trail_color
	queue_redraw()
