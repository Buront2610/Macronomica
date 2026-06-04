extends VBoxContainer
class_name WorldBoard

const UiCatalogScript := preload("res://src/ui/support/ui_catalog.gd")
const TrackPresenterScript := preload("res://src/ui/support/track_presenter.gd")

const WORLD_TRACKS := [
	"world_demand",
	"world_interest_rate",
	"trade_openness",
	"international_financial_instability",
	"depression",
	"protectionism",
	"global_coordination"
]

var token_assets
var colors: Dictionary = {}
var compact := false

func setup(next_token_assets, next_colors: Dictionary, next_compact: bool = false) -> void:
	token_assets = next_token_assets
	colors = next_colors
	compact = next_compact
	add_theme_constant_override("separation", 10)

func refresh(world) -> void:
	for child in get_children():
		child.queue_free()

	var event_card := RichTextLabel.new()
	event_card.bbcode_enabled = true
	event_card.fit_content = true
	event_card.scroll_active = false
	event_card.text = "[b]%s[/b]\n%s\n\n山札 %d / 捨札 %d" % [
		world.current_event.get("display_name", ""),
		world.current_event.get("message", ""),
		world.event_deck.size(),
		world.event_discard.size()
	]
	add_child(_event_frame(event_card, world))

	var track_grid := GridContainer.new()
	track_grid.columns = 2
	track_grid.add_theme_constant_override("h_separation", 8)
	track_grid.add_theme_constant_override("v_separation", 8)
	add_child(track_grid)
	var tracks := WORLD_TRACKS.slice(0, 4) if compact else WORLD_TRACKS
	for key in tracks:
		track_grid.add_child(_track_bar(key, int(world.tracks.get(key, 0))))

func _track_bar(key: String, value: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(132, 70)
	panel.add_theme_stylebox_override("panel", _stylebox(Color(0.060, 0.048, 0.030, 0.68), TrackPresenterScript.track_color(key, value, colors).darkened(0.08), 6))
	var tile := VBoxContainer.new()
	tile.alignment = BoxContainer.ALIGNMENT_CENTER
	tile.add_theme_constant_override("separation", 3)
	panel.add_child(tile)

	var seal := TextureRect.new()
	seal.texture = token_assets.texture(UiCatalogScript.track_token(key))
	seal.custom_minimum_size = Vector2(30, 24)
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.modulate = TrackPresenterScript.track_color(key, value, colors).lightened(0.2)
	tile.add_child(seal)

	var label := Label.new()
	label.text = _world_short_name(key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", colors["text"])
	label.add_theme_font_size_override("font_size", 11)
	tile.add_child(label)

	var rail := HBoxContainer.new()
	rail.alignment = BoxContainer.ALIGNMENT_CENTER
	rail.add_theme_constant_override("separation", 2)
	tile.add_child(rail)

	var filled := TrackPresenterScript.marker_count(key, value)
	var color := TrackPresenterScript.track_color(key, value, colors)
	for i in range(7):
		rail.add_child(_pip(color if i < filled else colors["token_empty"], 10))
	return panel

func _event_frame(child: Control, world) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _stylebox(Color(0.13, 0.092, 0.048, 0.72), colors["warn"], 6))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var seal := TextureRect.new()
	seal.texture = token_assets.texture("world_demand_globe")
	seal.custom_minimum_size = Vector2(54, 74)
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.modulate = colors["warn"].lightened(0.18)
	box.add_child(seal)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(text_box)
	var label := Label.new()
	label.text = "公開イベント"
	label.add_theme_color_override("font_color", colors["warn"].lightened(0.25))
	label.add_theme_font_size_override("font_size", 11)
	text_box.add_child(label)
	text_box.add_child(child)
	return panel

func _world_short_name(key: String) -> String:
	var names := {
		"world_demand": "需要",
		"world_interest_rate": "金利",
		"trade_openness": "貿易",
		"international_financial_instability": "金融不安",
		"depression": "恐慌",
		"protectionism": "保護",
		"global_coordination": "協調"
	}
	return names.get(key, UiCatalogScript.track_name(key))

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
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style
