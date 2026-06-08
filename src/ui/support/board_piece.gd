extends Control
class_name BoardPiece

var fill := Color.WHITE
var border := Color.BLACK
var border_width := 1.0
var shape := "plaque"
var pressed := Callable()
var hover_lift := 4.0
var home_position := Vector2.ZERO

func _ready() -> void:
	if mouse_filter != Control.MOUSE_FILTER_IGNORE:
		mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5
	home_position = position
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _draw() -> void:
	if shape == "circle":
		var radius := minf(size.x, size.y) * 0.5
		var center := size * 0.5
		draw_circle(center + Vector2(4, 5), radius, Color(0, 0, 0, 0.26))
		draw_circle(center, radius, fill)
		draw_arc(center, radius - border_width * 0.5, 0.0, TAU, 72, border, border_width, true)
		return
	var points := _points()
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(4, 5))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.22))
	draw_colored_polygon(points, fill)
	var line := PackedVector2Array(points)
	line.append(points[0])
	draw_polyline(line, border, border_width, true)

func set_skin(piece_fill: Color, piece_border: Color, width := 1.0, piece_shape := "plaque") -> void:
	fill = piece_fill
	border = piece_border
	border_width = width
	shape = piece_shape
	queue_redraw()

func _points() -> PackedVector2Array:
	var w := size.x
	var h := size.y
	if shape == "card":
		var c := 9.0
		return PackedVector2Array([Vector2(c, 0), Vector2(w - c, 0), Vector2(w, c), Vector2(w, h - c), Vector2(w - c, h), Vector2(c, h), Vector2(0, h - c), Vector2(0, c)])
	if shape == "seat":
		var c := 14.0
		return PackedVector2Array([Vector2(c, 0), Vector2(w, 0), Vector2(w - 8, h), Vector2(0, h), Vector2(10, h * 0.5)])
	var c := 7.0
	return PackedVector2Array([Vector2(c, 0), Vector2(w - c, 0), Vector2(w, c), Vector2(w, h - c), Vector2(w - c, h), Vector2(c, h), Vector2(0, h - c), Vector2(0, c)])

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and pressed.is_valid():
		_press_feedback()
		pressed.call()

func _on_mouse_entered() -> void:
	if mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	z_index = 20
	_tween_to(home_position + Vector2(0, -hover_lift), Vector2(1.045, 1.045), 0.10)

func _on_mouse_exited() -> void:
	if mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	z_index = 0
	_tween_to(home_position, Vector2.ONE, 0.12)

func _press_feedback() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.96, 0.96), 0.05)
	tween.tween_property(self, "scale", Vector2(1.045, 1.045), 0.08)

func _tween_to(target_position: Vector2, target_scale: Vector2, duration: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_position, duration)
	tween.parallel().tween_property(self, "scale", target_scale, duration)
