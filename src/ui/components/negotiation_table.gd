extends VBoxContainer
class_name NegotiationTable

signal country_selected(country_index: int)

const PolicyRecommenderScript := preload("res://src/app/policy_recommender.gd")
const UiCatalogScript := preload("res://src/ui/support/ui_catalog.gd")

const AGENDA := [
	{"name": "同時財政刺激", "tag": "cooperation", "icon": "協"},
	{"name": "スワップライン", "tag": "liquidity", "icon": "流"},
	{"name": "関税凍結", "tag": "trade", "icon": "関"},
	{"name": "債務再編", "tag": "debt", "icon": "債"}
]

var mode := "compact"
var warn_color := Color.ORANGE
var muted_color := Color.GRAY
var text_color := Color.WHITE
var line_color := Color.BLACK
var token_empty_color := Color.DIM_GRAY
var token_edge_color := Color.SADDLE_BROWN
var token_assets
var active_country_index := 0
var revealed_policies := false

func setup(next_mode: String, colors: Dictionary, next_token_assets = null) -> void:
	mode = next_mode
	warn_color = colors["warn"]
	muted_color = colors["muted"]
	text_color = colors["text"]
	line_color = colors["line"]
	token_empty_color = colors["token_empty"]
	token_edge_color = colors["token_edge"]
	token_assets = next_token_assets
	add_theme_constant_override("separation", 10)

func refresh(countries: Array, selected_country_index: int = 0, next_revealed_policies: bool = false) -> void:
	active_country_index = selected_country_index
	revealed_policies = next_revealed_policies
	for child in get_children():
		child.queue_free()
	var table := PanelContainer.new()
	table.custom_minimum_size = Vector2(0, 110 if mode == "wide" else 128)
	table.add_theme_stylebox_override("panel", _stylebox(Color(0.105, 0.082, 0.045, 0.56), warn_color.darkened(0.25), 7))
	add_child(table)

	var table_box := HBoxContainer.new()
	table_box.add_theme_constant_override("separation", 10)
	table.add_child(table_box)

	var facing_scroll := ScrollContainer.new()
	facing_scroll.custom_minimum_size = Vector2(372, 88)
	facing_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	facing_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	table_box.add_child(facing_scroll)
	var facing := HBoxContainer.new()
	facing.add_theme_constant_override("separation", 10)
	facing_scroll.add_child(facing)
	for i in range(countries.size()):
		facing.add_child(_country_stake(i, countries[i]))

	var agenda_scroll := ScrollContainer.new()
	agenda_scroll.custom_minimum_size = Vector2(0, 74)
	agenda_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	agenda_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	agenda_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	table_box.add_child(agenda_scroll)
	var agenda_row := HBoxContainer.new()
	agenda_row.add_theme_constant_override("separation", 8)
	agenda_scroll.add_child(agenda_row)
	for item in AGENDA:
		agenda_row.add_child(_agenda_tile(item["name"], item["tag"], item["icon"], countries))

func _country_stake(country_index: int, country) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(84, 74)
	var accent := _country_accent(country_index)
	var active := country_index == active_country_index
	panel.add_theme_stylebox_override("panel", _stylebox(Color(0.080, 0.064, 0.038, 0.72) if active else Color(0.055, 0.050, 0.038, 0.50), accent, 7))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			country_selected.emit(country_index)
	)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := VBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	panel.add_child(row)

	var seal := Label.new()
	seal.text = String.chr(65 + country_index)
	seal.custom_minimum_size = Vector2(30, 30)
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_theme_font_size_override("font_size", 18)
	seal.add_theme_color_override("font_color", accent.lightened(0.25))
	seal.add_theme_stylebox_override("normal", _stylebox(Color(0.035, 0.035, 0.030, 0.92), accent, 15))
	row.add_child(seal)

	var lower := HBoxContainer.new()
	lower.alignment = BoxContainer.ALIGNMENT_CENTER
	lower.add_theme_constant_override("separation", 3)
	row.add_child(lower)
	lower.add_child(_face_down_slot(country, accent))
	lower.add_child(_worker_slot(country, accent))
	return panel

func _face_down_slot(country, accent: Color) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(34, 28)
	slot.add_theme_stylebox_override("panel", _stylebox(Color(0.12, 0.095, 0.055, 0.98), accent.darkened(0.08), 5))
	var label := Label.new()
	label.text = "伏"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_font_size_override("font_size", 12)
	slot.add_child(label)
	return slot

func _worker_slot(country, accent: Color) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(30, 28)
	slot.add_theme_stylebox_override("panel", _stylebox(Color(0.035, 0.034, 0.029, 0.94), token_edge_color, 5))
	if token_assets == null:
		var label := Label.new()
		label.text = str(country.assigned_worker_list().size())
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", accent)
		slot.add_child(label)
		return slot
	var assigned_workers: Array = country.assigned_worker_list()
	if assigned_workers.is_empty():
		var empty := Label.new()
		empty.text = "未"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", accent)
		slot.add_child(empty)
		return slot
	var icon := TextureRect.new()
	icon.texture = token_assets.texture(UiCatalogScript.worker_token(String(assigned_workers[0])))
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = accent.lightened(0.12)
	slot.add_child(icon)
	if assigned_workers.size() > 1:
		var count := Label.new()
		count.text = str(assigned_workers.size())
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.add_theme_color_override("font_color", accent.lightened(0.25))
		slot.add_child(count)
	return slot

func _agenda_tile(label_text: String, tag: String, icon: String, countries: Array) -> Control:
	var panel := PanelContainer.new()
	var tile_size := Vector2(104, 62) if mode == "wide" else Vector2(96, 62)
	panel.custom_minimum_size = tile_size
	panel.add_theme_stylebox_override("panel", _stylebox(Color(0.15, 0.12, 0.07, 0.97), line_color.lightened(0.15), 6))

	var tile := VBoxContainer.new()
	tile.custom_minimum_size = tile_size
	tile.add_theme_constant_override("separation", 4)
	panel.add_child(tile)

	var seal := Label.new()
	seal.text = icon
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.add_theme_font_size_override("font_size", 16)
	seal.add_theme_color_override("font_color", warn_color if _planned_tag_count(tag, countries) > 0 else muted_color)
	tile.add_child(seal)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_font_size_override("font_size", 10)
	tile.add_child(label)

	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 2)
	tile.add_child(pips)
	var count := _planned_tag_count(tag, countries)
	for i in range(4):
		pips.add_child(_pip(warn_color if i < count else token_empty_color, 8))
	return panel

func _planned_tag_count(tag: String, countries: Array) -> int:
	if not revealed_policies:
		return 0
	var count := 0
	for country in countries:
		if not country.selected_policy.is_empty() and PolicyRecommenderScript.has_tag(country.selected_policy, tag):
			count += 1
	return count

func _pip(color: Color, size: int) -> PanelContainer:
	var pip := PanelContainer.new()
	pip.custom_minimum_size = Vector2(size, size)
	pip.add_theme_stylebox_override("panel", _stylebox(color, token_edge_color, size / 2))
	return pip

func _country_accent(index: int) -> Color:
	var accents := [
		Color(0.42, 0.66, 0.88),
		Color(0.32, 0.70, 0.58),
		Color(0.86, 0.62, 0.28),
		Color(0.76, 0.42, 0.38)
	]
	return accents[index] if index >= 0 and index < accents.size() else warn_color

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
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style
