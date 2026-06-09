extends Control
class_name BoardResolutionOverlay

var paths: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	for path in paths:
		var start: Vector2 = path.get("from", Vector2.ZERO)
		var finish: Vector2 = path.get("to", Vector2.ZERO)
		var color: Color = path.get("color", Color.WHITE)
		var label := String(path.get("label", ""))
		var glow := Color(color.r, color.g, color.b, 0.08)
		var core := Color(color.r, color.g, color.b, 0.30)
		draw_line(start, finish, glow, 6.0, true)
		draw_line(start, finish, core, 1.6, true)
		draw_circle(start, 4.0, core)
		draw_circle(finish, 5.0, core.lightened(0.20))
		if not label.is_empty():
			var mid := start.lerp(finish, 0.55)
			draw_circle(mid, 10.0, Color(0.03, 0.025, 0.018, 0.76))
			draw_string(get_theme_default_font(), mid + Vector2(-5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color.lightened(0.30))

func set_paths(next_paths: Array) -> void:
	paths = next_paths
	queue_redraw()
