extends RefCounted
class_name PanelFactory

static func wrap(child: Control, caption: String, colors: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", stylebox(colors["panel"], colors["line"], 6))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override("font_color", colors["text"])
	label.add_theme_font_size_override("font_size", 14)
	box.add_child(label)
	box.add_child(child)
	return panel

static func frame(child: Control, caption: String, accent: Color, colors: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", stylebox(Color(0.055, 0.050, 0.038, 0.62), accent, 6))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override("font_color", accent.lightened(0.25))
	label.add_theme_font_size_override("font_size", 11)
	box.add_child(label)
	box.add_child(child)
	return panel

static func stylebox(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	style.shadow_color = Color(0, 0, 0, 0.26)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 3)
	return style
