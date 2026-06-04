extends PanelContainer
class_name PhaseHeader

signal advance_requested
signal recommend_requested
signal restart_requested

const UiCatalogScript := preload("res://src/ui/support/ui_catalog.gd")

var mode := "compact"
var panel_color := Color.WHITE
var line_color := Color.BLACK
var text_color := Color.WHITE
var muted_color := Color.GRAY
var accents: Array = []

var phase_label: Label
var phase_strip: HBoxContainer
var advance_button: Button
var recommend_button: Button
var restart_button: Button

func setup(next_mode: String, colors: Dictionary) -> void:
	mode = next_mode
	panel_color = colors["panel"]
	line_color = colors["line"]
	text_color = colors["text"]
	muted_color = colors["muted"]
	accents = colors["accents"]
	_build()

func refresh(game, phases: Array, phase_chip_width: int) -> void:
	phase_label.text = "ターン %d/%d  %s" % [game.turn, game.turn_limit, game.current_phase_name()]
	advance_button.text = "同時公開" if game.current_phase() == "simultaneous_reveal" else "次フェーズ"
	advance_button.disabled = game.is_finished
	if game.is_finished:
		phase_label.text = "ゲーム終了"
		advance_button.text = "終了"

	for child in phase_strip.get_children():
		child.queue_free()
	for phase in phases:
		var chip := Label.new()
		chip.text = UiCatalogScript.short_phase_name(phase)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.custom_minimum_size = Vector2(phase_chip_width, 28)
		chip.add_theme_font_size_override("font_size", 12)
		var active: bool = phase == game.current_phase()
		chip.add_theme_color_override("font_color", text_color if active else muted_color)
		var accent: Color = accents[mini(game.phase_index, accents.size() - 1)] if active else Color(0.05, 0.055, 0.06, 0.86)
		chip.add_theme_stylebox_override("normal", _stylebox(accent, line_color, 6))
		phase_strip.add_child(chip)

func _build() -> void:
	for child in get_children():
		child.queue_free()
	add_theme_stylebox_override("panel", _stylebox(Color(panel_color.r, panel_color.g, panel_color.b, 0.38), line_color, 6))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var title := Label.new()
	title.text = "マクロノミカ"
	title.add_theme_color_override("font_color", text_color)
	title.add_theme_font_size_override("font_size", 30 if mode == "wide" else 22)
	row.add_child(title)

	phase_label = Label.new()
	phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_label.add_theme_color_override("font_color", muted_color)
	phase_label.add_theme_font_size_override("font_size", 15)
	row.add_child(phase_label)

	recommend_button = Button.new()
	recommend_button.text = "全員に推奨案" if mode == "wide" else "推奨"
	recommend_button.tooltip_text = "手札と国内圧力から政策案を自動で伏せます。"
	recommend_button.pressed.connect(func() -> void: recommend_requested.emit())
	row.add_child(recommend_button)

	advance_button = Button.new()
	advance_button.pressed.connect(func() -> void: advance_requested.emit())
	row.add_child(advance_button)

	restart_button = Button.new()
	restart_button.text = "新規ゲーム" if mode == "wide" else "新規"
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	row.add_child(restart_button)

	phase_strip = HBoxContainer.new()
	phase_strip.add_theme_constant_override("separation", 6)
	box.add_child(phase_strip)

func _stylebox(color: Color, border: Color, radius: int) -> StyleBoxFlat:
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
