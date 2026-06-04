extends PanelContainer
class_name CountryMat

signal country_selected(country_index: int)
signal policy_selected(country_index: int, hand_index: int)
signal worker_assigned(country_index: int, worker_id: String)

const CountryStateScript := preload("res://src/core/country_state.gd")
const UiCatalogScript := preload("res://src/ui/support/ui_catalog.gd")
const CardTextFormatterScript := preload("res://src/ui/support/card_text_formatter.gd")
const TrackPresenterScript := preload("res://src/ui/support/track_presenter.gd")

const COUNTRY_TRACKS := [
	"gdp_gap",
	"inflation",
	"unemployment",
	"debt",
	"financial_stress",
	"political_capital",
	"exchange_rate",
	"current_account"
]

var country_index := 0
var mode := "compact"
var token_assets
var colors: Dictionary = {}
var accent := Color.WHITE

var emblem: Label
var title: Label
var deck_label: Label
var pressure_card: RichTextLabel
var planned: RichTextLabel
var worker_buttons := {}
var track_views := {}
var hand_box: HBoxContainer
var detail: RichTextLabel
var pressure_title: Label
var pressure_message: Label

func setup(index: int, next_mode: String, mat_size: Vector2, next_token_assets, next_colors: Dictionary, next_accent: Color) -> void:
	country_index = index
	mode = next_mode
	token_assets = next_token_assets
	colors = next_colors
	accent = next_accent
	custom_minimum_size = mat_size
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _mat_style(colors["mat"], accent, 8))
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			country_selected.emit(country_index)
	)
	_build()

func refresh(country, selected_index: int, phase: String, revealed_policies: bool, is_finished: bool) -> void:
	var is_active := country_index == selected_index
	add_theme_stylebox_override("panel", _mat_style(colors["mat"].lightened(0.05) if is_active else colors["mat"], accent, 8))
	emblem.text = UiCatalogScript.country_emblem(country_index)
	title.text = country.display_name
	deck_label.text = "山札 %d / 捨札 %d" % [country.deck.size(), country.discard.size()]
	pressure_title.text = String(country.domestic_pressure.get("display_name", ""))
	pressure_message.text = String(country.domestic_pressure.get("message", ""))
	pressure_card.text = "[b]%s[/b]\n%s" % [pressure_title.text, pressure_message.text]
	planned.text = CardTextFormatterScript.planned_text(country, revealed_policies, phase, is_finished)

	for worker in worker_buttons.keys():
		worker_buttons[worker].button_pressed = worker == country.assigned_worker
	for key in track_views.keys():
		_update_track_chip(track_views[key], int(country.tracks.get(key, 0)))
	_rebuild_hand(country, phase, is_finished)

	var detail_card: Dictionary = country.selected_policy
	if detail_card.is_empty():
		detail_card = CardTextFormatterScript.first_policy(country.hand)
	detail.text = CardTextFormatterScript.card_detail(country, detail_card)

func _build() -> void:
	for child in get_children():
		child.queue_free()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	emblem = Label.new()
	emblem.custom_minimum_size = Vector2(48, 48)
	emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emblem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emblem.add_theme_font_size_override("font_size", 28)
	emblem.add_theme_color_override("font_color", accent)
	emblem.add_theme_stylebox_override("normal", _stylebox(Color(0.045, 0.040, 0.032, 0.94), accent, 24))
	header.add_child(emblem)

	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", colors["text"])
	title.add_theme_font_size_override("font_size", 18)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title)

	deck_label = Label.new()
	deck_label.add_theme_color_override("font_color", colors["muted"])
	deck_label.add_theme_font_size_override("font_size", 12)
	header.add_child(deck_label)

	var board_row := HBoxContainer.new()
	board_row.add_theme_constant_override("separation", 8)
	box.add_child(board_row)

	var pressure_tile := PanelContainer.new()
	pressure_tile.custom_minimum_size = Vector2(112, 86)
	pressure_tile.add_theme_stylebox_override("panel", _card_style(Color(0.070, 0.052, 0.034, 0.72), accent.darkened(0.05), false))
	board_row.add_child(pressure_tile)
	var pressure_box := VBoxContainer.new()
	pressure_box.add_theme_constant_override("separation", 3)
	pressure_tile.add_child(pressure_box)
	var pressure_icon := TextureRect.new()
	pressure_icon.texture = token_assets.texture("debt_chain")
	pressure_icon.custom_minimum_size = Vector2(44, 32)
	pressure_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pressure_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pressure_icon.modulate = accent.lightened(0.05)
	pressure_box.add_child(pressure_icon)
	pressure_title = Label.new()
	pressure_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pressure_title.add_theme_color_override("font_color", colors["text"])
	pressure_title.add_theme_font_size_override("font_size", 12)
	pressure_box.add_child(pressure_title)
	pressure_message = Label.new()
	pressure_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pressure_message.add_theme_color_override("font_color", colors["muted"])
	pressure_message.add_theme_font_size_override("font_size", 10)
	pressure_box.add_child(pressure_message)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, 96 if mode == "wide" else 92)
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	board_row.add_child(_mat_zone(hand_scroll, accent, "政策カード"))
	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 9)
	hand_scroll.add_child(hand_box)

	pressure_card = RichTextLabel.new()
	pressure_card.bbcode_enabled = true
	pressure_card.fit_content = true
	pressure_card.scroll_active = false
	pressure_card.visible = false
	box.add_child(pressure_card)

	var planned_row := HBoxContainer.new()
	planned_row.add_theme_constant_override("separation", 8)
	box.add_child(planned_row)

	planned = RichTextLabel.new()
	planned.bbcode_enabled = true
	planned.custom_minimum_size = Vector2(170, 70)
	planned.scroll_active = false
	planned_row.add_child(_mat_zone(planned, accent, "政策案"))

	var worker_scroll := ScrollContainer.new()
	worker_scroll.custom_minimum_size = Vector2(210, 70)
	worker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	worker_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	planned_row.add_child(_mat_zone(worker_scroll, accent, "ワーカー"))
	var worker_box := HBoxContainer.new()
	worker_box.add_theme_constant_override("separation", 6)
	worker_scroll.add_child(worker_box)
	for worker in CountryStateScript.WORKERS:
		var button := Button.new()
		button.text = ""
		button.icon = token_assets.texture(UiCatalogScript.worker_token(worker))
		button.expand_icon = false
		button.tooltip_text = "%s: %s" % [UiCatalogScript.worker_name(worker), UiCatalogScript.worker_tip(worker)]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(42, 36)
		button.add_theme_stylebox_override("normal", _stylebox(Color(0.095, 0.078, 0.052, 0.96), colors["line"], 4))
		button.add_theme_stylebox_override("hover", _stylebox(Color(0.15, 0.11, 0.065, 0.98), accent, 4))
		button.add_theme_stylebox_override("pressed", _stylebox(Color(0.19, 0.13, 0.065, 1.0), accent.lightened(0.18), 4))
		button.pressed.connect(func() -> void:
			worker_assigned.emit(country_index, worker)
		)
		worker_box.add_child(button)
		worker_buttons[worker] = button

	track_views.clear()

	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.fit_content = true
	detail.scroll_active = false
	if false:
		box.add_child(_mat_zone(detail, accent, "カード詳細"))

func _rebuild_hand(country, phase: String, is_finished: bool) -> void:
	for child in hand_box.get_children():
		child.queue_free()
	for i in range(country.hand.size()):
		hand_box.add_child(_make_hand_card(country, i, country.hand[i], phase, is_finished))

func _make_hand_card(country, hand_index: int, card: Dictionary, phase: String, is_finished: bool) -> Control:
	var disabled: bool = card.get("type", "") != "policy" or phase == "simultaneous_reveal" or is_finished
	var selected: bool = not country.selected_policy.is_empty() and country.selected_policy.get("id", "") == card.get("id", "")
	var color: Color = colors["card"] if card.get("type", "") == "policy" else colors["card_dark"]
	var border: Color = accent if selected else colors["line"]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(108, 68)
	panel.tooltip_text = card.get("description", "状態カード")
	panel.add_theme_stylebox_override("panel", _card_style(color.darkened(0.08) if disabled else color, border, selected))
	panel.mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if disabled:
			return
		if event is InputEventMouseButton and event.pressed:
			policy_selected.emit(country_index, hand_index)
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(38, 42)
	icon_frame.add_theme_stylebox_override("panel", _stylebox(Color(0.035, 0.030, 0.022, 0.70), border, 3))
	row.add_child(icon_frame)
	var icon := TextureRect.new()
	icon.texture = token_assets.texture(UiCatalogScript.card_token(card))
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_frame.add_child(icon)

	var label := Label.new()
	label.text = UiCatalogScript.short_card_name(card)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", colors["ink"] if card.get("type", "") == "policy" else colors["text"])
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)
	return panel

func _make_track_chip(key: String) -> Dictionary:
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(48, 52)
	root.add_theme_constant_override("separation", 2)
	var icon := TextureRect.new()
	icon.texture = token_assets.texture(UiCatalogScript.track_token(key))
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(icon)
	var name := Label.new()
	name.text = UiCatalogScript.short_track_name(key)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_color_override("font_color", colors["muted"])
	name.add_theme_font_size_override("font_size", 10)
	root.add_child(name)
	var tokens := HBoxContainer.new()
	tokens.alignment = BoxContainer.ALIGNMENT_CENTER
	tokens.add_theme_constant_override("separation", 1)
	root.add_child(tokens)
	return {"root": root, "icon": icon, "tokens": tokens, "key": key}

func _update_track_chip(chip: Dictionary, value: int) -> void:
	var root: Control = chip["root"]
	var key := String(chip["key"])
	var color := TrackPresenterScript.track_color(key, value, colors)
	root.add_theme_stylebox_override("panel", _stylebox(Color(0.06, 0.065, 0.07, 0.92), color, 6))
	chip["icon"].modulate = color.lightened(0.2)
	var tokens: HBoxContainer = chip["tokens"]
	for child in tokens.get_children():
		child.queue_free()
	var filled := TrackPresenterScript.marker_count(key, value)
	for i in range(5):
		tokens.add_child(_pip(color if i < filled else colors["token_empty"], 8))

func _card_frame(child: Control, frame_accent: Color, caption: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _stylebox(Color(0.075, 0.066, 0.045, 0.92), frame_accent.darkened(0.04), 6))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override("font_color", frame_accent.lightened(0.25))
	label.add_theme_font_size_override("font_size", 11)
	box.add_child(label)
	box.add_child(child)
	return panel

func _mat_zone(child: Control, frame_accent: Color, caption: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _stylebox(Color(0.035, 0.030, 0.022, 0.46), frame_accent.darkened(0.03), 5))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override("font_color", frame_accent.lightened(0.28))
	label.add_theme_font_size_override("font_size", 11)
	box.add_child(label)
	box.add_child(child)
	return panel

func _pip(color: Color, size: int) -> PanelContainer:
	var pip := PanelContainer.new()
	pip.custom_minimum_size = Vector2(size, size)
	pip.add_theme_stylebox_override("panel", _stylebox(color, colors["token_edge"], size / 2))
	return pip

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
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 3)
	return style

func _mat_style(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := _stylebox(color, border, radius)
	style.set_border_width_all(2)
	style.content_margin_left = 11
	style.content_margin_right = 11
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 5)
	return style

func _card_style(color: Color, border: Color, selected: bool) -> StyleBoxFlat:
	var style := _stylebox(color, border, 5)
	style.set_border_width_all(2 if selected else 1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.36)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style
