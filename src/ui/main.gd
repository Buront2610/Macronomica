extends Control

const GameStateScript := preload("res://src/core/game_state.gd")
const PolicyRecommenderScript := preload("res://src/app/policy_recommender.gd")
const TokenAssetsScript := preload("res://src/ui/support/token_assets.gd")
const UiCatalogScript := preload("res://src/ui/support/ui_catalog.gd")
const TrackPresenterScript := preload("res://src/ui/support/track_presenter.gd")
const CardTextFormatterScript := preload("res://src/ui/support/card_text_formatter.gd")
const BoardLayoutScript := preload("res://src/ui/support/board_layout.gd")
const BoardPieceScript := preload("res://src/ui/support/board_piece.gd")
const BoardTrailScript := preload("res://src/ui/support/board_trail.gd")
const BoardResolutionOverlayScript := preload("res://src/ui/support/board_resolution_overlay.gd")

const INK := Color(0.08, 0.065, 0.045)
const TEXT := Color(0.98, 0.96, 0.86)
const MUTED := Color(0.80, 0.76, 0.64)
const BOARD_LINE := Color(0.78, 0.53, 0.22, 1.0)
const CARD_FACE := Color(0.92, 0.84, 0.64, 1.0)
const CARD_BACK := Color(0.08, 0.10, 0.09, 0.88)
const GOOD := Color(0.22, 0.64, 0.43)
const WARN := Color(0.90, 0.58, 0.18)
const BAD := Color(0.78, 0.23, 0.18)
const BLUE := Color(0.28, 0.58, 0.82)
const TOKEN_EMPTY := Color(0.10, 0.075, 0.045, 0.94)
const COUNTRY_ACCENTS := [
	Color(0.42, 0.66, 0.88),
	Color(0.32, 0.70, 0.58),
	Color(0.86, 0.62, 0.28),
	Color(0.76, 0.42, 0.38)
]
const AGENDA := [
	{"name": "協調刺激", "tag": "cooperation", "icon": "協", "hint": "需要・協調"},
	{"name": "流動性", "tag": "liquidity", "icon": "流", "hint": "金融安定"},
	{"name": "関税凍結", "tag": "trade", "icon": "関", "hint": "通商摩擦"},
	{"name": "債務再編", "tag": "debt", "icon": "債", "hint": "債務支援"}
]
const WORLD_TRACKS := [
	"world_demand",
	"world_interest_rate",
	"trade_openness",
	"international_financial_instability",
	"depression",
	"protectionism",
	"global_coordination"
]
const WORKERS := ["bureaucrats", "central_bank_staff", "diplomat", "auditor", "lobbyist"]
const COST_KEYS := ["fiscal", "political", "administrative", "credibility", "international", "industrial"]
const BODY_FONT_MIN := 16
const MICRO_FONT_MIN := 12

var game
var token_assets
var bg_texture: Texture2D
var board_layer: Control
var selected_country_index := 0
var phase_pips: Array = []
var country_seats: Array = []
var country_policy_slots: Array = []
var country_policy_labels: Array = []
var country_stamp_slots: Array = []
var country_worker_icons: Array = []
var country_pressure_labels: Array = []
var country_state_labels: Array = []
var country_chip_racks: Array = []
var country_next_labels: Array = []
var country_pipeline_labels: Array = []
var country_election_labels: Array = []
var country_welfare_labels: Array = []
var planning_country_panel: Control
var planning_country_title: Label
var planning_country_subtitle: Label
var planning_country_pressure: Label
var planning_country_stats: Label
var planning_country_progress: Label
var policy_menu_nodes: Array = []
var negotiation_country_cards: Array = []
var negotiation_country_labels: Array = []
var negotiation_focus_label: Label
var negotiation_status_label: Label
var negotiation_guide_label: Label
var domestic_state_labels: Array = []
var domestic_state_cards: Array = []
var domestic_state_deck_label: Label
var policy_preview_panel: Control
var policy_preview_label: Label
var policy_focus_card: Control
var policy_focus_icon: TextureRect
var policy_focus_title: Label
var policy_focus_source: Label
var policy_focus_cost: Label
var policy_preview_index := 0
var policy_menu_page := 0
var worker_nodes := {}
var policy_slot
var policy_slot_label: Label
var policy_cost_labels: Array = []
var collapse_warning
var log_panel
var score_panel
var country_detail_label: Label
var last_selected_country_index := 0
var board_layout: Dictionary = {}
var resolution_step_nodes: Array = []
var resolution_step_labels: Array = []
var resolution_overlay
var resolution_marker_layer: Control
var last_resolution_snapshot: Dictionary = {}
var resolution_review_active := false
var resolution_step_index := -1
var worker_assignment_confirmed: Array = []
var final_score_panel
var final_score_labels: Array = []
var final_news_label: Label
var entry_state := "title"
var title_overlay: Control
var tutorial_overlay: Control
var tutorial_return_state := "country_select"
var country_select_overlay: Control
var player_country_index := -1
var turn_news_panel
var turn_news_label: Label
var turn_news_active := false
var log_highlight_key := ""

func _ready() -> void:
	_apply_preview_window_size()
	token_assets = TokenAssetsScript.new()
	bg_texture = load("res://assets/ui/policy_room_background.png")
	game = GameStateScript.new()
	game.new_game()
	_build_board()
	_refresh_board(true)
	_apply_preview_state_from_env()

func _apply_preview_window_size() -> void:
	var width := int(OS.get_environment("MACRONOMICA_PREVIEW_WIDTH"))
	var height := int(OS.get_environment("MACRONOMICA_PREVIEW_HEIGHT"))
	if width > 0 and height > 0:
		DisplayServer.window_set_size(Vector2i(width, height))
		size = Vector2(width, height)

func _apply_preview_state_from_env() -> void:
	var preview_state := OS.get_environment("MACRONOMICA_PREVIEW_STATE")
	if preview_state.is_empty():
		return
	if preview_state == "title":
		return
	if preview_state == "country_select":
		_show_country_select()
		return
	if preview_state == "tutorial":
		_show_tutorial_overlay("country_select")
		return
	_hide_entry_overlays()
	if preview_state == "negotiation":
		_refresh_board(false)
		return
	game.move_to_phase("policy_planning")
	selected_country_index = 0
	if preview_state == "policy_submitted":
		var policy_index := _preview_first_policy_index(game.policy_options(0))
		if policy_index >= 0:
			game.select_policy(0, policy_index)
		selected_country_index = 1
	elif preview_state == "worker_assignment":
		_preview_submit_all_policies()
		game.move_to_phase("worker_assignment")
		_reset_worker_confirmations()
	elif preview_state == "simultaneous_reveal":
		_preview_submit_all_policies()
		game.move_to_phase("worker_assignment")
		_preview_assign_workers()
		game.move_to_phase("simultaneous_reveal")
	elif preview_state == "resolution":
		_preview_submit_all_policies()
		game.move_to_phase("worker_assignment")
		_preview_assign_workers()
		game.move_to_phase("resolution")
		resolution_review_active = true
		resolution_step_index = maxi(0, int(OS.get_environment("MACRONOMICA_PREVIEW_RESOLUTION_STEP")))
		last_resolution_snapshot = game.preview_resolution_outcome()
	elif preview_state == "final":
		game.world.tracks["depression"] = 10
		game.resolve_turn()
	_refresh_board(false)

func _preview_submit_all_policies() -> void:
	for country_index in range(game.countries.size()):
		var policy_index := _preview_first_policy_index(game.policy_options(country_index))
		if policy_index >= 0:
			game.select_policy(country_index, policy_index)

func _preview_assign_workers() -> void:
	var workers := ["bureaucrats", "central_bank_staff", "diplomat", "auditor"]
	for country_index in range(game.countries.size()):
		game.assign_worker(country_index, workers[country_index % workers.size()])
		if country_index < worker_assignment_confirmed.size():
			worker_assignment_confirmed[country_index] = true

func _preview_first_policy_index(cards: Array) -> int:
	for i in range(cards.size()):
		if cards[i].get("type", "") == "policy":
			return i
	return -1

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_rebuild_board()

func _rebuild_board() -> void:
	for child in get_children():
		child.queue_free()
	_build_board()
	_refresh_board(false)

func _build_board() -> void:
	board_layout = BoardLayoutScript.for_screen(_screen())
	_add_background()
	board_layer = Control.new()
	board_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(board_layer)
	_build_surfaces()
	_build_table_marks()
	_build_event_card()
	_build_world_tracks()
	_build_planning_country_panel()
	_build_collapse_warning()
	_build_agenda_tiles()
	_build_country_seats()
	_build_policy_slot()
	_build_resolution_flow()
	_build_domestic_state_panel()
	_build_policy_preview_panel()
	_build_policy_menu_slots()
	_build_worker_tokens()
	_build_status_panels()
	_build_country_detail_panel()
	_build_resolution_overlay()
	_build_final_score_overlay()
	_build_turn_news_overlay()
	_build_entry_overlays()

func _add_background() -> void:
	var bg := TextureRect.new()
	bg.texture = bg_texture
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.018, 0.020, 0.14)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

func _build_surfaces() -> void:
	var play = _make_piece("PlaySurface", board_layout["play_surface_pos"], board_layout["play_surface_size"], Color(0.030, 0.037, 0.034, 0.16), Color(0.62, 0.45, 0.22, 0.28), 1, "plaque")
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var menu_panel = _make_piece("PolicyMenuPanel", board_layout["hand_panel_pos"], board_layout["hand_panel_size"], Color(0.070, 0.050, 0.030, 0.94), BOARD_LINE, 2, "plaque")
	menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var menu_title := _add_label_to(menu_panel, "PolicyMenuTitle", "政策カード一覧", Vector2(22, 10), Vector2(690, 28), 20, WARN.lightened(0.18), false)
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var menu_legend := _add_label_to(menu_panel, "PolicyMenuLegend", "出所: 共通 / 構造 / 協調 / 固有 / 危機", Vector2(730, 14), Vector2(menu_panel.size.x - 758, 22), 14, MUTED, false)
	menu_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add_action_token("PolicyPagePrev", "前へ", board_layout["policy_page_prev_pos"], board_layout["policy_page_button_size"], _on_policy_page_prev)
	_add_action_token("PolicyPageNext", "次へ", board_layout["policy_page_next_pos"], board_layout["policy_page_button_size"], _on_policy_page_next)

func _build_table_marks() -> void:
	_add_label("Title", "マクロノミカ", board_layout["title_pos"], board_layout["title_size"], 39, TEXT)
	var objective = _make_piece("ObjectiveHeader", board_layout["objective_pos"], board_layout["objective_size"], Color(0.070, 0.046, 0.020, 0.94), WARN.lightened(0.10), 2, "card")
	objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(objective, "ObjectiveKicker", "", Vector2(14, 8), Vector2(58, 22), 15, WARN.lightened(0.22), false).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_add_label_to(objective, "ObjectiveText", "", Vector2(80, 5), Vector2(objective.size.x - 96, 31), 24, TEXT, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_add_label_to(objective, "ObjectiveHint", "", Vector2(80, 38), Vector2(objective.size.x - 96, 21), 16, MUTED, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_add_label("TurnLabel", "", board_layout["turn_pos"], board_layout["turn_size"], 20, TEXT)
	phase_pips.clear()
	var phase_start: Vector2 = board_layout["phase_pip_start"]
	var phase_step: Vector2 = board_layout["phase_pip_step"]
	for i in range(GameStateScript.PHASES.size()):
		var pip = _make_piece("PhasePip_%d" % i, phase_start + phase_step * i, board_layout["phase_pip_size"], Color(0.04, 0.035, 0.026, 0.55), BOARD_LINE)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		phase_pips.append(pip)
	_add_action_token("RestartToken", "↺", board_layout["utility_command_pos"], board_layout["action_size"], _on_restart_pressed)
	var help = _add_action_token("HelpToken", "?", board_layout["help_command_pos"], board_layout["help_command_size"], _on_help_pressed)
	help.tooltip_text = "遊び方とこのターンで見る場所を確認します。"
	var recommend = _add_action_token("RecommendToken", "自動", board_layout["recommend_command_pos"], board_layout["recommend_command_size"], _on_recommend_pressed)
	recommend.tooltip_text = "テストプレイ補助"
	_add_action_token("AdvanceToken", "次", board_layout["advance_command_pos"], Vector2(108, 108), _on_advance_pressed)

func _build_event_card() -> void:
	var card = _make_piece("EventCard", board_layout["event_pos"], board_layout["event_size"], Color(0.13, 0.085, 0.040, 0.94), WARN, 2, "card")
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_make_icon("world_demand_globe", Vector2(14, 46), Vector2(50, 50), WARN))
	_add_label_to(card, "EventCaption", "公開イベント", Vector2(0, 10), Vector2(card.size.x, 22), 15, WARN.lightened(0.2))
	_add_label_to(card, "EventTitle", "", Vector2(68, 36), Vector2(card.size.x - 78, 38), 19, TEXT, true)
	_add_label_to(card, "EventMessage", "", Vector2(68, 78), Vector2(card.size.x - 78, 58), 13, TEXT, true)
	_add_label_to(card, "EventDeck", "", Vector2(68, 138), Vector2(card.size.x - 78, 20), 12, TEXT)

func _build_world_tracks() -> void:
	var panel = _make_piece("WorldPanel", board_layout["world_panel_pos"], board_layout["world_panel_size"], Color(0.030, 0.035, 0.034, 0.76), BLUE.lightened(0.05), 2, "plaque")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(panel, "WorldPanelTitle", "世界危機ボード", Vector2(0, 12), Vector2(panel.size.x, 34), 28, WARN.lightened(0.18))
	_add_label_to(panel, "WorldPanelHint", "政策の波及先", Vector2(0, panel.size.y - 34), Vector2(panel.size.x, 24), 16, MUTED)
	var start: Vector2 = board_layout["world_tracks_origin"]
	var step: Vector2 = board_layout["world_track_step"]
	for i in range(WORLD_TRACKS.size()):
		var key: String = WORLD_TRACKS[i]
		var col := i % 4
		var row := floori(float(i) / 4.0)
		var tile_pos := start + Vector2(step.x * col, step.y * row)
		var tile = _make_piece("WorldTrack_%s" % key, tile_pos, board_layout["world_track_size"], Color(0.020, 0.019, 0.016, 0.78), BLUE, 1, "card")
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_size: float = minf(58.0, tile.size.y - 58.0)
		tile.add_child(_make_icon(UiCatalogScript.track_token(key), Vector2(16, 16), Vector2(icon_size, icon_size), Color.WHITE, "TrackIcon"))
		var label := _add_label_to(tile, "TrackLabel", _world_short_name(key), Vector2(88, 10), Vector2(tile.size.x - 170, 34), 26, WARN.lightened(0.18), true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var value_label := _add_label_to(tile, "TrackValue", "", Vector2(tile.size.x - 90, 8), Vector2(74, 38), 30, WARN.lightened(0.18), false)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var meaning := _add_label_to(tile, "TrackMeaning", "", Vector2(88, 50), Vector2(tile.size.x - 104, 30), 18, MUTED, false)
		meaning.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var rail := Control.new()
		rail.name = "TrackRail"
		rail.position = Vector2(20, tile.size.y - 32)
		rail.size = Vector2(tile.size.x - 40, 20)
		tile.add_child(rail)
	var event_slot_pos := start + Vector2(step.x * 3.0, step.y)
	var event_slot = _make_piece("WorldEventSummary", event_slot_pos, board_layout["world_track_size"], Color(0.058, 0.040, 0.024, 0.88), WARN, 2, "card")
	event_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_slot.add_child(_make_icon("world_demand_globe", Vector2(16, 18), Vector2(52, 52), WARN.lightened(0.16), "WorldEventIcon"))
	var event_caption := _add_label_to(event_slot, "WorldEventSummaryCaption", "現在イベント", Vector2(84, 10), Vector2(event_slot.size.x - 100, 24), 16, WARN.lightened(0.18), false)
	event_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var event_title := _add_label_to(event_slot, "WorldEventSummaryTitle", "", Vector2(84, 34), Vector2(event_slot.size.x - 100, 32), 21, TEXT, true)
	event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var event_message := _add_label_to(event_slot, "WorldEventSummaryMessage", "", Vector2(18, 72), Vector2(event_slot.size.x - 36, event_slot.size.y - 84), 15, MUTED, true)
	event_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	event_message.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _build_planning_country_panel() -> void:
	var panel_pos: Vector2 = board_layout["planning_country_pos"]
	var panel_size: Vector2 = board_layout["planning_country_size"]
	planning_country_panel = _make_piece("PlanningCountryPanel", panel_pos, panel_size, Color(0.050, 0.036, 0.024, 0.92), COUNTRY_ACCENTS[0], 3, "plaque")
	planning_country_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(planning_country_panel, "PlanningCountryCaption", "政策計画フレーム", Vector2(20, 9), Vector2(170, 18), 13, WARN.lightened(0.18), false).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_add_label_to(planning_country_panel, "PlanningCountryEmblem", "", Vector2(20, 30), Vector2(66, 54), 44, TEXT, false)
	planning_country_title = _add_label_to(planning_country_panel, "PlanningCountryTitle", "", Vector2(96, 21), Vector2(310, 34), 21, TEXT, true)
	planning_country_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	planning_country_subtitle = _add_label_to(planning_country_panel, "PlanningCountrySubtitle", "", Vector2(96, 58), Vector2(310, 24), 14, MUTED, false)
	planning_country_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	planning_country_pressure = _add_label_to(planning_country_panel, "PlanningCountryPressure", "", Vector2(430, 18), Vector2(230, 28), 16, TEXT, true)
	planning_country_pressure.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	planning_country_stats = _add_label_to(planning_country_panel, "PlanningCountryStats", "", Vector2(430, 48), Vector2(260, 42), 15, WARN.lightened(0.20), true)
	planning_country_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	planning_country_progress = _add_label_to(planning_country_panel, "PlanningCountryProgress", "", Vector2(panel_size.x - 122, 24), Vector2(104, 54), 18, TEXT, true)
	planning_country_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	planning_country_progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _build_agenda_tiles() -> void:
	negotiation_country_cards.clear()
	negotiation_country_labels.clear()
	var negotiation = _make_piece("NegotiationPanel", board_layout["negotiation_pos"], board_layout["negotiation_size"], Color(0.056, 0.038, 0.022, 0.88), BOARD_LINE, 3, "plaque")
	negotiation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _add_label_to(negotiation, "NegotiationTitle", "国際交渉", Vector2(26, 14), Vector2(170, 34), 27, WARN.lightened(0.16))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	negotiation_focus_label = _add_label_to(negotiation, "NegotiationFocus", "", Vector2(198, 18), Vector2(negotiation.size.x - 396, 30), 20, TEXT, false)
	negotiation_focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	negotiation_status_label = _add_label_to(negotiation, "NegotiationStatus", "", Vector2(negotiation.size.x - 188, 18), Vector2(158, 30), 18, WARN.lightened(0.10), false)
	negotiation_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	negotiation_guide_label = _add_label_to(negotiation, "NegotiationGuide", "", Vector2(28, 52), Vector2(negotiation.size.x - 56, 26), 16, MUTED, false)
	negotiation_guide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var start: Vector2 = board_layout["agenda_origin"]
	var step: Vector2 = board_layout["agenda_step"]
	for i in range(AGENDA.size()):
		var item: Dictionary = AGENDA[i]
		var tile = _make_piece("Agenda_%s" % item["tag"], start + step * i, board_layout["agenda_size"], Color(0.15, 0.105, 0.055, 0.92), BOARD_LINE, 2, "card")
		tile.tooltip_text = "選択中の国がこの交渉議題を宣言し、同じタグの政策が議題に上がりやすくなります。"
		tile.pressed = func(tag := String(item["tag"])) -> void:
			_on_agenda_declared(tag)
		_add_label_to(tile, "AgendaIcon", String(item["icon"]), Vector2(10, 12), Vector2(56, 48), 34, WARN.lightened(0.05))
		var agenda_name := _add_label_to(tile, "AgendaName", String(item["name"]), Vector2(70, 15), Vector2(tile.size.x - 82, 28), 21, TEXT, false)
		agenda_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var agenda_hint := _add_label_to(tile, "AgendaHint", String(item["hint"]), Vector2(72, 47), Vector2(tile.size.x - 86, 20), 14, MUTED, false)
		agenda_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_add_label_to(tile, "AgendaAction", "宣言", Vector2(14, 74), Vector2(tile.size.x - 28, 20), 15, WARN.lightened(0.18))
		var pips := Control.new()
		pips.name = "AgendaPips"
		pips.position = Vector2(tile.size.x * 0.5 - 38.0, 96)
		pips.size = Vector2(86, 10)
		tile.add_child(pips)
	var country_w: float = (negotiation.size.x - 300.0) / 4.0
	var country_y: float = negotiation.size.y - 56.0
	for i in range(4):
		var card: Control = _make_child_piece(negotiation, "NegotiationCountry_%d" % i, Vector2(24.0 + country_w * i, country_y), Vector2(country_w - 8.0, 42), Color(0.032, 0.030, 0.024, 0.90), COUNTRY_ACCENTS[i], 1, "card")
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.pressed = func(country_index := i) -> void:
			selected_country_index = country_index
			_refresh_board(true)
		var label := _add_label_to(card, "NegotiationCountryLabel", "", Vector2(10, 7), Vector2(card.size.x - 20, 26), 15, TEXT, false)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		negotiation_country_cards.append(card)
		negotiation_country_labels.append(label)

func _build_country_seats() -> void:
	country_seats.clear()
	country_policy_slots.clear()
	country_policy_labels.clear()
	country_stamp_slots.clear()
	country_worker_icons.clear()
	country_pressure_labels.clear()
	country_state_labels.clear()
	country_chip_racks.clear()
	country_next_labels.clear()
	country_pipeline_labels.clear()
	country_election_labels.clear()
	country_welfare_labels.clear()
	var positions: Array = board_layout["country_seat_positions"]
	var seat_size: Vector2 = board_layout["country_seat_size"]
	for i in range(game.countries.size()):
		var accent: Color = COUNTRY_ACCENTS[i]
		var seat = _make_piece("CountrySeat_%d" % i, positions[i], seat_size, Color(0.060, 0.046, 0.030, 0.88), accent, 2, "card")
		seat.pressed = func(country_index := i) -> void:
			_on_country_selected(country_index)
		var country = game.countries[i]
		var title := _add_label_to(seat, "CountryTitle", "%s国" % UiCatalogScript.country_emblem(i), Vector2(18, 12), Vector2(62, 34), 31, accent.lightened(0.22))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var subtitle := _add_label_to(seat, "CountryType", _ellipsize(country.display_name.substr(3), 28), Vector2(88, 14), Vector2(seat_size.x - 206, 30), 18, MUTED)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

		var pressure = _make_child_piece(seat, "PressureCard", Vector2(20, 58), Vector2(seat_size.x * 0.47, 102), Color(0.86, 0.76, 0.55, 0.96), accent, 1, "card")
		var pressure_label := _add_label_to(pressure, "PressureLabel", "", Vector2(14, 12), pressure.size - Vector2(28, 24), 17, INK, true)
		pressure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		country_pressure_labels.append(pressure_label)

		var state_card = _make_child_piece(seat, "StateSummaryCard", Vector2(seat_size.x * 0.53, 58), Vector2(seat_size.x * 0.40, 50), Color(0.16, 0.13, 0.10, 0.96), BAD.darkened(0.08), 2, "card")
		var state_label := _add_label_to(state_card, "StateSummaryLabel", "", Vector2(12, 7), state_card.size - Vector2(24, 14), 15, TEXT, false)
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		state_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		country_state_labels.append(state_label)

		var policy = _make_child_piece(seat, "PolicySlot", Vector2(seat_size.x * 0.53, 118), Vector2(seat_size.x * 0.40, 54), Color(0.032, 0.038, 0.038, 0.94), accent, 2, "card")
		var policy_label := _add_label_to(policy, "PolicyLabel", "", Vector2(12, 10), Vector2(policy.size.x - 24, 34), 16, TEXT, false)
		country_policy_slots.append(policy)
		country_policy_labels.append(policy_label)

		var stamp = _make_child_piece(seat, "StampSlot", Vector2(seat_size.x - 82, 12), Vector2(64, 64), Color(0.020, 0.018, 0.014, 0.68), accent, 1, "circle")
		stamp.add_child(_make_icon("bureaucrat_seal", Vector2.ZERO, stamp.size, Color.WHITE, "WorkerIcon"))
		_add_label_to(stamp, "WorkerCount", "", Vector2(38, 38), Vector2(22, 20), 12, WARN.lightened(0.18))
		country_stamp_slots.append(stamp)
		country_worker_icons.append(stamp.get_node("WorkerIcon"))

		var info_y := seat_size.y - 58.0
		var next_label := _add_label_to(seat, "NextDeckLabel", "", Vector2(20, info_y), Vector2(seat_size.x * 0.35, 24), 14, MUTED, false)
		next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		next_label.visible = false
		var pipeline_label := _add_label_to(seat, "PipelineLabel", "", Vector2(seat_size.x * 0.39, info_y), Vector2(seat_size.x * 0.21, 24), 14, WARN.lightened(0.16), false)
		pipeline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		pipeline_label.visible = false
		var election_label := _add_label_to(seat, "ElectionLabel", "", Vector2(seat_size.x * 0.62, info_y), Vector2(seat_size.x * 0.16, 24), 14, MUTED, false)
		election_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		election_label.visible = false
		var welfare_label := _add_label_to(seat, "WelfareLabel", "", Vector2(seat_size.x - 112, 16), Vector2(94, 28), 17, WARN.lightened(0.16), false)
		welfare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		country_next_labels.append(next_label)
		country_pipeline_labels.append(pipeline_label)
		country_election_labels.append(election_label)
		country_welfare_labels.append(welfare_label)

		var chips := Control.new()
		chips.name = "RiskChips"
		chips.position = Vector2(20, seat_size.y - 34)
		chips.size = Vector2(seat_size.x - 40, 28)
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seat.add_child(chips)
		country_chip_racks.append(chips)
		country_seats.append(seat)

func _build_policy_slot() -> void:
	policy_slot = _make_piece("PolicySlot", board_layout["policy_slot_pos"], board_layout["policy_slot_size"], Color(0.050, 0.036, 0.024, 0.84), BOARD_LINE, 2, "card")
	policy_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot_size: Vector2 = board_layout["policy_slot_size"]
	_add_label_to(policy_slot, "PolicySlotTitle", "操作ガイド", Vector2(0, 8), Vector2(slot_size.x, 24), 17, WARN.lightened(0.18))
	policy_slot_label = _add_label_to(policy_slot, "PolicySlotLabel", "", Vector2(16, 34), Vector2(slot_size.x - 32, 42), 14, TEXT, true)
	policy_cost_labels.clear()
	var socket_w := (slot_size.x - 28.0) / float(COST_KEYS.size())
	for i in range(COST_KEYS.size()):
		var socket = _make_child_piece(policy_slot, "CostSocket_%s" % COST_KEYS[i], Vector2(14 + socket_w * i, slot_size.y - 22), Vector2(socket_w - 4, 15), Color(0.020, 0.018, 0.014, 0.68), BOARD_LINE.darkened(0.30), 1, "plaque")
		var label := _add_label_to(socket, "CostSocketLabel", "", Vector2(1, 1), socket.size - Vector2(2, 2), 8, MUTED, true)
		policy_cost_labels.append(label)

func _build_collapse_warning() -> void:
	var screen := _screen()
	collapse_warning = _make_piece("CollapseWarning", Vector2(420, 82), Vector2(screen.x - 900.0, 34), Color(0.36, 0.045, 0.025, 0.92), BAD.lightened(0.20), 2, "plaque")
	collapse_warning.z_index = 18
	collapse_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(collapse_warning, "CollapseWarningText", "", Vector2(14, 6), collapse_warning.size - Vector2(28, 12), 15, TEXT, true)
	collapse_warning.visible = false

func _build_resolution_flow() -> void:
	resolution_step_nodes.clear()
	resolution_step_labels.clear()
	var flow_pos: Vector2 = board_layout["resolution_flow_pos"]
	var flow_size: Vector2 = board_layout["resolution_flow_size"]
	var panel = _make_piece("ResolutionFlow", flow_pos, flow_size, Color(0.055, 0.040, 0.026, 0.94), BOARD_LINE, 2, "plaque")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _add_label_to(panel, "ResolutionFlowTitle", "解決レビュー", Vector2(18, 10), Vector2(190, 30), 23, WARN.lightened(0.18))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var hint := _add_label_to(panel, "ResolutionFlowHint", "次 = 1段階ずつ読む / 一括 = このターンを即解決", Vector2(flow_size.x - 430, 13), Vector2(408, 24), 15, MUTED, false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var stage_title := _add_label_to(panel, "ResolutionStageTitle", "", Vector2(28, 43), Vector2(242, 30), 20, TEXT, false)
	stage_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var stage_help := _add_label_to(panel, "ResolutionStageHelp", "", Vector2(282, 42), Vector2(flow_size.x - 312, 34), 16, TEXT, true)
	stage_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stage_help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var names := ["圧力", "コスト", "国内", "世界", "デッキ", "合成"]
	var step_w := (flow_size.x - 38.0) / float(names.size())
	for i in range(names.size()):
		var step = _make_child_piece(panel, "ResolutionStep_%d" % i, Vector2(18 + step_w * i, 92), Vector2(step_w - 8, 50), Color(0.030, 0.026, 0.020, 0.84), BOARD_LINE.darkened(0.18), 1, "card")
		_add_label_to(step, "StepName", names[i], Vector2(0, 4), Vector2(step.size.x, 17), 13, MUTED)
		var label := _add_label_to(step, "StepValue", "-", Vector2(4, 24), Vector2(step.size.x - 8, 20), 14, TEXT, true)
		resolution_step_nodes.append(step)
		resolution_step_labels.append(label)

func _build_resolution_overlay() -> void:
	resolution_overlay = BoardResolutionOverlayScript.new()
	resolution_overlay.name = "ResolutionOverlay"
	resolution_overlay.z_index = 8
	resolution_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_layer.add_child(resolution_overlay)
	resolution_marker_layer = Control.new()
	resolution_marker_layer.name = "ResolutionMarkers"
	resolution_marker_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resolution_marker_layer.z_index = 9
	resolution_marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_layer.add_child(resolution_marker_layer)

func _build_final_score_overlay() -> void:
	final_score_labels.clear()
	var screen := _screen()
	var panel_size := Vector2(minf(screen.x - 120.0, 920.0), minf(screen.y - 120.0, 520.0))
	var panel_pos := (screen - panel_size) * 0.5
	final_score_panel = _make_piece("FinalScoreOverlay", panel_pos, panel_size, Color(0.055, 0.040, 0.026, 0.96), BOARD_LINE, 3, "plaque")
	final_score_panel.z_index = 60
	final_score_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_label_to(final_score_panel, "FinalScoreTitle", "最終評議会", Vector2(0, 18), Vector2(panel_size.x, 34), 28, WARN.lightened(0.20))
	_add_label_to(final_score_panel, "FinalScoreSubtitle", "最終順位とレガシー目標", Vector2(0, 54), Vector2(panel_size.x, 22), 14, MUTED)
	var card_w := (panel_size.x - 82.0) / 4.0
	for i in range(4):
		var card = _make_child_piece(final_score_panel, "FinalScoreCard_%d" % i, Vector2(22 + (card_w + 12) * i, 96), Vector2(card_w, 210), Color(0.090, 0.065, 0.038, 0.92), COUNTRY_ACCENTS[i], 2, "card")
		card.add_child(_make_disc_label("Medal", "%d" % (i + 1), Vector2(card_w * 0.5 - 22, 14), 44, COUNTRY_ACCENTS[i]))
		var label := _add_label_to(card, "ScoreText", "", Vector2(12, 66), Vector2(card_w - 24, 132), 14, TEXT, true)
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		final_score_labels.append(label)
	var news = _make_child_piece(final_score_panel, "FinalNews", Vector2(22, 318), Vector2(panel_size.x - 44, 150), Color(0.80, 0.69, 0.49, 0.94), BOARD_LINE, 2, "card")
	_add_label_to(news, "FinalNewsTitle", "世界経済新聞 総括", Vector2(0, 8), Vector2(news.size.x, 20), 15, INK)
	final_news_label = _add_label_to(news, "FinalNewsText", "", Vector2(18, 30), Vector2(news.size.x - 36, 114), 13, INK, true)
	final_news_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	final_news_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var restart = _make_entry_button(final_score_panel, "FinalRestartButton", "↺  再戦", Vector2(panel_size.x - 128, panel_size.y - 48), Vector2(100, 34), _on_restart_pressed)
	restart.set_skin(Color(0.060, 0.044, 0.028, 0.94), BOARD_LINE, 2, "card")
	final_score_panel.visible = false

func _build_turn_news_overlay() -> void:
	var panel_pos: Vector2 = board_layout["news_drawer_pos"]
	var panel_size: Vector2 = board_layout["news_drawer_size"]
	turn_news_panel = _make_piece("TurnNewsOverlay", panel_pos, panel_size, Color(0.045, 0.034, 0.024, 0.97), BOARD_LINE, 2, "card")
	turn_news_panel.z_index = 56
	turn_news_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_label_to(turn_news_panel, "TurnNewsTitle", "世界経済新聞 / ログ", Vector2(0, 16), Vector2(panel_size.x, 30), 22, WARN.lightened(0.18))
	turn_news_label = _add_label_to(turn_news_panel, "TurnNewsText", "", Vector2(24, 64), Vector2(panel_size.x - 48, panel_size.y - 128), 15, TEXT, true)
	turn_news_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	turn_news_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	turn_news_label.add_theme_constant_override("line_spacing", 4)
	var next = _make_entry_button(turn_news_panel, "TurnNewsNext", "閉じる", Vector2(panel_size.x - 128, panel_size.y - 48), Vector2(104, 34), _hide_turn_news_overlay)
	next.set_skin(Color(0.15, 0.105, 0.055, 0.94), BOARD_LINE, 2, "card")
	turn_news_panel.visible = false

func _build_entry_overlays() -> void:
	_build_title_overlay()
	_build_tutorial_overlay()
	_build_country_select_overlay()
	_apply_entry_state()

func _build_title_overlay() -> void:
	var screen := _screen()
	title_overlay = Control.new()
	title_overlay.name = "TitleOverlay"
	title_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_overlay.z_index = 70
	title_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	board_layer.add_child(title_overlay)
	var scrim := ColorRect.new()
	scrim.name = "TitleScrim"
	scrim.color = Color(0.015, 0.012, 0.010, 0.72)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	title_overlay.add_child(scrim)
	var panel_size := Vector2(minf(screen.x - 160.0, 760.0), minf(screen.y - 140.0, 460.0))
	var panel_pos := (screen - panel_size) * 0.5
	var panel = _make_overlay_piece(title_overlay, "TitlePlaque", panel_pos, panel_size, Color(0.070, 0.048, 0.028, 0.96), BOARD_LINE, 3, "plaque")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(panel, "TitleOverlayName", "マクロノミカ", Vector2(0, 40), Vector2(panel_size.x, 56), 44, TEXT)
	_add_label_to(panel, "TitleOverlaySub", "世界経済戦略ボードゲーム", Vector2(0, 104), Vector2(panel_size.x, 28), 18, WARN.lightened(0.16))
	var memo = _make_child_piece(panel, "TitleMemo", Vector2(46, 156), Vector2(panel_size.x - 92, 116), Color(0.80, 0.69, 0.49, 0.94), BOARD_LINE, 2, "card")
	_add_label_to(memo, "TitleMemoText", "4つの国家が、世界危機を壊しすぎないよう交渉しながら、自国の厚生とレガシーを伸ばすゲームです。", Vector2(22, 18), Vector2(memo.size.x - 44, 80), 18, INK, true)
	var start = _make_entry_button(title_overlay, "TitleStart", "遊び方を見る", panel_pos + Vector2(panel_size.x * 0.5 - 124, panel_size.y - 112), Vector2(248, 62), _show_tutorial_from_title)
	_add_label_to(start, "StartHint", "初回はここから", Vector2(0, 38), Vector2(start.size.x, 18), 11, MUTED)
	var continue_token = _make_overlay_piece(title_overlay, "TitleContinue", panel_pos + Vector2(panel_size.x * 0.5 - 206, panel_size.y - 42), Vector2(160, 34), Color(0.024, 0.022, 0.020, 0.72), BOARD_LINE.darkened(0.42), 1, "card")
	continue_token.modulate = Color(1, 1, 1, 0.58)
	_add_label_to(continue_token, "ContinueText", "続きから（準備中）", Vector2.ZERO, continue_token.size, 13, MUTED)
	var settings_token = _make_overlay_piece(title_overlay, "TitleSettings", panel_pos + Vector2(panel_size.x * 0.5 + 46, panel_size.y - 42), Vector2(160, 34), Color(0.024, 0.022, 0.020, 0.72), BOARD_LINE.darkened(0.42), 1, "card")
	settings_token.modulate = Color(1, 1, 1, 0.58)
	_add_label_to(settings_token, "SettingsText", "設定（準備中）", Vector2.ZERO, settings_token.size, 13, MUTED)

func _build_tutorial_overlay() -> void:
	var screen := _screen()
	tutorial_overlay = Control.new()
	tutorial_overlay.name = "TutorialOverlay"
	tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_overlay.z_index = 72
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	board_layer.add_child(tutorial_overlay)
	var scrim := ColorRect.new()
	scrim.name = "TutorialScrim"
	scrim.color = Color(0.012, 0.010, 0.008, 0.78)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay.add_child(scrim)
	var panel_size := Vector2(minf(screen.x - 120.0, 1180.0), minf(screen.y - 100.0, 720.0))
	var panel_pos := (screen - panel_size) * 0.5
	var panel = _make_overlay_piece(tutorial_overlay, "TutorialPlaque", panel_pos, panel_size, Color(0.052, 0.038, 0.024, 0.985), BOARD_LINE, 3, "plaque")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(panel, "TutorialTitle", "まず何をするゲームか", Vector2(0, 24), Vector2(panel_size.x, 42), 34, TEXT)
	var lead := _add_label_to(panel, "TutorialLead", "毎ターン、世界危機と自国の状態を読み、政策議題から1枚選び、ワーカーで通して、結果を段階ごとに確認します。", Vector2(80, 74), Vector2(panel_size.x - 160, 48), 18, MUTED, true)
	lead.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var cards_origin := Vector2(44, 146)
	var gap := 16.0
	var card_w := (panel_size.x - 88.0 - gap * 2.0) / 3.0
	var card_h := 154.0
	_add_tutorial_card(panel, "TutorialCardWorld", cards_origin, Vector2(card_w, card_h), "1", "世界危機を見る", "需要・金利・保護主義・恐慌を確認。\n恐慌10なら全員敗北。", "world_demand_globe", BLUE)
	_add_tutorial_card(panel, "TutorialCardTalk", cards_origin + Vector2(card_w + gap, 0), Vector2(card_w, card_h), "2", "交渉で議題を作る", "協調刺激・流動性・関税凍結・債務再編を宣言。\n宣言は政策議題に影響。", "diplomat_seal", WARN)
	_add_tutorial_card(panel, "TutorialCardAgenda", cards_origin + Vector2((card_w + gap) * 2.0, 0), Vector2(card_w, card_h), "3", "政策議題から選ぶ", "全政策一覧ではない。\n今ターン会議に上がった候補と、弱い基本政策から1枚選ぶ。", "reform_wrench", COUNTRY_ACCENTS[0])
	var row2_y := cards_origin.y + card_h + gap
	_add_tutorial_card(panel, "TutorialCardWorker", Vector2(cards_origin.x, row2_y), Vector2(card_w, card_h), "4", "ワーカーで通す", "官僚・中銀・外交官・監査を置く。\n不足は骨抜きや延期を生む。", "bureaucrat_seal", COUNTRY_ACCENTS[1])
	_add_tutorial_card(panel, "TutorialCardResolve", Vector2(cards_origin.x + card_w + gap, row2_y), Vector2(card_w, card_h), "5", "解決を段階で読む", "圧力→コスト→国内→世界→デッキ→マクロ合成。\n「次段階」で止めて読む。", "depression_shadow", BAD)
	_add_tutorial_card(panel, "TutorialCardScore", Vector2(cards_origin.x + (card_w + gap) * 2.0, row2_y), Vector2(card_w, card_h), "勝", "勝ち方", "毎ターン厚生点を積み、レガシーと国際影響力を足す。\n世界危機を抑えながら自国の形を作る。", "international_influence_globe", GOOD)
	var footer = _make_child_piece(panel, "TutorialFooter", Vector2(44, panel_size.y - 138), Vector2(panel_size.x - 88, 68), Color(0.82, 0.72, 0.52, 0.96), BOARD_LINE, 2, "card")
	var footer_text := _add_label_to(footer, "TutorialFooterText", "操作に迷ったら、画面上部の「? 遊び方」でこの画面を開けます。", Vector2(22, 12), Vector2(footer.size.x - 44, 44), 17, INK, true)
	footer_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var primary = _make_entry_button(tutorial_overlay, "TutorialPrimary", "国家選択へ", panel_pos + Vector2(panel_size.x - 228, panel_size.y - 56), Vector2(184, 40), _tutorial_primary_action)
	primary.set_skin(Color(0.15, 0.105, 0.055, 0.98), WARN.lightened(0.12), 2, "card")
	var secondary = _make_entry_button(tutorial_overlay, "TutorialBack", "戻る", panel_pos + Vector2(44, panel_size.y - 56), Vector2(118, 40), _tutorial_back_action)
	secondary.set_skin(Color(0.044, 0.034, 0.026, 0.96), BOARD_LINE.darkened(0.08), 2, "card")

func _add_tutorial_card(parent: Control, node_name: String, position: Vector2, card_size: Vector2, number: String, title: String, body: String, icon_name: String, accent: Color) -> void:
	var card = _make_child_piece(parent, node_name, position, card_size, Color(0.075, 0.055, 0.034, 0.96), accent, 2, "card")
	card.add_child(_make_icon(icon_name, Vector2(16, 18), Vector2(50, 50), Color.WHITE, "TutorialIcon", true))
	var badge = _make_child_piece(card, "TutorialBadge", Vector2(card_size.x - 58, 16), Vector2(38, 38), Color(0.024, 0.022, 0.018, 0.78), accent, 1, "circle")
	_add_label_to(badge, "TutorialBadgeText", number, Vector2.ZERO, badge.size, 18, accent.lightened(0.22), false)
	var title_label := _add_label_to(card, "TutorialCardTitle", title, Vector2(78, 18), Vector2(card_size.x - 146, 28), 20, TEXT, false)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var body_label := _add_label_to(card, "TutorialCardBody", body, Vector2(18, 76), Vector2(card_size.x - 36, card_size.y - 88), 15, MUTED, true)
	body_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _build_country_select_overlay() -> void:
	var screen := _screen()
	country_select_overlay = Control.new()
	country_select_overlay.name = "CountrySelectOverlay"
	country_select_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	country_select_overlay.z_index = 71
	country_select_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	board_layer.add_child(country_select_overlay)
	var scrim := ColorRect.new()
	scrim.name = "CountrySelectScrim"
	scrim.color = Color(0.015, 0.012, 0.010, 0.72)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	country_select_overlay.add_child(scrim)
	var panel_size := Vector2(minf(screen.x - 120.0, 1040.0), minf(screen.y - 120.0, 560.0))
	var panel_pos := (screen - panel_size) * 0.5
	var panel = _make_overlay_piece(country_select_overlay, "CountrySelectPlaque", panel_pos, panel_size, Color(0.060, 0.044, 0.028, 0.96), BOARD_LINE, 3, "plaque")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(panel, "CountrySelectTitle", "国家選択", Vector2(0, 26), Vector2(panel_size.x, 40), 32, TEXT)
	_add_label_to(panel, "CountrySelectSub", "最初に操作する視点国家を選びます。全国家を順に操作するホットシート進行です。", Vector2(0, 68), Vector2(panel_size.x, 26), 15, MUTED)
	var card_gap := 16.0
	var card_w := (panel_size.x - 72.0 - card_gap) / 2.0
	var card_h := (panel_size.y - 152.0 - card_gap) / 2.0
	for i in range(game.countries.size()):
		var country = game.countries[i]
		var column := i % 2
		var row := i / 2
		var card_pos := panel_pos + Vector2(36.0 + (card_w + card_gap) * column, 110.0 + (card_h + card_gap) * row)
		var card = _make_entry_button(country_select_overlay, "CountryChoice_%d" % i, "", card_pos, Vector2(card_w, card_h), func(country_index := i) -> void:
			_select_start_country(country_index)
		)
		card.set_skin(Color(0.086, 0.064, 0.040, 0.96), COUNTRY_ACCENTS[i], 2, "card")
		card.add_child(_make_disc_label("ChoiceMedal_%d" % i, UiCatalogScript.country_emblem(i), Vector2(20, 20), 54, COUNTRY_ACCENTS[i]))
		var title := _add_label_to(card, "ChoiceTitle", country.display_name, Vector2(86, 18), Vector2(card_w - 112, 34), 18, TEXT, true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var goal := String(country.legacy_goal)
		if goal.is_empty():
			goal = "レガシー目標なし"
		var pressure := String(country.domestic_pressure.get("display_name", "国内圧力なし"))
		var tracks := "GDP %d  物価 %d\n失業 %d  債務 %d" % [
			int(country.tracks.get("gdp_gap", 0)),
			int(country.tracks.get("inflation", 0)),
			int(country.tracks.get("unemployment", 0)),
			int(country.tracks.get("debt", 0))
		]
		var body := _add_label_to(card, "ChoiceBody", "目標: %s\n初期圧力: %s\n%s" % [goal.substr(0, 42), pressure.substr(0, 18), tracks], Vector2(24, 72), Vector2(card_w - 48, card_h - 108), 14, TEXT, true)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_add_label_to(card, "ChoiceStart", "開始", Vector2(card_w - 92, card_h - 36), Vector2(70, 24), 15, COUNTRY_ACCENTS[i].lightened(0.25))

func _apply_entry_state() -> void:
	if title_overlay != null:
		title_overlay.visible = entry_state == "title"
	if tutorial_overlay != null:
		tutorial_overlay.visible = entry_state == "tutorial"
	if country_select_overlay != null:
		country_select_overlay.visible = entry_state == "country_select"
	if tutorial_overlay != null:
		var primary_text := "国家選択へ" if tutorial_return_state == "country_select" else "盤面へ戻る"
		var back_text := "タイトルへ" if tutorial_return_state == "country_select" else "閉じる"
		_set_label_in(tutorial_overlay, "TutorialPrimaryText", primary_text)
		_set_label_in(tutorial_overlay, "TutorialBackText", back_text)

func _show_title_overlay() -> void:
	entry_state = "title"
	_apply_entry_state()

func _show_tutorial_from_title() -> void:
	_show_tutorial_overlay("country_select")

func _show_tutorial_overlay(return_state := "country_select") -> void:
	tutorial_return_state = return_state
	entry_state = "tutorial"
	_apply_entry_state()

func _show_country_select() -> void:
	entry_state = "country_select"
	_apply_entry_state()

func _hide_entry_overlays() -> void:
	entry_state = "hidden"
	_apply_entry_state()

func _tutorial_primary_action() -> void:
	if tutorial_return_state == "country_select":
		_show_country_select()
	else:
		_hide_entry_overlays()

func _tutorial_back_action() -> void:
	if tutorial_return_state == "country_select":
		_show_title_overlay()
	else:
		_hide_entry_overlays()

func _show_turn_news_overlay() -> void:
	if turn_news_panel == null:
		return
	turn_news_active = true
	turn_news_panel.visible = true
	if turn_news_label != null:
		turn_news_label.text = _turn_news_text()
	if board_layer != null:
		_refresh_title()
	_bump(turn_news_panel)

func _hide_turn_news_overlay() -> void:
	turn_news_active = false
	if turn_news_panel != null:
		turn_news_panel.visible = false
	if board_layer != null:
		_refresh_title()

func _select_start_country(country_index: int) -> void:
	player_country_index = country_index
	selected_country_index = country_index
	_hide_entry_overlays()
	_refresh_board(true)
	if country_index >= 0 and country_index < country_seats.size():
		_bump(country_seats[country_index])

func _build_policy_menu_slots() -> void:
	var card_size: Vector2 = board_layout["hand_card_size"]
	for i in range(_policy_menu_page_size()):
		var slot = _make_piece("PolicyMenuSlot_%d" % i, _policy_menu_position(i), card_size, Color(0.018, 0.015, 0.012, 0.42), Color(0.32, 0.24, 0.14, 0.42), 1, "card")
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_domestic_state_panel() -> void:
	domestic_state_cards.clear()
	domestic_state_labels.clear()
	var panel_pos: Vector2 = board_layout["domestic_state_panel_pos"]
	var panel_size: Vector2 = board_layout["domestic_state_panel_size"]
	var panel = _make_piece("DomesticStatePanel", panel_pos, panel_size, Color(0.045, 0.036, 0.028, 0.94), BAD.darkened(0.10), 2, "plaque")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _add_label_to(panel, "DomesticStateTitle", "公開国内情勢（状態デッキから2枚）", Vector2(0, 8), Vector2(panel_size.x, 22), 16, WARN.lightened(0.16), false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	domestic_state_deck_label = _add_label_to(panel, "DomesticStateDeckZones", "", Vector2(22, 33), Vector2(panel_size.x - 44, 20), 13, MUTED, false)
	domestic_state_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _add_label_to(panel, "DomesticStateHint", "政策に山札/手札はない。ここだけが状態デッキの公開ゾーン。", Vector2(18, panel_size.y - 26), Vector2(panel_size.x - 36, 20), 13, MUTED, false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var card_size: Vector2 = board_layout["domestic_state_card_size"]
	var first_x := 34.0
	var gap := 18.0
	for i in range(2):
		var card = _make_child_piece(panel, "DomesticStateCard_%d" % i, Vector2(first_x + (card_size.x + gap) * i, 58), card_size, Color(0.17, 0.13, 0.10, 0.97), BAD.darkened(0.04), 2, "card")
		var icon = _make_icon("reform_wrench", Vector2(10, 14), Vector2(48, 48), Color.WHITE, "DomesticStateIcon")
		card.add_child(icon)
		var label := _add_label_to(card, "DomesticStateLabel", "", Vector2(66, 10), Vector2(card_size.x - 76, card_size.y - 20), 14, TEXT, true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		domestic_state_cards.append(card)
		domestic_state_labels.append(label)

func _build_policy_preview_panel() -> void:
	var panel_pos: Vector2 = board_layout["policy_preview_pos"]
	var panel_size: Vector2 = board_layout["policy_preview_size"]
	policy_preview_panel = _make_piece("PolicyPreviewPanel", panel_pos, panel_size, Color(0.030, 0.024, 0.018, 0.985), WARN.darkened(0.08), 3, "plaque")
	policy_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	policy_preview_panel.z_index = 24
	_add_label_to(policy_preview_panel, "PolicyPreviewTitle", "フォーカス中の政策: 説明と判定", Vector2(22, 10), Vector2(360, 28), 21, WARN.lightened(0.18), false).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	policy_focus_card = _make_child_piece(policy_preview_panel, "PolicyFocusCard", Vector2(22, 44), Vector2(288, 126), CARD_FACE, BOARD_LINE, 2, "card")
	policy_focus_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	policy_focus_icon = _make_icon("reform_wrench", Vector2(16, 17), Vector2(76, 76), Color.WHITE, "PolicyFocusIcon")
	policy_focus_card.add_child(policy_focus_icon)
	policy_focus_title = _add_label_to(policy_focus_card, "PolicyFocusTitle", "", Vector2(104, 10), Vector2(168, 52), 23, INK, true)
	policy_focus_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	policy_focus_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	policy_focus_source = _add_label_to(policy_focus_card, "PolicyFocusSource", "", Vector2(106, 66), Vector2(166, 20), 14, INK.darkened(0.05), false)
	policy_focus_source.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	policy_focus_cost = _add_label_to(policy_focus_card, "PolicyFocusCost", "", Vector2(16, 96), Vector2(256, 22), 15, INK.darkened(0.05), false)
	policy_focus_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	policy_preview_label = _add_label_to(policy_preview_panel, "PolicyPreviewLabel", "", Vector2(330, 42), Vector2(panel_size.x - 356, panel_size.y - 58), 20, TEXT.lightened(0.08), true)
	policy_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	policy_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	policy_preview_label.add_theme_constant_override("line_spacing", 5)

func _build_status_panels() -> void:
	var score_pos: Vector2 = board_layout["score_pos"]
	var score_size: Vector2 = board_layout["score_size"]
	var score = _make_piece("ScorePanel", score_pos, score_size, Color(0.060, 0.044, 0.026, 0.94), BOARD_LINE, 1, "plaque")
	score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(score, "ScoreTitle", "威信", Vector2(10, 3), Vector2(46, 20), 15, WARN.lightened(0.18))
	score_panel = _add_label_to(score, "ScoreComponent", "", Vector2(62, 3), Vector2(score_size.x - 72, 20), 15, TEXT)
	score_panel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var log_pos: Vector2 = board_layout["log_pos"]
	var log_size: Vector2 = board_layout["log_size"]
	var log = _make_piece("LogPanel", log_pos, log_size, Color(0.070, 0.050, 0.030, 0.96), BOARD_LINE, 2, "card")
	log.tooltip_text = "ログ/新聞ドロワーを開きます。"
	log.pressed = _on_log_panel_pressed
	_add_label_to(log, "LogTitle", "ログ", Vector2(0, 6), Vector2(log_size.x, 22), 17, WARN.lightened(0.18), false)
	log_panel = Label.new()
	log_panel.name = "LogComponent"
	log_panel.position = Vector2(0, 28)
	log_panel.size = Vector2(log_size.x, 16)
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_panel.add_theme_color_override("default_color", TEXT)
	log_panel.add_theme_font_size_override("font_size", 13)
	log_panel.autowrap_mode = TextServer.AUTOWRAP_OFF
	log_panel.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	log_panel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	log_panel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log.add_child(log_panel)

func _build_country_detail_panel() -> void:
	var detail_pos: Vector2 = board_layout["country_detail_pos"]
	var detail_size: Vector2 = board_layout["country_detail_size"]
	var panel = _make_piece("CountryDetailPanel", detail_pos, detail_size, Color(0.060, 0.044, 0.028, 0.95), BOARD_LINE, 1, "card")
	panel.tooltip_text = "クリックで対応任務の対象を切替"
	panel.pressed = _on_country_detail_pressed
	_add_label_to(panel, "CountryDetailTitle", "国勢メモ", Vector2(0, 9), Vector2(detail_size.x, 24), 17, WARN.lightened(0.18))
	country_detail_label = _add_label_to(panel, "CountryDetailLabel", "", Vector2(16, 38), Vector2(detail_size.x - 32, detail_size.y - 44), 15, TEXT, true)
	country_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	country_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _build_worker_tokens() -> void:
	worker_nodes.clear()
	var start: Vector2 = board_layout["worker_origin"]
	var step: Vector2 = board_layout["worker_step"]
	var token_size: Vector2 = board_layout["worker_size"]
	var columns := int(board_layout.get("worker_columns", 5))
	for i in range(WORKERS.size()):
		var worker: String = WORKERS[i]
		var col := i % columns
		var row := floori(float(i) / float(columns))
		var token = _make_piece("Worker_%s" % worker, start + Vector2(step.x * col, step.y * row), token_size, Color(0.045, 0.034, 0.024, 0.94), BOARD_LINE, 1, "card")
		token.visible = false
		token.tooltip_text = "%s: %s" % [UiCatalogScript.worker_name(worker), UiCatalogScript.worker_tip(worker)]
		token.pressed = func(worker_id := worker) -> void:
			if game.can_assign_worker():
				_on_worker_assigned(selected_country_index, worker_id, token.position)
		token.add_child(_make_icon(UiCatalogScript.worker_token(worker), Vector2(20, 28), Vector2(86, 86), Color.WHITE, "WorkerIcon"))
		var name_label := _add_label_to(token, "WorkerName", UiCatalogScript.worker_name(worker), Vector2(122, 24), Vector2(token_size.x - 140, 34), 21, TEXT, false)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var role_label := _add_label_to(token, "WorkerRole", _worker_role_label(worker), Vector2(122, 66), Vector2(token_size.x - 140, 24), 17, WARN.lightened(0.18), true)
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var hint_label := _add_label_to(token, "WorkerHint", _worker_hint_label(worker), Vector2(20, 112), Vector2(token_size.x - 40, 34), 13, MUTED, false)
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		worker_nodes[worker] = token

func _rebuild_policy_menu(animate: bool, origin := Vector2.INF) -> void:
	for node in policy_menu_nodes:
		node.queue_free()
	policy_menu_nodes.clear()
	var phase: String = game.current_phase()
	var show_menu: bool = phase == "policy_planning" and not _is_selecting_policy_target()
	var show_tray: bool = show_menu or phase == "worker_assignment"
	var country = game.countries[selected_country_index]
	var options: Array = game.policy_options(selected_country_index)
	policy_menu_page = _clamped_policy_menu_page(options)
	var page_size := _policy_menu_page_size()
	var page_count := _policy_menu_page_count(options)
	var page_start := policy_menu_page * page_size
	var page_end = mini(options.size(), page_start + page_size)
	var menu_panel = board_layer.get_node_or_null("PolicyMenuPanel")
	if menu_panel != null:
		menu_panel.visible = show_tray
		var title: Label = menu_panel.get_node_or_null("PolicyMenuTitle")
		if title != null:
			var country_label := "%s国: %s" % [UiCatalogScript.country_emblem(selected_country_index), String(country.display_name).substr(3)]
			title.text = "%s  今ターンの政策議題から1枚選ぶ" % country_label if show_menu else "%s  担当ワーカーを選んで印確定" % country_label
			title.add_theme_font_size_override("font_size", 20 if show_menu else 21)
			title.add_theme_color_override("font_color", WARN.lightened(0.18) if show_menu else COUNTRY_ACCENTS[selected_country_index].lightened(0.30))
		var legend: Label = menu_panel.get_node_or_null("PolicyMenuLegend")
		if legend != null:
			legend.text = "議題 %d-%d/%d / カーソルで詳細 / クリックで伏せる" % [page_start + 1, page_end, options.size()] if show_menu else "官僚/中銀/外交/監査/ロビイスト = 政策の通し方"
			legend.add_theme_font_size_override("font_size", 14 if show_menu else 15)
	_refresh_policy_page_controls(show_menu, page_count)
	for i in range(page_size):
		var slot = board_layer.get_node_or_null("PolicyMenuSlot_%d" % i)
		if slot != null:
			slot.visible = show_menu and (page_start + i) < options.size()
	if not show_menu:
		return
	var source := origin
	if source == Vector2.INF and selected_country_index < country_seats.size():
		source = country_seats[selected_country_index].position + Vector2(60, 46)
	for policy_index in range(page_start, page_end):
		var display_index := policy_index - page_start
		var card: Dictionary = options[policy_index]
		var card_node = _make_policy_card(card, policy_index, -1, true)
		var final_pos := _policy_menu_position(display_index)
		card_node.position = final_pos
		card_node.rotation_degrees = 0.0
		card_node.z_index = 12
		board_layer.add_child(card_node)
		policy_menu_nodes.append(card_node)
		if animate:
			_animate_policy_menu_deal(card_node, source, final_pos, 0.025 * display_index)

func _policy_menu_page_size() -> int:
	return maxi(1, int(board_layout.get("hand_columns", 4)) * int(board_layout.get("hand_rows", 4)))

func _policy_menu_page_count(options: Array) -> int:
	if options.is_empty():
		return 1
	return ceili(float(options.size()) / float(_policy_menu_page_size()))

func _clamped_policy_menu_page(options: Array) -> int:
	return clampi(policy_menu_page, 0, _policy_menu_page_count(options) - 1)

func _refresh_policy_page_controls(show_menu: bool, page_count: int) -> void:
	var show_controls := show_menu and page_count > 1
	var prev = board_layer.get_node_or_null("PolicyPagePrev")
	var next = board_layer.get_node_or_null("PolicyPageNext")
	if prev != null:
		prev.visible = show_controls
		prev.modulate.a = 0.42 if policy_menu_page <= 0 else 1.0
		prev.tooltip_text = "前の政策候補ページへ"
	if next != null:
		next.visible = show_controls
		next.modulate.a = 0.42 if policy_menu_page >= page_count - 1 else 1.0
		next.tooltip_text = "次の政策候補ページへ"

func _policy_menu_position(index: int) -> Vector2:
	var origin: Vector2 = board_layout["hand_origin"]
	var step: Vector2 = board_layout["hand_step"]
	var columns := int(board_layout.get("hand_columns", 10))
	var col := index % columns
	var row := floori(float(index) / float(columns))
	return origin + Vector2(step.x * col, step.y * row)

func _make_policy_card(card: Dictionary, policy_menu_index: int, display_country_index := -1, include_coin := true):
	var country_index := selected_country_index if display_country_index < 0 else display_country_index
	var country = game.countries[country_index]
	var selected: bool = not country.selected_policy.is_empty() and country.selected_policy.get("id", "") == card.get("id", "")
	var available: bool = country.is_policy_available(card)
	var face: Color = CARD_FACE if card.get("type", "") == "policy" else Color(0.16, 0.15, 0.12, 1.0)
	if not available:
		face = face.darkened(0.24)
	var border: Color = COUNTRY_ACCENTS[country_index] if selected else BOARD_LINE
	var card_size: Vector2 = board_layout.get("hand_card_size", Vector2(82, 108))
	var card_node = BoardPieceScript.new()
	card_node.name = "PolicyMenuCard_%d" % policy_menu_index
	card_node.size = card_size
	card_node.set_skin(face, border, 3 if selected else 2, "card")
	card_node.tooltip_text = _plain_card_detail(country, card)
	card_node.pressed = func() -> void:
		if card.get("type", "") == "policy" and game.can_select_policy() and available:
			_on_policy_selected(selected_country_index, policy_menu_index, card_node.position)
	card_node.mouse_entered.connect(func() -> void:
		if game.current_phase() == "policy_planning":
			_set_policy_preview(policy_menu_index)
	)
	if include_coin:
		var icon_size := minf(100.0, card_size.y * 0.58)
		card_node.add_child(_make_icon(UiCatalogScript.card_token(card), Vector2((card_size.x - icon_size) * 0.5, 12), Vector2(icon_size, icon_size), Color.WHITE, "CardCoin"))
	var label_y := minf(card_size.y - 58.0, 108.0) if include_coin else 8.0
	var label := _add_label_to(card_node, "CardName", _ellipsize(UiCatalogScript.short_card_name(card), 13), Vector2(14, label_y), Vector2(card_size.x - 28, 30), 19, INK if card.get("type", "") == "policy" else TEXT, false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var cost_text := _policy_menu_footer(country, card)
	var cost_label := _add_label_to(card_node, "CardCost", _ellipsize(cost_text, 20), Vector2(14, card_size.y - 31), Vector2(card_size.x - 28, 22), 15, INK.darkened(0.06) if available else INK.lightened(0.25), false)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return card_node

func _policy_menu_footer(country, card: Dictionary) -> String:
	var pressure := "圧OK" if PolicyRecommenderScript.pressure_matches(country, card) else "圧外"
	if not country.is_policy_available(card):
		return "%s %s 冷却%dT" % [_policy_source_short(card), pressure, int(country.policy_cooldowns.get(String(card.get("id", "")), 0))]
	return "%s %s %s" % [_policy_source_short(card), pressure, _policy_menu_cost_summary(country, card)]

func _policy_menu_cost_summary(country, card: Dictionary) -> String:
	if not country.is_policy_available(card):
		return "冷却:%dT" % int(country.policy_cooldowns.get(String(card.get("id", "")), 0))
	var costs: Dictionary = card.get("costs", {})
	var parts := []
	for key in COST_KEYS:
		var value := int(costs.get(key, 0))
		if value <= 0:
			continue
		parts.append("%s%d" % [_cost_short_name(key), value])
		if parts.size() >= 3:
			break
	return "コストなし" if parts.is_empty() else " ".join(parts)

func _policy_source_short(card: Dictionary) -> String:
	var source := String(card.get("_menu_source", ""))
	if source.begins_with("module:"):
		return "構"
	if source == "common":
		return "共"
	if source == "cooperation":
		return "協"
	if source == "unique":
		return "固"
	if source.begins_with("crisis:"):
		return "危"
	return "?"

func _policy_source_color(card: Dictionary) -> Color:
	var source := String(card.get("_menu_source", ""))
	if source.begins_with("module:"):
		return BLUE.darkened(0.16)
	if source == "common":
		return Color(0.38, 0.30, 0.18)
	if source == "cooperation":
		return GOOD.darkened(0.16)
	if source == "unique":
		return WARN.darkened(0.20)
	if source.begins_with("crisis:"):
		return BAD.darkened(0.12)
	return Color(0.18, 0.16, 0.13)

func _policy_source_label(card: Dictionary) -> String:
	var source := String(card.get("_menu_source", ""))
	if source.begins_with("module:"):
		return "国家構成:%s" % source.substr("module:".length())
	if source == "common":
		return "共通政策"
	if source == "cooperation":
		return "国際協調政策"
	if source == "unique":
		return "国固有政策"
	if source.begins_with("crisis:"):
		return "危機対応:%s" % source.substr("crisis:".length())
	return "出所未設定"

func _policy_source_preview(card: Dictionary) -> String:
	var source := String(card.get("_menu_source", ""))
	if source.begins_with("module:"):
		return "構:%s" % source.substr("module:".length()).substr(0, 8)
	if source == "common":
		return "共通"
	if source == "cooperation":
		return "協調"
	if source == "unique":
		return "固有"
	if source.begins_with("crisis:"):
		return "危機"
	return "出所?"

func _policy_preview_text(country, policy: Dictionary, index: int) -> String:
	var preview: Dictionary = game._preview_policy_cost(country, policy)
	var shortages: Dictionary = preview.get("shortages", {}) if preview is Dictionary else {}
	var shortage_parts := []
	for key in COST_KEYS:
		var value := int(shortages.get(key, 0))
		if value <= 0:
			continue
		shortage_parts.append("%s%d" % [_cost_short_name(key), value])
		if shortage_parts.size() >= 3:
			break
	var shortage_text := "不足なし" if shortage_parts.is_empty() else "不足 %s" % " / ".join(shortage_parts)
	var effects: Dictionary = policy.get("effects", {})
	var country_effect := _short_effect_scope(effects.get("country", {}))
	var world_effect := _short_effect_scope(effects.get("world", {}))
	if String(policy.get("target", "")) == "country":
		country_effect = _short_effect_scope(effects.get("donor", {}))
		world_effect = _short_effect_scope(effects.get("recipient", {}))
	var effect_text := "自国 %s / 世界 %s" % [
		country_effect if not country_effect.is_empty() else "-",
		world_effect if not world_effect.is_empty() else "-"
	]
	var pressure_text := "国内圧力に合う" if PolicyRecommenderScript.pressure_matches(country, policy) else "国内圧力とはズレる"
	var cost_text := _policy_menu_cost_summary(country, policy)
	var description := _ellipsize(String(policy.get("description", "")), 64)
	return "#%02d  %s  [%s]\n%s\n判定: %s / コスト %s / %s\n効果: %s" % [
		index + 1,
		String(policy.get("display_name", policy.get("id", "政策"))).substr(0, 18),
		_policy_source_preview(policy),
		description,
		pressure_text,
		cost_text,
		shortage_text,
		effect_text
	]

func _plain_card_detail(country, card: Dictionary) -> String:
	var text := CardTextFormatterScript.card_detail(country, card)
	for token in ["[b]", "[/b]", "[center]", "[/center]"]:
		text = text.replace(token, "")
	text = text.replace("[color=#9aa0a4]", "").replace("[color=#999999]", "").replace("[/color]", "")
	return text

func _refresh_board(animate: bool) -> void:
	if board_layer == null:
		return
	_refresh_title()
	_refresh_phase()
	_refresh_world()
	_refresh_planning_country_panel()
	_refresh_collapse_warning()
	_refresh_agenda()
	_refresh_country_seats()
	_refresh_policy_slot(animate)
	_refresh_workers()
	_refresh_status_panels()
	_refresh_country_detail_panel()
	_refresh_resolution_flow()
	_refresh_resolution_links()
	_refresh_final_score_overlay()
	_refresh_domestic_state_panel()
	_refresh_policy_preview_panel()
	_rebuild_policy_menu(animate)
	_refresh_context_visibility()

func _refresh_title() -> void:
	var turn := board_layer.get_node_or_null("TurnLabel")
	if turn != null:
		turn.visible = false
		turn.text = "T%d/%d" % [game.turn, game.turn_limit]
	_refresh_objective_header()
	_set_label("AdvanceTokenLabel", _advance_token_text())
	var advance = board_layer.get_node_or_null("AdvanceToken")
	if advance != null:
		advance.visible = not turn_news_active
		var advance_label: Label = advance.get_node_or_null("AdvanceTokenLabel")
		if game.current_phase() == "negotiation":
			advance.position = _snap_vec(board_layout["negotiation_pos"] + board_layout["negotiation_size"] - Vector2(226.0, 50.0))
			advance.size = Vector2(202, 38)
			advance.z_index = 18
			advance.set_skin(Color(0.12, 0.075, 0.026, 0.96), WARN.lightened(0.12), 3, "card")
			if advance_label != null:
				advance_label.position = Vector2.ZERO
				advance_label.size = advance.size
				advance_label.add_theme_font_size_override("font_size", 21)
		else:
			advance.position = _snap_vec(board_layout["advance_command_pos"])
			advance.size = Vector2(108, 108)
			advance.z_index = 0
			advance.set_skin(Color(0.09, 0.060, 0.026, 0.88), WARN.lightened(0.06), 2, "circle")
			if advance_label != null:
				advance_label.position = Vector2.ZERO
				advance_label.size = advance.size
				advance_label.add_theme_font_size_override("font_size", 28)
		advance.tooltip_text = _advance_token_tip()
	var recommend = board_layer.get_node_or_null("RecommendToken")
	if recommend != null:
		recommend.visible = game.current_phase() != "negotiation" and not turn_news_active
		recommend.tooltip_text = _recommend_token_tip()
		_set_label("RecommendTokenLabel", _recommend_token_text())
	var restart = board_layer.get_node_or_null("RestartToken")
	if restart != null:
		restart.tooltip_text = "現在のゲームを破棄してタイトルに戻ります。"
	var help = board_layer.get_node_or_null("HelpToken")
	if help != null:
		help.tooltip_text = "ゲームの目的とターンの読み方を開きます。"

func _refresh_objective_header() -> void:
	var panel = board_layer.get_node_or_null("ObjectiveHeader")
	if panel == null:
		return
	panel.visible = entry_state == "hidden"
	var accent := _objective_accent()
	panel.set_skin(Color(0.072, 0.044, 0.018, 0.97), accent, 3, "card")
	_set_label_in(panel, "ObjectiveKicker", "T%d/%d" % [game.turn, game.turn_limit])
	_set_label_in(panel, "ObjectiveText", _objective_text())
	_set_label_in(panel, "ObjectiveHint", _objective_hint())
	var kicker: Label = panel.get_node_or_null("ObjectiveKicker")
	if kicker != null:
		kicker.add_theme_color_override("font_color", accent.lightened(0.20))
	var text: Label = panel.get_node_or_null("ObjectiveText")
	if text != null:
		text.add_theme_color_override("font_color", TEXT)
	var hint: Label = panel.get_node_or_null("ObjectiveHint")
	if hint != null:
		hint.add_theme_color_override("font_color", MUTED.lightened(0.08))

func _objective_text() -> String:
	if turn_news_active:
		return "新聞/ログを確認"
	if game.is_finished:
		return "最終評議会を確認"
	var phase: String = game.current_phase()
	var country_name := _active_country_name()
	if phase == "negotiation":
		return "%s: 交渉議題を宣言" % country_name if _countries_without_agenda_count() > 0 else "交渉完了: 政策選択へ"
	if phase == "policy_planning":
		var country = game.countries[selected_country_index]
		if not country.selected_policy.is_empty() and String(country.selected_policy.get("target", "")) == "country":
			return "%s: 対象国を選ぶ" % country_name
		if country.selected_policy.is_empty():
			return "%s: 政策議題から1枚選ぶ" % country_name
		return "%s: 提出済み、次の国へ" % country_name
	if phase == "worker_assignment":
		return "%s: ワーカーを配置" % country_name if not _all_workers_confirmed() else "配置完了: 政策公開へ"
	if phase == "simultaneous_reveal":
		return "4国の政策を同時公開"
	if phase == "resolution":
		return "今見る結果: %s" % _resolution_step_name(resolution_step_index) if resolution_review_active else "ターン結果を解決"
	return game.current_phase_name()

func _objective_hint() -> String:
	if turn_news_active:
		return "閉じると盤面へ戻る"
	if game.is_finished:
		return "順位とレガシー目標を見る"
	var phase: String = game.current_phase()
	if phase == "negotiation":
		return "議題カードを押す / スキップは右下"
	if phase == "policy_planning":
		return "%d/4 提出済み" % _submitted_policy_count()
	if phase == "worker_assignment":
		var confirmed := 0
		for item in worker_assignment_confirmed:
			if bool(item):
				confirmed += 1
		return "%d/4 配置確定" % confirmed
	if phase == "simultaneous_reveal":
		return "右下の公開で解決レビューへ"
	if phase == "resolution":
		return "中央の解決レビューを読み、右下で次へ" if resolution_review_active else "一括解決中"
	return "次の処理へ"

func _objective_accent() -> Color:
	if turn_news_active:
		return WARN.lightened(0.16)
	if game.is_finished:
		return GOOD.lightened(0.10)
	var phase: String = game.current_phase()
	if phase == "resolution":
		return BAD.lightened(0.16)
	if phase == "simultaneous_reveal":
		return WARN.lightened(0.18)
	if selected_country_index >= 0 and selected_country_index < COUNTRY_ACCENTS.size():
		return COUNTRY_ACCENTS[selected_country_index].lightened(0.18)
	return WARN.lightened(0.10)

func _active_country_name() -> String:
	if selected_country_index < 0 or selected_country_index >= game.countries.size():
		return "担当国"
	return "%s国" % UiCatalogScript.country_emblem(selected_country_index)

func _refresh_phase() -> void:
	for i in range(phase_pips.size()):
		var active: bool = i == game.phase_index
		phase_pips[i].set_skin(WARN if active else Color(0.04, 0.035, 0.026, 0.55), BOARD_LINE)
		var label: Label = board_layer.get_node_or_null("PhaseLabel_%d" % i)
		if label != null:
			label.add_theme_color_override("font_color", TEXT if active else MUTED)

func _refresh_world() -> void:
	var world_visible: bool = game.current_phase() != "policy_planning"
	var world_panel: Control = board_layer.get_node_or_null("WorldPanel")
	if world_panel != null:
		world_panel.visible = world_visible
	var event: Dictionary = game.world.current_event
	_set_label("EventTitle", String(event.get("display_name", "")))
	_set_label("EventMessage", String(event.get("message", "")))
	_set_label("EventDeck", "山札 %d / 捨札 %d" % [game.world.event_deck.size(), game.world.event_discard.size()])
	var event_title_text := String(event.get("display_name", ""))
	var event_message_text := String(event.get("message", ""))
	if event_title_text.is_empty():
		event_title_text = "世界イベント待ち"
	if event_message_text.is_empty():
		event_message_text = "次の世界イベントで各国の状態デッキや政策カタログが変化します。"
	_set_label("WorldEventSummaryCaption", "現在イベント: %s" % _ellipsize(event_title_text, 28))
	_set_label("WorldEventSummaryTitle", _ellipsize(event_title_text, 24))
	_set_label("WorldEventSummaryMessage", _ellipsize(event_message_text, 72))
	_set_label("WorldPanelHint", _persistent_crisis_summary())
	for key in WORLD_TRACKS:
		var tile = board_layer.get_node_or_null("WorldTrack_%s" % key)
		if tile == null:
			continue
		tile.visible = world_visible
		var value := int(game.world.tracks.get(key, 0))
		var color := TrackPresenterScript.track_color(key, value, _track_colors())
		var highlighted: bool = key == log_highlight_key
		tile.set_skin(Color(0.045, 0.032, 0.018, 0.86) if highlighted else Color(0.020, 0.019, 0.016, 0.72), WARN if highlighted else color, 3 if highlighted else 1, "card")
		var value_label: Label = tile.get_node_or_null("TrackValue")
		if value_label != null:
			value_label.text = _world_value_label(key, value)
			value_label.add_theme_color_override("font_color", color.lightened(0.28))
		var meaning_label: Label = tile.get_node_or_null("TrackMeaning")
		if meaning_label != null:
			meaning_label.text = _world_track_meaning(key, value)
			meaning_label.add_theme_color_override("font_color", MUTED if not highlighted else WARN.lightened(0.24))
		var rail := tile.get_node("TrackRail")
		_clear_children(rail)
		var filled := TrackPresenterScript.marker_count(key, value)
		for i in range(7):
			var pip_size := 13
			var gap: float = (rail.size.x - float(pip_size)) / 6.0
			var x: float = gap * float(i)
			rail.add_child(_make_pip(Vector2(x, 3), pip_size, color if i < filled else TOKEN_EMPTY))
		var icon: TextureRect = tile.get_node_or_null("TrackIcon")
		if icon != null:
			icon.modulate = color.lightened(0.20)
	var event_summary: Control = board_layer.get_node_or_null("WorldEventSummary")
	if event_summary != null:
		event_summary.visible = world_visible

func _refresh_planning_country_panel() -> void:
	if planning_country_panel == null:
		return
	var phase: String = game.current_phase()
	planning_country_panel.visible = false
	if phase == "policy_planning" or phase == "worker_assignment":
		return
	var country = game.countries[selected_country_index]
	var accent: Color = COUNTRY_ACCENTS[selected_country_index]
	planning_country_panel.set_skin(Color(0.050, 0.036, 0.024, 0.93), accent.lightened(0.10), 3, "plaque")
	var emblem: Label = planning_country_panel.get_node_or_null("PlanningCountryEmblem")
	if emblem != null:
		emblem.text = "%s国" % UiCatalogScript.country_emblem(selected_country_index)
		emblem.add_theme_color_override("font_color", accent.lightened(0.25))
	if planning_country_title != null:
		planning_country_title.text = String(country.display_name)
	if planning_country_subtitle != null:
		planning_country_subtitle.text = _ellipsize(String(country.summary), 24)
	if planning_country_pressure != null:
		planning_country_pressure.text = _pressure_summary(country).replace("\n", "  ")
	if planning_country_stats != null:
		var t: Dictionary = country.tracks
		planning_country_stats.text = "GDP %d / 物価 %d / 失業 %d / 金融 %d / %s" % [
			int(t.get("gdp_gap", 0)),
			int(t.get("inflation", 0)),
			int(t.get("unemployment", 0)),
			int(t.get("financial_stress", 0)),
			_welfare_check_summary(country)
		]
	if planning_country_progress != null:
		if phase == "worker_assignment":
			planning_country_progress.text = "印\n%d/4" % (_confirmed_worker_count() + 1)
		else:
			planning_country_progress.text = "担当\n%d/4" % (_submitted_policy_count() + 1)

func _refresh_collapse_warning() -> void:
	if collapse_warning == null:
		return
	var depression := int(game.world.tracks.get("depression", 0))
	var should_warn := depression >= 8 and not bool(game.global_collapse)
	collapse_warning.visible = should_warn
	if should_warn:
		var label: Label = collapse_warning.get_node_or_null("CollapseWarningText")
		if label != null:
			label.text = "世界恐慌警戒: 恐慌 %d/10  協調・需要・金融安定を優先" % depression

func _refresh_agenda() -> void:
	var panel: Control = board_layer.get_node_or_null("NegotiationPanel")
	if panel != null:
		panel.visible = game.current_phase() == "negotiation"
	for item in AGENDA:
		var tag := String(item["tag"])
		var tile := board_layer.get_node("Agenda_%s" % tag)
		tile.visible = game.current_phase() == "negotiation"
		var pips := tile.get_node("AgendaPips")
		_clear_children(pips)
		var count := 0
		for country in game.countries:
			if String(country.declared_agenda) == tag:
				count += 1
		if game.revealed_policies or game.current_phase() == "resolution" or game.is_finished:
			count = 0
			for country in game.countries:
				if not country.selected_policy.is_empty() and PolicyRecommenderScript.has_tag(country.selected_policy, tag):
					count += 1
		var declared_here: bool = String(game.countries[selected_country_index].declared_agenda) == tag
		var action_label: Label = tile.get_node_or_null("AgendaAction")
		if action_label != null:
			action_label.text = "%s国 宣言済" % UiCatalogScript.country_emblem(selected_country_index) if declared_here else "%s国が宣言" % UiCatalogScript.country_emblem(selected_country_index)
			action_label.add_theme_color_override("font_color", TEXT if declared_here else WARN.lightened(0.18))
		tile.set_skin(Color(0.20, 0.14, 0.064, 0.98) if declared_here else Color(0.13, 0.092, 0.048, 0.94), COUNTRY_ACCENTS[selected_country_index] if declared_here else BOARD_LINE, 4 if declared_here else 2, "card")
		for i in range(4):
			pips.add_child(_make_pip(Vector2(i * 18, 0), 10, WARN if i < count else TOKEN_EMPTY))
	for i in range(negotiation_country_cards.size()):
		var card: Control = negotiation_country_cards[i]
		var label: Label = negotiation_country_labels[i]
		var active := i == selected_country_index
		var country = game.countries[i]
		var declared := String(country.declared_agenda)
		var declaration := _agenda_display_name(declared) if not declared.is_empty() else "未宣言"
		card.visible = game.current_phase() == "negotiation"
		card.set_skin(Color(0.070, 0.052, 0.032, 0.96) if active else Color(0.032, 0.030, 0.024, 0.90), COUNTRY_ACCENTS[i] if active else BOARD_LINE.darkened(0.18), 3 if active else 1, "card")
		label.text = "%s国  %s" % [UiCatalogScript.country_emblem(i), declaration]
		label.add_theme_color_override("font_color", COUNTRY_ACCENTS[i].lightened(0.28) if active else TEXT)
	if negotiation_focus_label != null:
		var active_country = game.countries[selected_country_index]
		var active_declared := String(active_country.declared_agenda)
		negotiation_focus_label.text = "%s国の交渉議題" % UiCatalogScript.country_emblem(selected_country_index) if active_declared.is_empty() else "%s国: %s" % [UiCatalogScript.country_emblem(selected_country_index), _agenda_display_name(active_declared)]
	if negotiation_status_label != null:
		var missing := _countries_without_agenda_count()
		negotiation_status_label.text = "未宣言 %d国" % missing
	if negotiation_guide_label != null:
		var missing := _countries_without_agenda_count()
		if missing > 0:
			negotiation_guide_label.text = "%s国: 議題カードを1枚押して宣言。宣言しない国は右下「政策選択へ」でスキップできます。" % UiCatalogScript.country_emblem(selected_country_index)
		else:
			negotiation_guide_label.text = "全員の宣言が揃いました。右下「政策選択へ」で、各国の政策カード選択へ進みます。"

func _refresh_country_seats() -> void:
	var phase: String = game.current_phase()
	var target_mode := false
	if phase == "policy_planning" and selected_country_index >= 0 and selected_country_index < game.countries.size():
		var selected_country = game.countries[selected_country_index]
		target_mode = not selected_country.selected_policy.is_empty() and String(selected_country.selected_policy.get("target", "")) == "country"
	for i in range(country_seats.size()):
		var country = game.countries[i]
		var accent: Color = COUNTRY_ACCENTS[i]
		var active: bool = i == selected_country_index
		var targeted_by_selected := _selected_policy_target_index() == i
		var seat = country_seats[i]
		seat.visible = (phase != "policy_planning" and phase != "worker_assignment" and phase != "negotiation") or target_mode
		var border_color: Color = WARN if targeted_by_selected and phase == "policy_planning" else accent
		var fill := Color(0.090, 0.064, 0.034, 0.94) if active else Color(0.060, 0.046, 0.030, 0.86)
		var border_width := 3 if active or (targeted_by_selected and phase == "policy_planning") else 2
		if phase == "worker_assignment":
			fill = Color(0.086, 0.060, 0.034, 0.94) if active else Color(0.044, 0.036, 0.028, 0.74)
			border_color = accent.lightened(0.18) if active else BOARD_LINE.darkened(0.48)
			border_width = 3 if active else 1
		seat.set_skin(fill, border_color, border_width, "card")
		country_pressure_labels[i].text = _pressure_summary(country)
		country_state_labels[i].text = _state_hand_card_text(country)
		country_policy_labels[i].text = _policy_slot_summary(country)
		country_next_labels[i].text = ""
		country_pipeline_labels[i].text = ""
		country_election_labels[i].text = ""
		country_welfare_labels[i].text = _welfare_check_summary(country)
		var policy_slot_node = country_policy_slots[i]
		policy_slot_node.set_skin(Color(0.050, 0.044, 0.032, 0.96) if not country.selected_policy.is_empty() and (game.revealed_policies or game.current_phase() == "resolution") else Color(0.032, 0.038, 0.038, 0.94), accent, 2, "card")
		var worker_icon: TextureRect = country_worker_icons[i]
		var has_policy: bool = not country.selected_policy.is_empty()
		var assigned_workers: Array = country.assigned_worker_list()
		worker_icon.visible = has_policy and not assigned_workers.is_empty()
		var count_label: Label = country_stamp_slots[i].get_node_or_null("WorkerCount")
		if count_label != null:
			count_label.text = str(assigned_workers.size()) if assigned_workers.size() > 1 else ""
		if has_policy and not assigned_workers.is_empty():
			worker_icon.texture = token_assets.texture(UiCatalogScript.worker_token(String(assigned_workers[0])))
			worker_icon.modulate = Color.WHITE
		_refresh_country_risk_chips(i, country)

func _refresh_domestic_state_panel() -> void:
	var panel: Control = board_layer.get_node_or_null("DomesticStatePanel")
	if panel == null:
		return
	panel.visible = false
	if selected_country_index < 0 or selected_country_index >= game.countries.size():
		return
	var country = game.countries[selected_country_index]
	var title: Label = panel.get_node_or_null("DomesticStateTitle")
	if title != null:
		title.text = "%s国の公開国内情勢（状態デッキ）" % UiCatalogScript.country_emblem(selected_country_index)
	if domestic_state_deck_label != null:
		domestic_state_deck_label.text = "状態山札:%d  公開:%d  捨札:%d  次札:%s" % [
			country.deck.size(),
			country.hand.size(),
			country.discard.size(),
			_next_deck_name(country).substr(0, 8)
		]
	var visible_states := []
	for card in country.hand:
		if _is_state_card(card):
			visible_states.append(card)
	for i in range(domestic_state_cards.size()):
		var card_node: Control = domestic_state_cards[i]
		var label: Label = domestic_state_labels[i]
		var has_card := i < visible_states.size()
		card_node.visible = true
		if has_card:
			var card: Dictionary = visible_states[i]
			var border := BAD.darkened(0.04) if String(card.get("type", "")) == "vulnerability" else WARN.darkened(0.05)
			if card_node.has_method("set_skin"):
				card_node.set_skin(Color(0.17, 0.13, 0.10, 0.97), border, 2, "card")
			var icon: TextureRect = card_node.get_node_or_null("DomesticStateIcon")
			if icon != null:
				icon.texture = token_assets.texture(UiCatalogScript.card_token(card))
			label.text = _domestic_state_card_text(card)
			card_node.tooltip_text = _plain_card_detail(country, card)
		else:
			if card_node.has_method("set_skin"):
				card_node.set_skin(Color(0.055, 0.046, 0.038, 0.80), BOARD_LINE.darkened(0.18), 1, "card")
			label.text = "公開なし\n状態デッキ待ち"
			card_node.tooltip_text = "この枠は状態デッキから公開される国内情勢カードです。政策カードではありません。"

func _refresh_policy_preview_panel() -> void:
	if policy_preview_panel == null or policy_preview_label == null:
		return
	var show_preview: bool = game.current_phase() == "policy_planning" and not _is_selecting_policy_target()
	policy_preview_panel.visible = show_preview
	if not show_preview:
		return
	var country = game.countries[selected_country_index]
	var options: Array = game.policy_options(selected_country_index)
	if options.is_empty():
		policy_preview_label.text = "政策議題なし"
		return
	policy_preview_index = clampi(policy_preview_index, 0, options.size() - 1)
	var policy: Dictionary = options[policy_preview_index]
	_refresh_policy_focus_card(country, policy)
	policy_preview_label.text = _policy_preview_text(country, policy, policy_preview_index)

func _set_policy_preview(index: int) -> void:
	policy_preview_index = index
	_refresh_policy_preview_panel()

func _refresh_policy_focus_card(country, policy: Dictionary) -> void:
	if policy_focus_card == null:
		return
	var selected: bool = not country.selected_policy.is_empty() and String(country.selected_policy.get("id", "")) == String(policy.get("id", ""))
	var available: bool = country.is_policy_available(policy)
	var border: Color = COUNTRY_ACCENTS[selected_country_index].lightened(0.18) if selected else _policy_source_color(policy).lightened(0.18)
	var fill: Color = CARD_FACE if available else CARD_FACE.darkened(0.20)
	policy_focus_card.set_skin(fill, border, 3 if selected else 2, "card")
	policy_focus_card.tooltip_text = _plain_card_detail(country, policy)
	if policy_focus_icon != null:
		policy_focus_icon.texture = token_assets.texture(UiCatalogScript.card_token(policy))
	if policy_focus_title != null:
		policy_focus_title.text = _ellipsize(UiCatalogScript.short_card_name(policy), 10)
	if policy_focus_source != null:
		policy_focus_source.text = "%s / %s" % [_policy_source_label(policy), "選択中" if selected else "候補"]
	if policy_focus_cost != null:
		policy_focus_cost.text = _ellipsize(_policy_menu_footer(country, policy), 16)

func _refresh_policy_slot(animate: bool) -> void:
	var country = game.countries[selected_country_index]
	var phase: String = game.current_phase()
	var country_name := "%s国" % UiCatalogScript.country_emblem(selected_country_index)
	var waiting_for_target: bool = not country.selected_policy.is_empty() and String(country.selected_policy.get("target", "")) == "country"
	policy_slot.visible = phase != "policy_planning" or waiting_for_target
	var title: Label = policy_slot.get_node_or_null("PolicySlotTitle")
	if phase == "policy_planning":
		if title != null:
			title.text = "操作ガイド: 政策計画"
			title.add_theme_font_size_override("font_size", 17)
		policy_slot_label.add_theme_font_size_override("font_size", 14)
		if not country.selected_policy.is_empty() and String(country.selected_policy.get("target", "")) == "country":
			policy_slot_label.text = "%s: 対象国マットをクリック\n%s" % [country_name, _target_effect_preview(country)]
		else:
			policy_slot_label.text = "%s: 提出済み。右上で次国へ" % country_name if not country.selected_policy.is_empty() else "%s: 下の政策を1枚クリック\n出所・圧力・不足を確認" % country_name
	elif phase == "worker_assignment":
		if title != null:
			title.text = "操作ガイド: ワーカー配置"
			title.add_theme_font_size_override("font_size", 18)
		policy_slot_label.add_theme_font_size_override("font_size", 16)
		policy_slot_label.text = "%s: ワーカーを1つ選ぶ\n選んだら右上「印確定」" % country_name
	elif phase == "simultaneous_reveal":
		if title != null:
			title.text = "操作ガイド: 同時公開"
			title.add_theme_font_size_override("font_size", 17)
		policy_slot_label.add_theme_font_size_override("font_size", 14)
		policy_slot_label.text = "4国の伏せ札を公開\n右上「公開」をクリック"
	elif phase == "resolution":
		if title != null:
			title.text = "操作ガイド: 解決"
			title.add_theme_font_size_override("font_size", 17)
		policy_slot_label.add_theme_font_size_override("font_size", 14)
		policy_slot_label.text = "%sを確認\n右上「解決」で進む" % _resolution_step_name(resolution_step_index) if resolution_review_active else "公開済み政策を\n順に解決"
	elif phase == "negotiation":
		if title != null:
			title.text = "操作ガイド: 国際交渉"
			title.add_theme_font_size_override("font_size", 17)
		policy_slot_label.add_theme_font_size_override("font_size", 14)
		policy_slot_label.text = "%s: 上の議題をクリック可\n終えたら右上「政策へ」" % country_name
	else:
		if title != null:
			title.text = "操作ガイド"
			title.add_theme_font_size_override("font_size", 17)
		policy_slot_label.add_theme_font_size_override("font_size", 14)
		policy_slot_label.text = CardTextFormatterScript.planned_text(country, game.revealed_policies, phase, game.is_finished).replace("[center]", "").replace("[/center]", "").replace("[b]", "").replace("[/b]", "")
	_refresh_cost_sockets(country)
	if animate:
		_bump(policy_slot)

func _refresh_cost_sockets(country) -> void:
	var policy: Dictionary = country.selected_policy
	if policy.is_empty():
		policy = CardTextFormatterScript.first_policy(game.policy_options(selected_country_index))
	var costs: Dictionary = policy.get("costs", {}) if not policy.is_empty() else {}
	var preview: Dictionary = game._preview_policy_cost(country, policy) if not policy.is_empty() else {}
	var shortages: Dictionary = preview.get("shortages", {}) if preview is Dictionary else {}
	for i in range(policy_cost_labels.size()):
		if i >= COST_KEYS.size():
			continue
		var key := String(COST_KEYS[i])
		var required := int(costs.get(key, 0))
		var shortage := int(shortages.get(key, 0))
		var label: Label = policy_cost_labels[i]
		var socket = label.get_parent()
		var color := GOOD if required == 0 or shortage == 0 else BAD
		if socket != null and socket.has_method("set_skin"):
			socket.set_skin(Color(0.020, 0.018, 0.014, 0.76), color.darkened(0.05), 1, "plaque")
		label.text = "%s%d" % [_cost_short_name(key), required]
		label.add_theme_color_override("font_color", color.lightened(0.18) if required > 0 else MUTED)

func _refresh_status_panels() -> void:
	if score_panel != null:
		var scores: Array = game.get_scores()
		if not scores.is_empty() and bool(scores[0].get("global_collapse", false)):
			score_panel.text = "全員敗北  世界恐慌"
			return
		var parts := []
		for score in scores:
			parts.append("%s %d" % [String(score.get("display_name", "")).substr(0, 2), int(score.get("score", 0))])
		score_panel.text = "  ".join(parts)
	if log_panel != null:
		log_panel.text = "ログ"

func _refresh_final_score_overlay() -> void:
	if final_score_panel == null:
		return
	final_score_panel.visible = game.is_finished
	if not game.is_finished:
		return
	var scores: Array = game.get_scores()
	var is_collapse := not scores.is_empty() and bool(scores[0].get("global_collapse", false))
	var title: Label = final_score_panel.get_node_or_null("FinalScoreTitle")
	if title != null:
		title.text = "全員敗北" if is_collapse else "最終評議会"
	var subtitle: Label = final_score_panel.get_node_or_null("FinalScoreSubtitle")
	if subtitle != null:
		subtitle.text = "世界恐慌が臨界点に到達" if is_collapse else "最終順位とレガシー目標"
	for i in range(final_score_labels.size()):
		var label: Label = final_score_labels[i]
		if i >= scores.size():
			label.text = ""
			continue
		var score: Dictionary = scores[i]
		if is_collapse:
			label.text = "%s\n0点\nレガシー 無効\n勝者なし" % String(score.get("display_name", "")).substr(0, 11)
		else:
			label.text = "%s\n%d点\n厚生 %d / 影響 %d\nGDP %s\nレガシー +%d" % [
				String(score.get("display_name", "")).substr(0, 11),
				int(score.get("score", 0)),
				_welfare_total_for_score(score),
				_influence_for_score(score),
				_gdp_history_for_score(score),
				int(score.get("legacy_bonus", 0)),
			]
	if final_news_label != null:
		final_news_label.text = _news_headlines(game.log)

func _refresh_resolution_flow() -> void:
	if resolution_step_nodes.is_empty():
		return
	var panel: Control = board_layer.get_node_or_null("ResolutionFlow")
	if panel != null:
		panel.visible = game.current_phase() == "resolution" or resolution_review_active
	var items: Array = _resolution_items()
	var has_items := not items.is_empty()
	var active_index := clampi(resolution_step_index, 0, 5) if resolution_review_active else 5
	var stage_title: Label = board_layer.find_child("ResolutionStageTitle", true, false)
	if stage_title != null:
		stage_title.text = "今見る: %s" % _resolution_step_name(active_index)
		stage_title.add_theme_color_override("font_color", WARN.lightened(0.20))
	var stage_help: Label = board_layer.find_child("ResolutionStageHelp", true, false)
	if stage_help != null:
		stage_help.text = _resolution_step_help(active_index)
	var satisfied := 0
	var costs := 0
	var country_effects := 0
	var world_effects := 0
	var mutations := 0
	var macro_changes := 0
	for item in items:
		if bool(item.get("pressure_satisfied", false)):
			satisfied += 1
		costs += _as_dict(item.get("costs", {})).size()
		country_effects += _diff_count(_as_dict(item.get("country_diffs", {})))
		world_effects += _as_dict(item.get("world_diff", {})).size()
		mutations += int(item.get("mutation_count", 0))
	var macro: Dictionary = last_resolution_snapshot.get("macro", {})
	if not macro.is_empty():
		macro_changes = _diff_count(_as_dict(macro.get("country_diffs", {}))) + _as_dict(macro.get("world_diff", {})).size()
	_set_resolution_step(0, "満 %d/%d" % [satisfied, items.size()] if has_items else "提出待ち", GOOD if satisfied == items.size() and has_items else WARN)
	_set_resolution_step(1, "費 %d" % costs if has_items else "未判定", WARN if costs > 0 else MUTED)
	_set_resolution_step(2, "国 %d" % country_effects if has_items else "未適用", GOOD if country_effects > 0 else MUTED)
	_set_resolution_step(3, "世 %d" % world_effects if has_items else "未波及", BLUE if world_effects > 0 else MUTED)
	_set_resolution_step(4, "変 %d" % mutations if has_items else "未変質", BAD if mutations > 0 else MUTED)
	_set_resolution_step(5, "合 %d" % macro_changes if has_items else "未合成", WARN if macro_changes > 0 else MUTED)

func _set_resolution_step(index: int, text: String, accent: Color) -> void:
	if index < 0 or index >= resolution_step_nodes.size():
		return
	var step = resolution_step_nodes[index]
	var active := resolution_review_active and index == resolution_step_index
	var reached := not resolution_review_active or index <= resolution_step_index
	var fill := Color(0.065, 0.046, 0.026, 0.92) if active else Color(0.040, 0.032, 0.022, 0.84)
	var border := accent if reached else BOARD_LINE.darkened(0.35)
	step.set_skin(fill, border, 3 if active else 1, "card")
	var label: Label = resolution_step_labels[index]
	label.text = text
	label.add_theme_color_override("font_color", accent.lightened(0.30) if reached else MUTED)

func _refresh_context_visibility() -> void:
	var phase: String = game.current_phase()
	var planning_focus := phase == "policy_planning"
	var worker_focus := phase == "worker_assignment"
	var world_visible := not planning_focus and not worker_focus
	_apply_world_layout(phase == "negotiation", phase == "resolution" or resolution_review_active)
	var world_panel: Control = board_layer.get_node_or_null("WorldPanel")
	if world_panel != null:
		world_panel.visible = world_visible
	for key in WORLD_TRACKS:
		var world_tile: Control = board_layer.get_node_or_null("WorldTrack_%s" % key)
		if world_tile != null:
			world_tile.visible = world_visible
	var event_summary: Control = board_layer.get_node_or_null("WorldEventSummary")
	if event_summary != null:
		event_summary.visible = world_visible
	for node_name in ["EventCard", "CountryDetailPanel"]:
		var sidebar_node: Control = board_layer.get_node_or_null(node_name)
		if sidebar_node != null:
			sidebar_node.visible = false
	var score_node: Control = board_layer.get_node_or_null("ScorePanel")
	if score_node != null:
		score_node.visible = not planning_focus and not worker_focus
	var log_node: Control = board_layer.get_node_or_null("LogPanel")
	if log_node != null:
		log_node.visible = not planning_focus and not worker_focus
	var negotiation_panel: Control = board_layer.get_node_or_null("NegotiationPanel")
	if negotiation_panel != null:
		negotiation_panel.visible = phase == "negotiation"
	for item in AGENDA:
		var agenda_tile: Control = board_layer.get_node_or_null("Agenda_%s" % String(item["tag"]))
		if agenda_tile != null:
			agenda_tile.visible = phase == "negotiation"
	var resolution_panel: Control = board_layer.get_node_or_null("ResolutionFlow")
	if resolution_panel != null:
		resolution_panel.visible = phase == "resolution" or resolution_review_active
	var domestic_panel: Control = board_layer.get_node_or_null("DomesticStatePanel")
	if domestic_panel != null:
		domestic_panel.visible = false
	if planning_country_panel != null:
		planning_country_panel.visible = false
	if policy_slot != null and selected_country_index >= 0 and selected_country_index < game.countries.size():
		var country = game.countries[selected_country_index]
		var waiting_for_target: bool = not country.selected_policy.is_empty() and String(country.selected_policy.get("target", "")) == "country"
		policy_slot.visible = (phase != "policy_planning" and phase != "worker_assignment" and phase != "negotiation") or waiting_for_target
		if phase == "resolution" or resolution_review_active:
			policy_slot.visible = false
	if planning_focus:
		var target_mode := false
		if selected_country_index >= 0 and selected_country_index < game.countries.size():
			var selected_country = game.countries[selected_country_index]
			target_mode = not selected_country.selected_policy.is_empty() and String(selected_country.selected_policy.get("target", "")) == "country"
		for i in range(country_seats.size()):
			var seat: Control = country_seats[i]
			seat.visible = target_mode

func _apply_world_layout(wide: bool, resolution_mode := false) -> void:
	var panel: Control = board_layer.get_node_or_null("WorldPanel")
	if panel == null:
		return
	var panel_pos: Vector2 = board_layout["world_panel_pos"]
	var panel_size: Vector2 = board_layout["world_panel_size"]
	if resolution_mode and board_layout.has("world_panel_resolution_size"):
		panel_size = board_layout["world_panel_resolution_size"]
	elif wide and board_layout.has("world_panel_wide_size"):
		panel_size = board_layout["world_panel_wide_size"]
	panel.position = _snap_vec(panel_pos)
	panel.size = _snap_vec(panel_size)
	var title: Label = panel.get_node_or_null("WorldPanelTitle")
	if title != null:
		title.position = Vector2(0, 12)
		title.size = Vector2(panel.size.x, 34)
		title.add_theme_font_size_override("font_size", 30)
	var hint: Label = panel.get_node_or_null("WorldPanelHint")
	if hint != null:
		hint.position = Vector2(0, panel.size.y - 34)
		hint.size = Vector2(panel.size.x, 24)
		hint.add_theme_font_size_override("font_size", 18)
	var columns := 3 if wide and not resolution_mode else 4
	var gap := 16.0 if wide and not resolution_mode else 12.0
	var row_count := ceili(float(WORLD_TRACKS.size()) / float(columns))
	if wide and not resolution_mode:
		row_count += 1
	else:
		row_count = maxi(row_count, 2)
	var track_w := (panel_size.x - 80.0 - gap * float(columns - 1)) / float(columns)
	var track_h := (panel_size.y - 98.0 - gap * float(row_count - 1)) / float(row_count)
	var start := panel_pos + Vector2(40.0, 62.0)
	for i in range(WORLD_TRACKS.size()):
		var key: String = WORLD_TRACKS[i]
		var tile: Control = board_layer.get_node_or_null("WorldTrack_%s" % key)
		if tile == null:
			continue
		var col := i % columns
		var row := floori(float(i) / float(columns))
		tile.position = _snap_vec(start + Vector2((track_w + gap) * col, (track_h + gap) * row))
		tile.size = _snap_vec(Vector2(track_w, track_h))
		var icon_size: float = minf(70.0 if wide and not resolution_mode else 58.0, tile.size.y - 58.0)
		var icon: TextureRect = tile.get_node_or_null("TrackIcon")
		if icon != null:
			icon.position = _snap_vec(Vector2(16, 16))
			icon.size = _snap_vec(Vector2(icon_size, icon_size))
		var label: Label = tile.get_node_or_null("TrackLabel")
		if label != null:
			label.position = _snap_vec(Vector2(88, 10))
			label.size = _snap_vec(Vector2(tile.size.x - 170, 34))
			label.add_theme_color_override("font_color", WARN.lightened(0.18))
			label.add_theme_font_size_override("font_size", 29 if wide and not resolution_mode else 26)
		var value_label: Label = tile.get_node_or_null("TrackValue")
		if value_label != null:
			var value_w := 104.0 if wide and not resolution_mode else 84.0
			value_label.position = _snap_vec(Vector2(tile.size.x - value_w - 16.0, 8))
			value_label.size = _snap_vec(Vector2(value_w, 38))
			value_label.add_theme_font_size_override("font_size", 32 if wide and not resolution_mode else 30)
		var meaning: Label = tile.get_node_or_null("TrackMeaning")
		if meaning != null:
			meaning.position = _snap_vec(Vector2(88, 50))
			meaning.size = _snap_vec(Vector2(tile.size.x - 104, 30))
			meaning.add_theme_font_size_override("font_size", 20 if wide and not resolution_mode else 18)
		var rail: Control = tile.get_node_or_null("TrackRail")
		if rail != null:
			rail.position = _snap_vec(Vector2(20, tile.size.y - 32))
			rail.size = _snap_vec(Vector2(tile.size.x - 40, 20))
	var event_summary: Control = board_layer.get_node_or_null("WorldEventSummary")
	if event_summary != null:
		var event_pos := start + Vector2((track_w + gap) * 3.0, track_h + gap)
		var event_size := Vector2(track_w, track_h)
		if wide and not resolution_mode:
			event_pos = start + Vector2(0.0, (track_h + gap) * float(row_count - 1))
			event_size = Vector2(panel_size.x - 80.0, track_h)
		event_summary.position = _snap_vec(event_pos)
		event_summary.size = _snap_vec(event_size)
		var event_icon: TextureRect = event_summary.get_node_or_null("WorldEventIcon")
		if event_icon != null:
			event_icon.position = _snap_vec(Vector2(16, 18))
			event_icon.size = _snap_vec(Vector2(52, 52))
		var event_caption: Label = event_summary.get_node_or_null("WorldEventSummaryCaption")
		if event_caption != null:
			event_caption.position = _snap_vec(Vector2(84, 10))
			event_caption.size = _snap_vec(Vector2(event_summary.size.x - 100, 24))
			event_caption.add_theme_font_size_override("font_size", 17 if wide and not resolution_mode else 16)
		var event_title: Label = event_summary.get_node_or_null("WorldEventSummaryTitle")
		if event_title != null:
			event_title.position = _snap_vec(Vector2(84, 34))
			event_title.size = _snap_vec(Vector2(event_summary.size.x - 100, 32))
			event_title.add_theme_font_size_override("font_size", 24 if wide and not resolution_mode else 21)
		var event_message: Label = event_summary.get_node_or_null("WorldEventSummaryMessage")
		if event_message != null:
			event_message.position = _snap_vec(Vector2(18, 72))
			event_message.size = _snap_vec(Vector2(event_summary.size.x - 36, event_summary.size.y - 84))
			event_message.add_theme_font_size_override("font_size", 17 if wide and not resolution_mode else 15)

func _refresh_resolution_links() -> void:
	if resolution_overlay == null or resolution_marker_layer == null:
		return
	_clear_children(resolution_marker_layer)
	resolution_overlay.set_paths([])

func _resolution_stage_visible(stage: int, active_step: int) -> bool:
	if not resolution_review_active:
		return true
	return stage == active_step

func _should_show_resolution_links() -> bool:
	return not last_resolution_snapshot.is_empty() or game.current_phase() == "simultaneous_reveal" or game.current_phase() == "resolution"

func _resolution_path(step_index: int, target: Vector2, color: Color, label: String) -> Dictionary:
	return {
		"from": _control_center(resolution_step_nodes[step_index]),
		"to": target,
		"color": color,
		"label": label
	}

func _control_center(control: Control) -> Vector2:
	return control.global_position + control.size * 0.5

func _country_pressure_center(country_index: int) -> Vector2:
	var pressure: Control = country_seats[country_index].get_node("PressureCard")
	return _control_center(pressure)

func _country_result_chip_center(country_index: int, offset_y: float) -> Vector2:
	var seat: Control = country_seats[country_index]
	var screen_center := _screen().x * 0.5
	var outside_x := seat.global_position.x + seat.size.x + 22.0
	if seat.global_position.x > screen_center:
		outside_x = seat.global_position.x - 22.0
	return Vector2(outside_x, seat.global_position.y + seat.size.y * 0.5 + offset_y)

func _add_result_chip(node_name: String, center: Vector2, text: String, accent: Color) -> void:
	var chip_size := Vector2(38, 28) if text.length() > 1 else Vector2(28, 28)
	var chip = BoardPieceScript.new()
	chip.name = node_name
	chip.position = center - chip_size * 0.5
	chip.size = chip_size
	chip.set_skin(Color(0.030, 0.024, 0.018, 0.88), accent, 2, "circle")
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.name = "Text"
	label.text = text
	label.position = Vector2.ZERO
	label.size = chip_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", accent.lightened(0.30))
	label.add_theme_font_size_override("font_size", 11 if text.length() > 1 else 12)
	_apply_label_outline(label, accent.lightened(0.30))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	resolution_marker_layer.add_child(chip)

func _diff_chip_label(diffs: Dictionary, fallback: String) -> String:
	for key in diffs.keys():
		return "%s%s" % [_track_chip_prefix(String(key), fallback), _signed_delta(int(diffs[key]))]
	return fallback

func _single_diff_chip_label(diffs: Dictionary, key: String, fallback: String) -> String:
	if diffs.has(key):
		return "%s%s" % [_track_chip_prefix(key, fallback), _signed_delta(int(diffs[key]))]
	return fallback

func _track_chip_prefix(key: String, fallback: String) -> String:
	var names := {
		"world_demand": "需",
		"world_interest_rate": "金",
		"trade_openness": "貿",
		"international_financial_instability": "融",
		"depression": "恐",
		"protectionism": "保",
		"global_coordination": "協",
		"gdp_gap": "GDP",
		"inflation": "物",
		"expected_inflation": "期",
		"unemployment": "失",
		"debt": "債",
		"financial_stress": "融",
		"political_capital": "政",
		"influence": "影"
	}
	return names.get(key, fallback)

func _signed_delta(delta: int) -> String:
	if delta > 0:
		return "+%d" % delta
	return str(delta)

func _next_deck_summary(country) -> String:
	return "次:%s" % _next_deck_name(country)

func _next_deck_name(country) -> String:
	if country.deck.is_empty():
		return "なし"
	var card: Dictionary = country.deck[0]
	return UiCatalogScript.short_card_name(card).substr(0, 7)

func _pipeline_summary(country) -> String:
	var count: int = country.pending_effects.size()
	if count <= 0:
		return "待:0"
	var first: Dictionary = country.pending_effects[0]
	var label: String = String(first.get("display_name", first.get("policy_id", "政策ラグ")))
	return "待:%d %s" % [count, label.substr(0, 5)]

func _state_card_summary(country) -> String:
	if country.hand.is_empty():
		return "なし"
	var parts := []
	for card in country.hand:
		if not _is_state_card(card):
			continue
		parts.append(UiCatalogScript.short_card_name(card).substr(0, 5))
		if parts.size() >= 2:
			break
	return " / ".join(parts) if not parts.is_empty() else "なし"

func _state_hand_card_text(country) -> String:
	if country.hand.is_empty():
		return "情勢: なし"
	var parts := []
	for card in country.hand:
		if not _is_state_card(card):
			continue
		parts.append(_ellipsize(UiCatalogScript.short_card_name(card), 4))
		if parts.size() >= 1:
			break
	return "情勢: %s" % (" / ".join(parts) if not parts.is_empty() else "なし")

func _domestic_state_card_text(card: Dictionary) -> String:
	var kind := "脆弱性" if String(card.get("type", "")) == "vulnerability" else "レガシー"
	var title := _ellipsize(UiCatalogScript.short_card_name(card), 9)
	var response: Dictionary = card.get("response", {})
	var response_text := "対応なし"
	if not response.is_empty():
		var tags := []
		for tag in response.get("removed_by_tags", []):
			tags.append(_short_tag_list([tag], 1))
			if tags.size() >= 2:
				break
		response_text = "対応:%s" % ("・".join(tags) if not tags.is_empty() else "可")
	return "%s\n%s\n%s" % [title, kind, response_text]

func _is_state_card(card: Dictionary) -> bool:
	var type := String(card.get("type", ""))
	return type == "vulnerability" or type == "legacy"

func _response_target_summary(country) -> String:
	var candidates := _response_candidate_indices(country)
	if candidates.is_empty():
		return "候補なし"
	var index := int(country.selected_response_index)
	if index < 0 or not candidates.has(index):
		index = candidates[0]
	var card: Dictionary = country.hand[index]
	var response: Dictionary = card.get("response", {})
	var extra_costs: Dictionary = response.get("extra_costs", {})
	var cost_parts := []
	for key in extra_costs.keys():
		cost_parts.append("%s%d" % [_cost_short_name(String(key)), int(extra_costs[key])])
	var cost_text := ""
	if not cost_parts.is_empty():
		cost_text = "(%s)" % " ".join(cost_parts)
	return "%s%s" % [
		UiCatalogScript.short_card_name(card).substr(0, 6),
		cost_text
	]

func _response_candidate_indices(country) -> Array:
	var result := []
	var policy: Dictionary = country.selected_policy
	if policy.is_empty():
		return result
	var policy_tags: Array = policy.get("tags", [])
	for i in range(country.hand.size()):
		var card: Dictionary = country.hand[i]
		if String(card.get("type", "")) != "vulnerability":
			continue
		var response: Dictionary = card.get("response", {})
		if response.is_empty():
			continue
		for tag in response.get("removed_by_tags", []):
			if policy_tags.has(tag):
				result.append(i)
				break
	return result

func _election_short_status(country) -> String:
	if country.is_election_turn(game.turn):
		return "選:本"
	if country.is_election_eve(game.turn):
		return "選:前"
	var next_turn: int = int(country.election_turn)
	while next_turn < game.turn:
		next_turn += int(country.election_period)
	return "選:%d" % maxi(0, next_turn - game.turn)

func _welfare_check_summary(country) -> String:
	return "厚:%d/4" % _welfare_conditions(country).size()

func _welfare_condition_marks(country) -> String:
	var labels := {
		"gdp": "GDP",
		"jobs": "雇",
		"prices": "物",
		"finance": "金"
	}
	var passed: Array = _welfare_conditions(country)
	var parts: Array = []
	for key in ["gdp", "jobs", "prices", "finance"]:
		parts.append("%s%s" % [labels[key], "✓" if passed.has(key) else "×"])
	return " ".join(parts)

func _worker_summary(country) -> String:
	var names := []
	for worker in country.assigned_worker_list():
		names.append(UiCatalogScript.worker_name(String(worker)).substr(0, 3))
	return "/".join(names) if not names.is_empty() else "未"

func _welfare_conditions(country) -> Array:
	var t: Dictionary = country.tracks
	var passed: Array = []
	var gdp_gap: int = int(t.get("gdp_gap", 0))
	if gdp_gap >= 0 and gdp_gap <= 1:
		passed.append("gdp")
	if int(t.get("unemployment", 0)) <= 3:
		passed.append("jobs")
	if abs(int(t.get("inflation", 0)) - 2) <= 1:
		passed.append("prices")
	if int(t.get("financial_stress", 0)) <= 4:
		passed.append("finance")
	return passed

func _cost_short_name(key: String) -> String:
	var names: Dictionary = {
		"fiscal": "財",
		"political": "政",
		"administrative": "行",
		"credibility": "信",
		"international": "国",
		"industrial": "産"
	}
	return names.get(key, key.substr(0, 1))

func _turn_news_text() -> String:
	var event: Dictionary = game.world.current_event
	var lines: Array = [
		"公開イベント",
		String(event.get("display_name", "なし")),
		String(event.get("message", "")),
		"",
		"解決ログ",
		_news_headlines(game.log).replace("\n\n", "\n")
	]
	var welfare_parts: Array = []
	for i in range(game.countries.size()):
		var country = game.countries[i]
		welfare_parts.append("%s国 %s 累%d" % [
			UiCatalogScript.country_emblem(i),
			_welfare_check_summary(country),
			int(country.welfare_score)
		])
	lines.append("")
	lines.append("厚生")
	lines.append(" / ".join(welfare_parts))
	return "\n".join(lines)

func _persistent_crisis_summary() -> String:
	var crises: Array = game.world.active_crises
	if crises.is_empty():
		return ""
	var parts := []
	for entry in crises:
		if not (entry is Dictionary):
			continue
		parts.append("%s 残%d / 解除:%s" % [
			String(entry.get("display_name", "危機")).substr(0, 8),
			int(entry.get("turns", 0)),
			String(entry.get("clear_text", "条件")).substr(0, 8)
		])
		if parts.size() >= 2:
			break
	return "持続: %s" % " / ".join(parts)

func _refresh_country_detail_panel() -> void:
	if country_detail_label == null:
		return
	var country = game.countries[selected_country_index]
	var pressure := String(country.domestic_pressure.get("display_name", "国内圧力なし"))
	country_detail_label.text = "%s\n圧:%s  選:%s  厚:%d\n公開:%s\n次札:%s  条件:%s\nリスク:%s  山/捨:%d/%d" % [
		country.display_name.substr(0, 9),
		pressure.substr(0, 8),
		_election_status(country),
		int(country.welfare_score),
		_state_card_summary(country),
		_next_deck_name(country).substr(0, 6),
		_welfare_condition_marks(country),
		_country_risk_words(country).substr(0, 8),
		country.deck.size(),
		country.discard.size()
	]

func _refresh_workers() -> void:
	var assigned: Array = game.countries[selected_country_index].assigned_worker_list()
	var show_workers: bool = game.current_phase() == "worker_assignment"
	var token_size: Vector2 = board_layout["worker_size"]
	var start: Vector2 = board_layout["worker_origin"]
	var step: Vector2 = board_layout["worker_step"]
	var columns := int(board_layout.get("worker_columns", 5))
	for i in range(WORKERS.size()):
		var worker: String = WORKERS[i]
		var node = worker_nodes[worker]
		node.visible = show_workers
		if not show_workers:
			continue
		node.size = _snap_vec(token_size)
		var col := i % columns
		var row := floori(float(i) / float(columns))
		node.position = _snap_vec(start + Vector2(step.x * col, step.y * row))
		node.home_position = node.position
		var selected: bool = assigned.has(worker)
		node.set_skin(Color(0.105, 0.074, 0.040, 0.98) if selected else Color(0.050, 0.038, 0.026, 0.96), COUNTRY_ACCENTS[selected_country_index].lightened(0.20) if selected else BOARD_LINE.darkened(0.16), 4 if selected else 2, "card")
		var icon: TextureRect = node.get_node_or_null("WorkerIcon")
		if icon != null:
			icon.position = _snap_vec(Vector2(20, 28))
			icon.size = _snap_vec(Vector2(86, 86))
		var name_label: Label = node.get_node_or_null("WorkerName")
		if name_label != null:
			name_label.position = _snap_vec(Vector2(122, 24))
			name_label.size = _snap_vec(Vector2(token_size.x - 140.0, 34))
			name_label.add_theme_font_size_override("font_size", 21)
			name_label.add_theme_color_override("font_color", TEXT)
		var role_label: Label = node.get_node_or_null("WorkerRole")
		if role_label != null:
			role_label.position = _snap_vec(Vector2(122, 66))
			role_label.size = _snap_vec(Vector2(token_size.x - 140.0, 24))
			role_label.add_theme_font_size_override("font_size", 17)
			role_label.add_theme_color_override("font_color", WARN.lightened(0.18))
		var hint_label: Label = node.get_node_or_null("WorkerHint")
		if hint_label != null:
			hint_label.position = _snap_vec(Vector2(20, 112))
			hint_label.size = _snap_vec(Vector2(token_size.x - 40.0, 34))
			hint_label.add_theme_font_size_override("font_size", 12)
			hint_label.add_theme_color_override("font_color", MUTED)

func _on_advance_pressed() -> void:
	if turn_news_active:
		_hide_turn_news_overlay()
		return
	var previous_phase: int = game.phase_index
	if game.current_phase() == "policy_planning" and not _all_policies_submitted():
		selected_country_index = _next_country_without_policy(selected_country_index - 1)
		_refresh_board(true)
		return
	if game.current_phase() == "worker_assignment" and not _all_workers_confirmed():
		_ensure_worker_confirmations()
		if selected_country_index >= 0 and selected_country_index < worker_assignment_confirmed.size():
			worker_assignment_confirmed[selected_country_index] = true
		selected_country_index = _next_country_without_worker(selected_country_index)
		if selected_country_index < 0:
			_enter_simultaneous_reveal()
		_refresh_board(true)
		return
	if game.current_phase() == "worker_assignment" and _all_workers_confirmed():
		_enter_simultaneous_reveal()
		_refresh_board(true)
		_animate_phase_marker(previous_phase, game.phase_index)
		return
	if game.current_phase() == "simultaneous_reveal":
		_start_resolution_review(previous_phase)
		return
	if resolution_review_active:
		_advance_resolution_review()
		return
	game.advance_phase()
	_refresh_board(true)
	_animate_phase_marker(previous_phase, game.phase_index)

func _advance_token_text() -> String:
	if turn_news_active:
		return "新聞"
	if game.current_phase() == "policy_planning":
		if not _all_policies_submitted():
			var next_country := _next_country_without_policy(selected_country_index - 1)
			return "%s国へ" % String.chr(65 + next_country) if next_country >= 0 else "担当へ"
		return "担当へ"
	if game.current_phase() == "worker_assignment":
		if not _all_workers_confirmed():
			return "確定"
		return "公開"
	if game.current_phase() == "simultaneous_reveal":
		return "公開"
	if game.current_phase() == "negotiation":
		return "政策選択へ"
	if resolution_review_active or game.current_phase() == "resolution":
		return "次段階" if resolution_review_active and resolution_step_index < 5 else "ターン\n解決"
	if game.is_finished:
		return "終了"
	return "進行"

func _advance_token_tip() -> String:
	if turn_news_active:
		return "新聞を閉じて盤面へ戻ります。"
	if game.current_phase() == "negotiation":
		return "交渉を終えて、各国の政策計画へ進みます。"
	if game.current_phase() == "policy_planning":
		if not _all_policies_submitted():
			return "未提出の国へフォーカスを移します。政策は下段メニューから1枚選びます。"
		return "全政策が伏せられたので、ワーカー配置へ進みます。"
	if game.current_phase() == "worker_assignment":
		if not _all_workers_confirmed():
			return "現在の国の担当印を確定し、次の国へ進みます。"
		return "全担当印が確定したので、同時公開へ進みます。"
	if game.current_phase() == "simultaneous_reveal":
		return "4国の伏せ札を公開し、解決レビューを始めます。"
	if resolution_review_active or game.current_phase() == "resolution":
		return "解決レビューを1段階ずつ読みます。一括で進める場合は「自動」を使います。"
	if game.is_finished:
		return "ゲームは終了しています。"
	return "次のフェーズへ進みます。"

func _recommend_token_text() -> String:
	if game.can_select_policy():
		return "全員\n政策"
	if game.can_assign_worker():
		return "全員\n配置"
	if resolution_review_active or game.current_phase() == "resolution":
		return "一括\n解決"
	return "補助"

func _recommend_token_tip() -> String:
	if game.can_select_policy():
		return "テストプレイ用: 各国の政策を自動選択し、ワーカー配置へ進みます。"
	if game.can_assign_worker():
		return "テストプレイ用: 選択済み政策に合わせて全員のワーカーを自動配置し、同時公開へ進みます。"
	if resolution_review_active or game.current_phase() == "resolution":
		return "解決レビューを飛ばして、このターンを一括解決します。"
	return "現在のフェーズでは推奨操作はありません。"

func _start_resolution_review(previous_phase: int) -> void:
	last_resolution_snapshot = _capture_resolution_snapshot()
	resolution_review_active = true
	resolution_step_index = 0
	game.move_to_phase("resolution")
	game.log.append("全政策が同時公開されました。")
	_refresh_board(true)
	_animate_phase_marker(previous_phase, game.phase_index)

func _advance_resolution_review() -> void:
	if resolution_step_index < 5:
		resolution_step_index += 1
		_refresh_board(true)
		if resolution_step_index >= 0 and resolution_step_index < resolution_step_nodes.size():
			_bump(resolution_step_nodes[resolution_step_index])
		return
	resolution_review_active = false
	resolution_step_index = -1
	game.resolve_turn()
	last_resolution_snapshot = {}
	_refresh_board(true)
	if not game.is_finished:
		_show_turn_news_overlay()

func _resolve_review_now() -> void:
	if not resolution_review_active and game.current_phase() != "resolution":
		return
	resolution_review_active = false
	resolution_step_index = -1
	game.resolve_turn()
	last_resolution_snapshot = {}
	_refresh_board(true)
	if not game.is_finished:
		_show_turn_news_overlay()

func _on_recommend_pressed() -> void:
	_hide_turn_news_overlay()
	if resolution_review_active or game.current_phase() == "resolution":
		_resolve_review_now()
		return
	last_resolution_snapshot = {}
	resolution_review_active = false
	resolution_step_index = -1
	worker_assignment_confirmed = []
	if game.can_select_policy():
		for i in range(game.countries.size()):
			var recommendation := PolicyRecommenderScript.recommend_for_country(game, i)
			if recommendation.is_empty():
				continue
			game.select_policy(i, int(recommendation["policy_index"]))
		if _all_policies_submitted():
			_enter_worker_assignment()
	elif game.can_assign_worker():
		_ensure_worker_confirmations()
		for i in range(game.countries.size()):
			var recommendation := PolicyRecommenderScript.recommend_for_country(game, i)
			if recommendation.is_empty():
				continue
			game.assign_workers(i, recommendation.get("workers", [String(recommendation["worker"])]))
			worker_assignment_confirmed[i] = true
		if _all_workers_confirmed():
			_enter_simultaneous_reveal()
	_refresh_board(true)

func _on_log_panel_pressed() -> void:
	log_highlight_key = _latest_log_world_track()
	_refresh_world()
	if not log_highlight_key.is_empty():
		var track = board_layer.get_node_or_null("WorldTrack_%s" % log_highlight_key)
		if track != null:
			_bump(track)
	_show_turn_news_overlay()

func _on_help_pressed() -> void:
	_show_tutorial_overlay("hidden")

func _on_agenda_declared(tag: String) -> void:
	if game.current_phase() != "negotiation":
		return
	game.declare_agenda(selected_country_index, tag)
	game.request_support(selected_country_index, tag)
	var next_country := _next_country_without_agenda(selected_country_index)
	if next_country >= 0:
		selected_country_index = next_country
	_refresh_board(true)

func _on_country_detail_pressed() -> void:
	if not (game.can_select_policy() or game.can_assign_worker()):
		return
	var country = game.countries[selected_country_index]
	var candidates := _response_candidate_indices(country)
	if candidates.is_empty():
		game.select_response_card(selected_country_index, -1)
		_refresh_board(false)
		return
	var current := int(country.selected_response_index)
	var next_index: int = int(candidates[0])
	var current_pos := candidates.find(current)
	if current_pos >= 0:
		next_index = int(candidates[(current_pos + 1) % candidates.size()])
	game.select_response_card(selected_country_index, next_index)
	_refresh_board(false)

func _on_restart_pressed() -> void:
	game.new_game()
	last_resolution_snapshot = {}
	resolution_review_active = false
	resolution_step_index = -1
	worker_assignment_confirmed = []
	last_selected_country_index = 0
	selected_country_index = 0
	player_country_index = -1
	entry_state = "title"
	_hide_turn_news_overlay()
	_refresh_board(true)
	_apply_entry_state()

func _on_country_selected(country_index: int) -> void:
	if _is_waiting_for_policy_target(selected_country_index, country_index):
		var source_index := selected_country_index
		game.select_policy_target(source_index, country_index)
		selected_country_index = _next_country_without_policy(source_index)
		policy_preview_index = 0
		if selected_country_index < 0:
			_enter_worker_assignment()
		_refresh_board(true)
		_bump(country_seats[country_index])
		return
	if country_index == selected_country_index:
		_bump(country_seats[country_index])
		return
	var previous := selected_country_index
	last_selected_country_index = previous
	selected_country_index = country_index
	policy_preview_index = 0
	policy_menu_page = 0
	var origin = country_seats[country_index].position + Vector2(60, 46)
	_refresh_title()
	_refresh_country_seats()
	_refresh_policy_slot(true)
	_refresh_workers()
	_rebuild_policy_menu(true, origin)
	_animate_country_marker(previous, country_index)

func _on_policy_selected(country_index: int, policy_index: int, from_pos: Vector2) -> void:
	if not game.can_select_policy():
		return
	last_resolution_snapshot = {}
	resolution_review_active = false
	resolution_step_index = -1
	worker_assignment_confirmed = []
	var card: Dictionary = game.policy_options(country_index)[policy_index]
	game.select_policy(country_index, policy_index)
	if String(card.get("target", "")) == "country":
		selected_country_index = country_index
	else:
		selected_country_index = _next_country_without_policy(country_index)
		policy_preview_index = 0
		policy_menu_page = 0
		if selected_country_index < 0:
			_enter_worker_assignment()
	_refresh_board(false)
	var slot: Control = country_policy_slots[country_index]
	_animate_card_to_slot(country_index, card, from_pos, slot.global_position)

func _on_worker_assigned(country_index: int, worker_id: String, from_pos: Vector2) -> void:
	if not game.can_assign_worker():
		return
	game.toggle_worker(country_index, worker_id)
	_ensure_worker_confirmations()
	worker_assignment_confirmed[country_index] = true
	_refresh_board(false)
	var stamp: Control = country_stamp_slots[country_index]
	_animate_token_to_seat(UiCatalogScript.worker_token(worker_id), from_pos, stamp.global_position, COUNTRY_ACCENTS[country_index])

func _next_country_without_policy(after_index: int) -> int:
	for offset in range(1, game.countries.size() + 1):
		var index: int = (after_index + offset) % game.countries.size()
		if game.countries[index].selected_policy.is_empty():
			return index
	return -1

func _on_policy_page_prev() -> void:
	if game.current_phase() != "policy_planning":
		return
	var options: Array = game.policy_options(selected_country_index)
	policy_menu_page = maxi(0, _clamped_policy_menu_page(options) - 1)
	policy_preview_index = mini(policy_preview_index, policy_menu_page * _policy_menu_page_size())
	_rebuild_policy_menu(false)
	_refresh_policy_preview_panel()

func _on_policy_page_next() -> void:
	if game.current_phase() != "policy_planning":
		return
	var options: Array = game.policy_options(selected_country_index)
	var page_count := _policy_menu_page_count(options)
	policy_menu_page = mini(page_count - 1, _clamped_policy_menu_page(options) + 1)
	policy_preview_index = mini(options.size() - 1, policy_menu_page * _policy_menu_page_size())
	_rebuild_policy_menu(false)
	_refresh_policy_preview_panel()

func _is_waiting_for_policy_target(source_index: int, target_index: int) -> bool:
	if not game.can_select_policy():
		return false
	if source_index < 0 or source_index >= game.countries.size():
		return false
	if source_index == target_index:
		return false
	var country = game.countries[source_index]
	return not country.selected_policy.is_empty() and String(country.selected_policy.get("target", "")) == "country"

func _is_selecting_policy_target() -> bool:
	if not game.can_select_policy():
		return false
	if selected_country_index < 0 or selected_country_index >= game.countries.size():
		return false
	var country = game.countries[selected_country_index]
	return not country.selected_policy.is_empty() and String(country.selected_policy.get("target", "")) == "country"

func _next_country_without_worker(after_index: int) -> int:
	_ensure_worker_confirmations()
	for offset in range(1, game.countries.size() + 1):
		var index: int = (after_index + offset) % game.countries.size()
		if not bool(worker_assignment_confirmed[index]):
			return index
	return -1

func _all_policies_submitted() -> bool:
	for country in game.countries:
		if country.selected_policy.is_empty():
			return false
	return true

func _submitted_policy_count() -> int:
	var count := 0
	for country in game.countries:
		if not country.selected_policy.is_empty():
			count += 1
	return count

func _all_workers_confirmed() -> bool:
	_ensure_worker_confirmations()
	for confirmed in worker_assignment_confirmed:
		if not bool(confirmed):
			return false
	return true

func _confirmed_worker_count() -> int:
	_ensure_worker_confirmations()
	var count := 0
	for confirmed in worker_assignment_confirmed:
		if bool(confirmed):
			count += 1
	return count

func _enter_worker_assignment() -> void:
	_reset_worker_confirmations()
	selected_country_index = 0
	game.move_to_phase("worker_assignment")

func _enter_simultaneous_reveal() -> void:
	selected_country_index = 0
	game.move_to_phase("simultaneous_reveal")

func _reset_worker_confirmations() -> void:
	worker_assignment_confirmed.clear()
	for _i in range(game.countries.size()):
		worker_assignment_confirmed.append(false)

func _ensure_worker_confirmations() -> void:
	if worker_assignment_confirmed.size() == game.countries.size():
		return
	_reset_worker_confirmations()

func _add_action_token(node_name: String, text: String, position: Vector2, size: Vector2, action: Callable):
	var shape := "circle" if absf(size.x - size.y) < 1.0 else "card"
	var token = _make_piece(node_name, position, size, Color(0.05, 0.038, 0.024, 0.86), BOARD_LINE, 1, shape)
	token.pressed = action
	var font_size := 18
	if size.x >= 96.0:
		font_size = 28 if shape == "circle" else 23
	elif size.x >= 44.0:
		font_size = 20
	_add_label_to(token, "%sLabel" % node_name, text, Vector2.ZERO, size, font_size, TEXT)
	return token

func _make_piece(node_name: String, position: Vector2, piece_size: Vector2, fill: Color, border: Color, border_width := 1.0, shape := "rect"):
	var piece = BoardPieceScript.new()
	piece.name = node_name
	piece.position = _snap_vec(position)
	piece.size = _snap_vec(piece_size)
	piece.set_skin(fill, border, border_width, shape)
	board_layer.add_child(piece)
	return piece

func _make_overlay_piece(parent: Control, node_name: String, position: Vector2, piece_size: Vector2, fill: Color, border: Color, border_width := 1.0, shape := "rect"):
	var piece = BoardPieceScript.new()
	piece.name = node_name
	piece.position = _snap_vec(position)
	piece.size = _snap_vec(piece_size)
	piece.set_skin(fill, border, border_width, shape)
	parent.add_child(piece)
	return piece

func _make_entry_button(parent: Control, node_name: String, text: String, position: Vector2, piece_size: Vector2, action: Callable):
	var piece = _make_overlay_piece(parent, node_name, position, piece_size, Color(0.075, 0.052, 0.030, 0.94), BOARD_LINE, 2, "card")
	piece.pressed = action
	if not text.is_empty():
		_add_label_to(piece, "%sText" % node_name, text, Vector2.ZERO, piece_size, 22, TEXT)
	return piece

func _make_child_piece(parent: Control, node_name: String, position: Vector2, piece_size: Vector2, fill: Color, border: Color, border_width := 1.0, shape := "rect"):
	var piece = BoardPieceScript.new()
	piece.name = node_name
	piece.position = _snap_vec(position)
	piece.size = _snap_vec(piece_size)
	piece.set_skin(fill, border, border_width, shape)
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(piece)
	return piece

func _make_icon(token_name: String, position: Vector2, icon_size: Vector2, tint: Color, node_name := "", prefer_small := false) -> TextureRect:
	var icon := TextureRect.new()
	if not node_name.is_empty():
		icon.name = node_name
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ZERO
	icon.texture = token_assets.texture(token_name, prefer_small)
	icon.position = _snap_vec(position)
	icon.size = _snap_vec(icon_size)
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _make_icon_medallion(token_name: String, position: Vector2, accent: Color, diameter := 46):
	var medallion := Control.new()
	var snapped_diameter := roundf(diameter)
	medallion.position = _snap_vec(position)
	medallion.size = Vector2(snapped_diameter, snapped_diameter)
	medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medallion.add_child(_make_icon(token_name, Vector2.ZERO, medallion.size, Color.WHITE))
	return medallion

func _make_disc_label(node_name: String, text: String, position: Vector2, diameter: float, accent: Color):
	var disc = BoardPieceScript.new()
	disc.name = node_name
	disc.position = position
	disc.size = Vector2(diameter, diameter)
	disc.set_skin(Color(0.02, 0.022, 0.020, 0.62), accent, 1, "circle")
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(disc, "%sText" % node_name, text, Vector2.ZERO, disc.size, 20, accent.lightened(0.2))
	return disc

func _make_pip(position: Vector2, pip_size: int, color: Color):
	var pip = BoardPieceScript.new()
	pip.position = position
	pip.size = Vector2(pip_size, pip_size)
	pip.set_skin(color, BOARD_LINE, 1, "circle")
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pip

func _add_label(node_name: String, text: String, position: Vector2, label_size: Vector2, font_size: int, color: Color, wrap := false) -> Label:
	var label := Label.new()
	var resolved_font_size := _ui_font_size(node_name, font_size)
	label.name = node_name
	label.text = text
	label.position = _snap_vec(position)
	label.size = _snap_vec(label_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if node_name != "Title" and node_name != "TurnLabel" else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.clip_text = true
	if not wrap:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", resolved_font_size)
	_apply_label_outline(label, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_layer.add_child(label)
	return label

func _add_label_to(parent: Control, node_name: String, text: String, position: Vector2, label_size: Vector2, font_size: int, color: Color, wrap := false) -> Label:
	var label := Label.new()
	var resolved_font_size := _ui_font_size(node_name, font_size)
	label.name = node_name
	label.text = text
	label.position = _snap_vec(position)
	label.size = _snap_vec(label_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.clip_text = true
	if not wrap:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", resolved_font_size)
	_apply_label_outline(label, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _ui_font_size(node_name: String, requested_size: int) -> int:
	if _is_micro_label(node_name):
		return maxi(requested_size, MICRO_FONT_MIN)
	if requested_size < BODY_FONT_MIN:
		return BODY_FONT_MIN
	if requested_size <= 17:
		return requested_size + 2
	if requested_size <= 22:
		return requested_size + 1
	return requested_size

func _is_micro_label(node_name: String) -> bool:
	return (
		node_name.begins_with("CostSocketLabel")
		or node_name == "WorkerCount"
		or node_name == "StepName"
		or node_name == "Text"
		or node_name.begins_with("PhaseLabel_")
		or node_name.begins_with("TutorialBadgeText")
	)

func _snap_vec(value: Vector2) -> Vector2:
	return Vector2(roundf(value.x), roundf(value.y))

func _apply_label_outline(label: Label, color: Color) -> void:
	var luma := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	if luma < 0.35:
		return
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.82))
	label.add_theme_constant_override("outline_size", 2)

func _set_label(node_name: String, text: String) -> void:
	var label: Label = board_layer.find_child(node_name, true, false)
	if label != null:
		label.text = text

func _set_label_in(parent: Node, node_name: String, text: String) -> void:
	var label: Label = parent.find_child(node_name, true, false)
	if label != null:
		label.text = text

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _animate_card_to_slot(country_index: int, card: Dictionary, from_pos: Vector2, to_pos: Vector2) -> void:
	var slot: Control = country_policy_slots[country_index]
	_bump(slot)

func _animate_token_to_seat(token_name: String, from_pos: Vector2, to_pos: Vector2, tint: Color) -> void:
	var ghost = _make_piece("WorkerGhost", from_pos, Vector2(46, 46), Color(0.045, 0.035, 0.025, 0.82), tint, 2, "circle")
	ghost.add_child(_make_icon(token_name, Vector2(4, 4), Vector2(38, 38), tint.lightened(0.12)))
	_animate_trail(from_pos + Vector2(23, 23), to_pos + Vector2(23, 23), tint, 0.24)
	_animate_move_and_fade(ghost, to_pos, 0.24)

func _animate_phase_marker(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= phase_pips.size() or to_index < 0 or to_index >= phase_pips.size():
		return
	var from_pip = phase_pips[from_index]
	var to_pip = phase_pips[to_index]
	var ghost = _make_piece("PhaseGhost", from_pip.position + Vector2(7, -5), Vector2(22, 22), WARN, BOARD_LINE, 2, "circle")
	_animate_trail(from_pip.position + Vector2(18, 3), to_pip.position + Vector2(18, 3), WARN, 0.22)
	_animate_move_and_fade(ghost, to_pip.position + Vector2(7, -5), 0.22)

func _animate_country_marker(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= country_seats.size() or to_index < 0 or to_index >= country_seats.size():
		return
	var from_seat = country_seats[from_index]
	var to_seat = country_seats[to_index]
	var accent: Color = COUNTRY_ACCENTS[to_index]
	var ghost = _make_piece("CountryFocusGhost", from_seat.position + Vector2(6, 10), Vector2(46, 46), Color(0.02, 0.022, 0.020, 0.50), accent, 2, "circle")
	_add_label_to(ghost, "CountryFocusLetter", UiCatalogScript.country_emblem(to_index), Vector2.ZERO, Vector2(46, 46), 20, accent.lightened(0.25))
	_animate_trail(from_seat.position + Vector2(28, 34), to_seat.position + Vector2(28, 34), accent, 0.24)
	_animate_move_and_fade(ghost, to_seat.position + Vector2(6, 10), 0.24)

func _animate_trail(from_pos: Vector2, to_pos: Vector2, color: Color, duration: float) -> void:
	var trail = BoardTrailScript.new()
	trail.name = "BoardTrail"
	board_layer.add_child(trail)
	trail.set_path(from_pos, to_pos, color)
	trail.z_index = 30
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(trail, "progress", 1.0, duration)
	tween.tween_callback(trail.queue_redraw)
	tween.tween_property(trail, "modulate:a", 0.0, 0.12)
	tween.tween_callback(trail.queue_free)

func _animate_policy_menu_deal(node: Control, source: Vector2, final_pos: Vector2, delay: float) -> void:
	node.position = source
	node.scale = Vector2(0.72, 0.72)
	node.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_interval(delay)
	tween.tween_property(node, "position", final_pos, 0.22)
	tween.parallel().tween_property(node, "scale", Vector2.ONE, 0.18)
	tween.parallel().tween_property(node, "modulate:a", 1.0, 0.10)

func _animate_move_and_fade(node: Control, to_pos: Vector2, duration: float) -> void:
	node.z_index = 40
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", to_pos, duration)
	tween.parallel().tween_property(node, "scale", Vector2(1.08, 1.08), duration * 0.55)
	tween.tween_property(node, "modulate:a", 0.0, 0.14)
	tween.tween_callback(node.queue_free)

func _animate_drop(node: Control, delay: float) -> void:
	var final_pos := node.position
	node.position = final_pos + Vector2(0, 18)
	node.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_interval(delay)
	tween.tween_property(node, "position", final_pos, 0.18)
	tween.parallel().tween_property(node, "modulate:a", 1.0, 0.12)

func _bump(node: Control) -> void:
	var original := node.scale
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", original * 1.035, 0.08)
	tween.tween_property(node, "scale", original, 0.12)

func _screen() -> Vector2:
	if size.x > 0 and size.y > 0:
		return size
	return get_viewport_rect().size

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
	return names.get(key, key)

func _world_value_label(key: String, value: int) -> String:
	if ["world_demand", "world_interest_rate"].has(key):
		return "%+d" % value
	if key == "depression":
		return "%d/10" % value
	return str(value)

func _world_track_meaning(key: String, value: int) -> String:
	match key:
		"world_demand":
			return "世界需要が%s" % ("強い" if value > 0 else ("弱い" if value < 0 else "中立"))
		"world_interest_rate":
			return "外貨債務国に%s" % ("逆風" if value > 0 else ("追い風" if value < 0 else "中立"))
		"trade_openness":
			return "貿易路の開き %d" % value
		"international_financial_instability":
			return "危機伝染 %d" % value
		"depression":
			return "10で全員敗北"
		"protectionism":
			return "関税連鎖 %d" % value
		"global_coordination":
			return "協調余地 %d" % value
	return ""

func _welfare_total_for_score(score: Dictionary) -> int:
	return int(score.get("welfare_score", 0))

func _influence_for_score(score: Dictionary) -> int:
	return int(score.get("influence", 0))

func _gdp_history_for_score(score: Dictionary) -> String:
	var country = _country_for_score(score)
	if country == null:
		return "-"
	var values := []
	for snapshot in country.track_history:
		values.append(int(snapshot.get("gdp_gap", 0)))
	if values.is_empty():
		values.append(int(country.tracks.get("gdp_gap", 0)))
	return _sparkline(values)

func _country_for_score(score: Dictionary):
	var country_id := String(score.get("country_id", ""))
	for country in game.countries:
		if country.country_id == country_id:
			return country
	return null

func _sparkline(values: Array) -> String:
	var chars := ["_", "-", "=", "+", "#"]
	var text := ""
	for value in values:
		var index := clampi(int(value) + 2, 0, chars.size() - 1)
		text += chars[index]
	return text.substr(maxi(0, text.length() - 10), 10)

func _election_status(country) -> String:
	if country.is_election_turn(game.turn):
		return "当"
	if country.is_election_eve(game.turn):
		return "前"
	var next_turn := int(country.election_turn)
	while next_turn < game.turn:
		next_turn += int(country.election_period)
	return "あと%d" % maxi(0, next_turn - game.turn)

func _resolution_items() -> Array:
	if not last_resolution_snapshot.is_empty():
		return last_resolution_snapshot.get("items", [])
	if not resolution_review_active and not game.revealed_policies:
		return []
	return _capture_resolution_snapshot().get("items", [])

func _capture_resolution_snapshot() -> Dictionary:
	var outcome: Dictionary = game.preview_resolution_outcome()
	for item_value in outcome.get("items", []):
		var item: Dictionary = item_value
		var policy: Dictionary = item.get("policy", {})
		item["country"] = "%s国" % UiCatalogScript.country_emblem(int(item.get("country_index", 0)))
		item["policy_name"] = UiCatalogScript.short_card_name(policy)
	return outcome

func _diff_count(diffs: Dictionary) -> int:
	var count := 0
	for value in diffs.values():
		if value is Dictionary:
			count += _as_dict(value).size()
		else:
			count += 1
	return count

func _as_dict(value) -> Dictionary:
	return value if value is Dictionary else {}

func _policy_satisfies_pressure(country, policy: Dictionary) -> bool:
	var pressure: Dictionary = country.domestic_pressure
	var preferred: Array = pressure.get("demand", {}).get("preferred_policy_tags", [])
	for tag in preferred:
		if PolicyRecommenderScript.has_tag(policy, String(tag)):
			return true
	return false

func _mutation_count(policy: Dictionary) -> int:
	var mutations: Dictionary = policy.get("mutations", {})
	var count := 0
	count += mutations.get("add_to_deck", []).size()
	count += mutations.get("remove_from_deck", []).size()
	count += mutations.get("add_to_policy_catalog", []).size()
	count += mutations.get("remove_from_policy_catalog", []).size()
	count += mutations.get("replace_in_policy_catalog", []).size()
	if not String(mutations.get("add_world_card", "")).is_empty():
		count += 1
	return count

func _phase_short_name(key: String) -> String:
	var names := {
		"world_event": "世界",
		"domestic_update": "国内",
		"negotiation": "交渉",
		"policy_planning": "計画",
		"worker_assignment": "配置",
		"simultaneous_reveal": "公開",
		"resolution": "解決"
	}
	return names.get(key, key)

func _resolution_step_name(index: int) -> String:
	var names := ["国内圧力", "コスト", "国内効果", "世界波及", "デッキ変質", "マクロ合成"]
	if index < 0 or index >= names.size():
		return "解決処理"
	return names[index]

func _resolution_step_help(index: int) -> String:
	var helps := [
		"国内圧力に応えたか確認。満たせない公約は政治資本を削る。",
		"政策コストと国家能力を照合。不足は補助金混入・延期・骨抜きへ。",
		"GDP・物価・失業・金融ストレスなど、自国への直接効果。",
		"世界需要・保護主義・金融不安など、共有ボードへの波及。",
		"状態デッキと政策カタログの変質。国家の歴史がここに残る。",
		"貿易・期待・利払い・資本移動・デフレスパイラルを合成。"
	]
	if index < 0 or index >= helps.size():
		return "上から順に、政策が国内・世界・デッキ・マクロ動学へ及ぼす結果を確認します。"
	return helps[index]

func _agenda_display_name(tag: String) -> String:
	for item in AGENDA:
		if String(item.get("tag", "")) == tag:
			return String(item.get("name", tag))
	return tag

func _next_country_without_agenda(after_index: int) -> int:
	if game == null or game.countries.is_empty():
		return -1
	for offset in range(1, game.countries.size() + 1):
		var index: int = int((after_index + offset) % game.countries.size())
		if String(game.countries[index].declared_agenda).is_empty():
			return index
	return -1

func _countries_without_agenda_count() -> int:
	if game == null:
		return 0
	var count := 0
	for country in game.countries:
		if String(country.declared_agenda).is_empty():
			count += 1
	return count

func _news_headlines(log_entries: Array) -> String:
	var headlines := []
	for i in range(log_entries.size() - 1, -1, -1):
		var line := String(log_entries[i]).strip_edges()
		if line.is_empty() or line.begins_with("----") or line.begins_with("フェーズ:"):
			continue
		if line.begins_with("新しいゲーム"):
			continue
		var headline := _short_news_line(line)
		if headlines.has(headline):
			continue
		headlines.append(headline)
		if headlines.size() >= 3:
			break
	headlines.reverse()
	if headlines.is_empty():
		headlines.append("世界情勢カードを待機")
	var text := ""
	for headline in headlines:
		text += "・%s\n\n" % headline
	return text.strip_edges()

func _latest_news_summary() -> String:
	if game == null or game.log.is_empty():
		return "未読"
	for i in range(game.log.size() - 1, -1, -1):
		var line := String(game.log[i]).strip_edges()
		if line.is_empty() or line.begins_with("----") or line.begins_with("フェーズ:") or line.begins_with("新しいゲーム"):
			continue
		return _short_news_line(line)
	return "未読"

func _short_news_line(line: String) -> String:
	var cleaned := line.replace("世界イベント「", "").replace("」: ", "：")
	cleaned = cleaned.replace("しました。", "。").replace("されています。", "。")
	if cleaned.length() > 42:
		return cleaned.substr(0, 41) + "…"
	return cleaned

func _ellipsize(text: String, max_chars: int) -> String:
	if max_chars <= 0 or text.length() <= max_chars:
		return text
	return text.substr(0, maxi(1, max_chars - 1)) + "…"

func _latest_log_world_track() -> String:
	var mapping := {
		"世界需要": "world_demand",
		"需要": "world_demand",
		"金利": "world_interest_rate",
		"貿易": "trade_openness",
		"輸出": "trade_openness",
		"金融": "international_financial_instability",
		"信用": "international_financial_instability",
		"恐慌": "depression",
		"保護": "protectionism",
		"協調": "global_coordination"
	}
	for i in range(game.log.size() - 1, -1, -1):
		var line := String(game.log[i])
		for key in mapping.keys():
			if line.contains(String(key)):
				return String(mapping[key])
	return ""

func _pressure_summary(country) -> String:
	var pressure: Dictionary = country.domestic_pressure
	if pressure.is_empty():
		return "国内圧力\nなし"
	var tags: Array = pressure.get("demand", {}).get("preferred_policy_tags", [])
	var preferred := _short_tag_list(tags, 1)
	return "%s\n求:%s" % [
		_ellipsize(String(pressure.get("display_name", "国内圧力")), 7),
		preferred if not preferred.is_empty() else "不明"
	]

func _policy_slot_summary(country) -> String:
	if country.selected_policy.is_empty():
		return "未提出"
	if game.revealed_policies or resolution_review_active or game.current_phase() == "resolution" or game.is_finished:
		return "%s%s" % [UiCatalogScript.short_card_name(country.selected_policy), _target_summary(country)]
	return "伏せ札"

func _target_summary(country) -> String:
	if String(country.selected_policy.get("target", "")) != "country":
		return ""
	var target_index := int(country.selected_target_index)
	if target_index < 0 or target_index >= game.countries.size():
		return " →未定"
	return " →%s国" % UiCatalogScript.country_emblem(target_index)

func _target_effect_preview(country) -> String:
	var target := _target_summary(country).strip_edges()
	var effects: Dictionary = country.selected_policy.get("effects", {})
	var donor := _short_effect_scope(effects.get("donor", {}))
	var recipient := _short_effect_scope(effects.get("recipient", {}))
	return "%s 供:%s / 受:%s" % [
		target if not target.is_empty() else "→未定",
		donor if not donor.is_empty() else "-",
		recipient if not recipient.is_empty() else "-"
	]

func _short_effect_scope(effects: Dictionary) -> String:
	var parts := []
	for key in effects.keys():
		parts.append("%s%s" % [_track_chip_prefix(String(key), String(key).substr(0, 1)), _signed_delta(int(effects[key]))])
		if parts.size() >= 2:
			break
	return " ".join(parts)

func _selected_policy_target_index() -> int:
	if selected_country_index < 0 or selected_country_index >= game.countries.size():
		return -1
	var country = game.countries[selected_country_index]
	if String(country.selected_policy.get("target", "")) != "country":
		return -1
	return int(country.selected_target_index)

func _short_tag_list(tags: Array, limit: int) -> String:
	var names := {
		"fiscal": "財政",
		"demand": "需要",
		"cooperation": "協調",
		"austerity": "緊縮",
		"monetary": "金融",
		"rate_hike": "利上げ",
		"credibility": "信認",
		"qe": "流動性",
		"currency_depreciation": "通貨安",
		"trade": "通商",
		"tariff": "関税",
		"industrial": "産業",
		"investment": "投資",
		"employment": "雇用",
		"financial_regulation": "規制",
		"stability": "安定",
		"international": "国際",
		"reform": "改革",
		"growth": "成長",
		"infrastructure": "インフラ",
		"resource": "資源",
		"export_subsidy": "輸出補助",
		"social_policy": "社会保障",
		"fund": "基金",
		"beggar_thy_neighbor": "近隣窮乏",
		"consumption": "消費",
		"housing": "住宅",
		"banking": "銀行",
		"capital_control": "資本規制",
		"swap_line": "スワップ",
		"debt_restructuring": "債務再編"
	}
	var parts := []
	for i in range(mini(limit, tags.size())):
		parts.append(names.get(String(tags[i]), String(tags[i])))
	return " / ".join(parts)

func _worker_short_label(worker: String) -> String:
	var names := {
		"bureaucrats": "官僚",
		"central_bank_staff": "中銀",
		"diplomat": "外交",
		"auditor": "監査",
		"lobbyist": "ロビ"
	}
	return names.get(worker, worker.substr(0, 2))

func _worker_role_label(worker: String) -> String:
	var labels := {
		"bureaucrats": "行政 -1",
		"central_bank_staff": "信認 -1",
		"diplomat": "国際 -1",
		"auditor": "汚職抑制",
		"lobbyist": "政治 -2"
	}
	return labels.get(worker, UiCatalogScript.worker_tip(worker).substr(0, 8))

func _worker_hint_label(worker: String) -> String:
	var labels := {
		"bureaucrats": "行政コストを下げる",
		"central_bank_staff": "信認コストを下げる",
		"diplomat": "国際コストを下げる",
		"auditor": "汚職・レントを抑制",
		"lobbyist": "政治を通す / 利権追加"
	}
	return labels.get(worker, UiCatalogScript.worker_tip(worker))

func _country_risk_words(country) -> String:
	var risks := []
	if int(country.tracks.get("gdp_gap", 0)) <= -3:
		risks.append("需要低迷")
	if int(country.tracks.get("inflation", 0)) >= 5:
		risks.append("物価高")
	if int(country.tracks.get("unemployment", 0)) >= 5:
		risks.append("失業")
	if int(country.tracks.get("debt", 0)) >= 6:
		risks.append("債務")
	if int(country.tracks.get("financial_stress", 0)) >= 5:
		risks.append("金融不安")
	if int(country.tracks.get("political_capital", 0)) <= 2:
		risks.append("政治余力低下")
	if risks.is_empty():
		return "安定圏"
	return " / ".join(risks.slice(0, 3))

func _refresh_country_risk_chips(country_index: int, country) -> void:
	var rack: Control = country_chip_racks[country_index]
	_clear_children(rack)
	var chip_defs := [
		{"key": "unemployment", "label": "失"},
		{"key": "debt", "label": "債"},
		{"key": "financial_stress", "label": "融"},
		{"key": "political_capital", "label": "政"}
	]
	var chip_gap := 6.0
	var chip_w := (rack.size.x - chip_gap * float(chip_defs.size() - 1)) / float(chip_defs.size())
	for i in range(chip_defs.size()):
		var def: Dictionary = chip_defs[i]
		var value := int(country.tracks.get(def["key"], 0))
		var key := String(def["key"])
		var color: Color = BAD if value >= 5 and key != "political_capital" else COUNTRY_ACCENTS[country_index]
		if key == "political_capital" and value <= 2:
			color = WARN
		var chip = BoardPieceScript.new()
		chip.position = Vector2((chip_w + chip_gap) * i, 0)
		chip.size = Vector2(chip_w, rack.size.y)
		chip.set_skin(Color(0.026, 0.022, 0.018, 0.86), color, 1, "plaque")
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.name = "RiskChipLabel"
		label.text = "%s%d" % [String(def["label"]), value]
		label.position = Vector2.ZERO
		label.size = chip.size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_color_override("font_color", color.lightened(0.26))
		label.add_theme_font_size_override("font_size", 14)
		_apply_label_outline(label, color.lightened(0.26))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(label)
		chip.tooltip_text = "%s %d" % [def["label"], value]
		rack.add_child(chip)

func _track_colors() -> Dictionary:
	return {
		"good": GOOD,
		"warn": WARN,
		"bad": BAD,
		"blue": BLUE
	}
