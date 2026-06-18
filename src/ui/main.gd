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
	{"name": "協調刺激", "tag": "cooperation", "icon": "協"},
	{"name": "流動性", "tag": "liquidity", "icon": "流"},
	{"name": "関税凍結", "tag": "trade", "icon": "関"},
	{"name": "債務再編", "tag": "debt", "icon": "債"}
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
var hand_nodes: Array = []
var hand_coin_nodes: Array = []
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
	_hide_entry_overlays()
	game.move_to_phase("policy_planning")
	selected_country_index = 0
	if preview_state == "policy_submitted":
		var policy_index := _preview_first_policy_index(game.countries[0].policy_menu)
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
		var policy_index := _preview_first_policy_index(game.countries[country_index].policy_menu)
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
	_build_collapse_warning()
	_build_agenda_tiles()
	_build_country_seats()
	_build_policy_slot()
	_build_resolution_flow()
	_build_hand_slots()
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
	var hand = _make_piece("HandPanel", board_layout["hand_panel_pos"], board_layout["hand_panel_size"], Color(0.070, 0.050, 0.030, 0.94), BOARD_LINE, 2, "plaque")
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var menu_title := _add_label_to(hand, "PolicyMenuTitle", "政策メニュー（常設・デッキではない）", Vector2(16, 4), Vector2(260, 16), 12, WARN.lightened(0.18), false)
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _build_table_marks() -> void:
	_add_label("Title", "マクロノミカ", board_layout["title_pos"], board_layout["title_size"], 36, TEXT)
	_add_label("TurnLabel", "", board_layout["turn_pos"], board_layout["turn_size"], 17, TEXT)
	phase_pips.clear()
	var phase_start: Vector2 = board_layout["phase_pip_start"]
	var phase_step: Vector2 = board_layout["phase_pip_step"]
	for i in range(GameStateScript.PHASES.size()):
		var pip = _make_piece("PhasePip_%d" % i, phase_start + phase_step * i, board_layout["phase_pip_size"], Color(0.04, 0.035, 0.026, 0.55), BOARD_LINE)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_add_label("PhaseLabel_%d" % i, _phase_short_name(String(GameStateScript.PHASES[i])), phase_start + phase_step * i + Vector2(-8, 18), Vector2(58, 16), 10, MUTED)
		phase_pips.append(pip)
	var command_origin: Vector2 = board_layout["command_origin"]
	_add_action_token("RestartToken", "↺", command_origin + Vector2(12, 12), Vector2(48, 48), _on_restart_pressed)
	var recommend = _add_action_token("RecommendToken", "助", command_origin + Vector2(82, 18), Vector2(36, 36), _on_recommend_pressed)
	recommend.tooltip_text = "推奨（テスト補助）"
	_add_action_token("AdvanceToken", "次", command_origin + Vector2(150, 0), Vector2(68, 68), _on_advance_pressed)

func _build_event_card() -> void:
	var card = _make_piece("EventCard", board_layout["event_pos"], board_layout["event_size"], Color(0.13, 0.085, 0.040, 0.94), WARN, 2, "card")
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_make_icon("world_demand_globe", Vector2(14, 46), Vector2(50, 50), WARN))
	_add_label_to(card, "EventCaption", "公開イベント", Vector2(0, 10), Vector2(card.size.x, 20), 13, WARN.lightened(0.2))
	_add_label_to(card, "EventTitle", "", Vector2(68, 34), Vector2(card.size.x - 78, 34), 17, TEXT, true)
	_add_label_to(card, "EventMessage", "", Vector2(68, 70), Vector2(card.size.x - 78, 38), 11, TEXT, true)
	_add_label_to(card, "EventDeck", "", Vector2(68, 108), Vector2(card.size.x - 78, 18), 11, TEXT)

func _build_world_tracks() -> void:
	var panel = _make_piece("WorldPanel", board_layout["world_panel_pos"], board_layout["world_panel_size"], Color(0.030, 0.035, 0.034, 0.70), BLUE.lightened(0.05), 2, "plaque")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(panel, "WorldPanelTitle", "世界危機ボード", Vector2(0, 10), Vector2(panel.size.x, 24), 18, WARN.lightened(0.18))
	_add_label_to(panel, "WorldPanelHint", "政策の波及先", Vector2(0, panel.size.y - 26), Vector2(panel.size.x, 18), 11, MUTED)
	var start: Vector2 = board_layout["world_tracks_origin"]
	var step: Vector2 = board_layout["world_track_step"]
	for i in range(WORLD_TRACKS.size()):
		var key: String = WORLD_TRACKS[i]
		var tile_pos := start + Vector2(step.x * i, 0)
		var tile = _make_piece("WorldTrack_%s" % key, tile_pos, board_layout["world_track_size"], Color(0.020, 0.019, 0.016, 0.72), BLUE, 1, "card")
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_size: float = minf(68.0, tile.size.y - 40.0)
		tile.add_child(_make_icon(UiCatalogScript.track_token(key), Vector2(tile.size.x * 0.5 - icon_size * 0.5, 8), Vector2(icon_size, icon_size), Color.WHITE, "TrackIcon"))
		var label_y: float = icon_size + 14.0
		var label := _add_label_to(tile, "TrackLabel", _world_short_name(key), Vector2(6, label_y), Vector2(tile.size.x - 12, 22), 14, TEXT, true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var rail := Control.new()
		rail.name = "TrackRail"
		rail.position = Vector2(tile.size.x * 0.5 - 43, tile.size.y - 19)
		rail.size = Vector2(86, 13)
		tile.add_child(rail)

func _build_agenda_tiles() -> void:
	var negotiation = _make_piece("NegotiationPanel", board_layout["negotiation_pos"], board_layout["negotiation_size"], Color(0.060, 0.042, 0.026, 0.72), BOARD_LINE, 2, "plaque")
	negotiation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(negotiation, "NegotiationTitle", "国際交渉", Vector2(0, 6), Vector2(negotiation.size.x, 18), 13, WARN.lightened(0.16))
	var start: Vector2 = board_layout["agenda_origin"]
	var step: Vector2 = board_layout["agenda_step"]
	for i in range(AGENDA.size()):
		var item: Dictionary = AGENDA[i]
		var tile = _make_piece("Agenda_%s" % item["tag"], start + step * i, board_layout["agenda_size"], Color(0.15, 0.105, 0.055, 0.92), BOARD_LINE, 2, "card")
		tile.tooltip_text = "選択中の国が共同宣言を置きます。"
		tile.pressed = func(tag := String(item["tag"])) -> void:
			_on_agenda_declared(tag)
		_add_label_to(tile, "AgendaIcon", String(item["icon"]), Vector2(0, 5), Vector2(tile.size.x, 25), 22, WARN.lightened(0.05))
		_add_label_to(tile, "AgendaName", String(item["name"]), Vector2(0, 31), Vector2(tile.size.x, 22), 13, TEXT)
		var pips := Control.new()
		pips.name = "AgendaPips"
		pips.position = Vector2(24, 57)
		pips.size = Vector2(70, 8)
		tile.add_child(pips)

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
		var title := _add_label_to(seat, "CountryTitle", "%s国" % UiCatalogScript.country_emblem(i), Vector2(14, 8), Vector2(48, 26), 24, accent.lightened(0.22))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var subtitle := _add_label_to(seat, "CountryType", country.display_name.substr(3, 18), Vector2(62, 10), Vector2(seat_size.x - 76, 20), 12, MUTED)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

		var pressure = _make_child_piece(seat, "PressureCard", Vector2(14, 36), Vector2(seat_size.x * 0.42, seat_size.y - 50), Color(0.86, 0.76, 0.55, 0.96), accent, 1, "card")
		var pressure_label := _add_label_to(pressure, "PressureLabel", "", Vector2(9, 7), pressure.size - Vector2(18, 14), 12, INK, true)
		pressure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		country_pressure_labels.append(pressure_label)

		var state_card = _make_child_piece(seat, "StateHandCard", Vector2(seat_size.x * 0.47, 36), Vector2(seat_size.x * 0.29, 54), Color(0.16, 0.13, 0.10, 0.96), BAD.darkened(0.08), 2, "card")
		var state_label := _add_label_to(state_card, "StateHandLabel", "", Vector2(7, 5), state_card.size - Vector2(14, 10), 11, TEXT, true)
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		state_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		country_state_labels.append(state_label)

		var policy = _make_child_piece(seat, "PolicySlot", Vector2(seat_size.x * 0.47, 94), Vector2(seat_size.x * 0.29, 30), Color(0.032, 0.038, 0.038, 0.94), accent, 2, "card")
		var policy_icon_size: float = minf(policy.size.x - 12.0, policy.size.y - 26.0)
		if policy_icon_size >= 12.0:
			policy.add_child(_make_icon("coordination_ring", Vector2(5, policy.size.y * 0.5 - policy_icon_size * 0.5), Vector2(policy_icon_size, policy_icon_size), Color(0.75, 0.68, 0.45, 0.86), "PolicyBackIcon"))
		var policy_label := _add_label_to(policy, "PolicyLabel", "", Vector2(8, 4), Vector2(policy.size.x - 16, 22), 11, TEXT, false)
		country_policy_slots.append(policy)
		country_policy_labels.append(policy_label)

		var stamp = _make_child_piece(seat, "StampSlot", Vector2(seat_size.x - 64, 44), Vector2(52, 52), Color(0.020, 0.018, 0.014, 0.68), accent, 1, "circle")
		stamp.add_child(_make_icon("bureaucrat_seal", Vector2.ZERO, stamp.size, Color.WHITE, "WorkerIcon"))
		_add_label_to(stamp, "WorkerCount", "", Vector2(29, 30), Vector2(18, 16), 10, WARN.lightened(0.18))
		country_stamp_slots.append(stamp)
		country_worker_icons.append(stamp.get_node("WorkerIcon"))

		var info_y := seat_size.y - 21.0
		var next_label := _add_label_to(seat, "NextDeckLabel", "", Vector2(14, info_y), Vector2(seat_size.x * 0.34, 16), 10, MUTED, false)
		next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var pipeline_label := _add_label_to(seat, "PipelineLabel", "", Vector2(seat_size.x * 0.37, info_y), Vector2(seat_size.x * 0.23, 16), 10, WARN.lightened(0.16), false)
		pipeline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var election_label := _add_label_to(seat, "ElectionLabel", "", Vector2(seat_size.x * 0.60, info_y), Vector2(seat_size.x * 0.18, 16), 10, MUTED, false)
		election_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var welfare_label := _add_label_to(seat, "WelfareLabel", "", Vector2(seat_size.x * 0.78, info_y), Vector2(seat_size.x * 0.18, 16), 10, MUTED, false)
		welfare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		country_next_labels.append(next_label)
		country_pipeline_labels.append(pipeline_label)
		country_election_labels.append(election_label)
		country_welfare_labels.append(welfare_label)

		var chips := Control.new()
		chips.name = "RiskChips"
		chips.position = Vector2(68, seat_size.y - 17)
		chips.size = Vector2(seat_size.x * 0.30, 12)
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seat.add_child(chips)
		country_chip_racks.append(chips)
		country_seats.append(seat)

func _build_policy_slot() -> void:
	policy_slot = _make_piece("PolicySlot", board_layout["policy_slot_pos"], board_layout["policy_slot_size"], Color(0.050, 0.036, 0.024, 0.84), BOARD_LINE, 2, "card")
	policy_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot_size: Vector2 = board_layout["policy_slot_size"]
	_add_label_to(policy_slot, "PolicySlotTitle", "同時公開卓", Vector2(0, 8), Vector2(slot_size.x, 22), 15, WARN.lightened(0.18))
	policy_slot_label = _add_label_to(policy_slot, "PolicySlotLabel", "", Vector2(14, 30), Vector2(slot_size.x - 28, 28), 13, TEXT, true)
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
	var panel = _make_piece("ResolutionFlow", flow_pos, flow_size, Color(0.055, 0.040, 0.026, 0.68), BOARD_LINE, 1, "plaque")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(panel, "ResolutionFlowTitle", "解決処理", Vector2(10, 6), Vector2(68, 18), 12, WARN.lightened(0.18))
	var names := ["圧力", "コスト", "国内", "世界", "デッキ", "合成"]
	var step_w := (flow_size.x - 94.0) / float(names.size())
	for i in range(names.size()):
		var step = _make_child_piece(panel, "ResolutionStep_%d" % i, Vector2(82 + step_w * i, 8), Vector2(step_w - 8, 48), Color(0.030, 0.026, 0.020, 0.76), BOARD_LINE.darkened(0.18), 1, "card")
		_add_label_to(step, "StepName", names[i], Vector2(0, 4), Vector2(step.size.x, 16), 11, MUTED)
		var label := _add_label_to(step, "StepValue", "-", Vector2(4, 22), Vector2(step.size.x - 8, 20), 12, TEXT, true)
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
	var news = _make_child_piece(final_score_panel, "FinalNews", Vector2(22, 326), Vector2(panel_size.x - 44, 122), Color(0.80, 0.69, 0.49, 0.94), BOARD_LINE, 2, "card")
	_add_label_to(news, "FinalNewsTitle", "世界経済新聞 総括", Vector2(0, 8), Vector2(news.size.x, 20), 15, INK)
	final_news_label = _add_label_to(news, "FinalNewsText", "", Vector2(18, 34), Vector2(news.size.x - 36, 72), 13, INK, true)
	final_news_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	final_news_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var restart = _make_entry_button(final_score_panel, "FinalRestartButton", "↺  再戦", Vector2(panel_size.x - 128, panel_size.y - 48), Vector2(100, 34), _on_restart_pressed)
	restart.set_skin(Color(0.060, 0.044, 0.028, 0.94), BOARD_LINE, 2, "card")
	final_score_panel.visible = false

func _build_turn_news_overlay() -> void:
	var screen := _screen()
	var panel_size := Vector2(minf(screen.x - 220.0, 620.0), 220.0)
	var panel_pos := Vector2((screen.x - panel_size.x) * 0.5, screen.y - panel_size.y - 190.0)
	turn_news_panel = _make_piece("TurnNewsOverlay", panel_pos, panel_size, Color(0.80, 0.69, 0.49, 0.96), BOARD_LINE, 2, "card")
	turn_news_panel.z_index = 56
	turn_news_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_label_to(turn_news_panel, "TurnNewsTitle", "世界経済新聞", Vector2(0, 18), Vector2(panel_size.x, 28), 22, INK)
	turn_news_label = _add_label_to(turn_news_panel, "TurnNewsText", "", Vector2(28, 62), Vector2(panel_size.x - 56, 122), 15, INK, true)
	turn_news_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	turn_news_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var next = _make_entry_button(turn_news_panel, "TurnNewsNext", "次ターンへ", Vector2(panel_size.x - 154, panel_size.y - 54), Vector2(124, 36), _hide_turn_news_overlay)
	next.set_skin(Color(0.060, 0.044, 0.028, 0.94), BOARD_LINE, 2, "card")
	turn_news_panel.visible = false

func _build_entry_overlays() -> void:
	_build_title_overlay()
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
	var memo = _make_child_piece(panel, "TitleMemo", Vector2(46, 156), Vector2(panel_size.x - 92, 104), Color(0.80, 0.69, 0.49, 0.94), BOARD_LINE, 2, "card")
	_add_label_to(memo, "TitleMemoText", "カード・担当印・世界トラックを卓上で読み、10ターン後のレガシー目標を競います。", Vector2(22, 18), Vector2(memo.size.x - 44, 68), 18, INK, true)
	var start = _make_entry_button(title_overlay, "TitleStart", "開始", panel_pos + Vector2(panel_size.x * 0.5 - 102, panel_size.y - 112), Vector2(204, 62), _show_country_select)
	_add_label_to(start, "StartHint", "国家を選ぶ", Vector2(0, 38), Vector2(start.size.x, 18), 11, MUTED)
	var continue_token = _make_overlay_piece(title_overlay, "TitleContinue", panel_pos + Vector2(panel_size.x * 0.5 - 206, panel_size.y - 42), Vector2(160, 34), Color(0.024, 0.022, 0.020, 0.72), BOARD_LINE.darkened(0.42), 1, "card")
	continue_token.modulate = Color(1, 1, 1, 0.58)
	_add_label_to(continue_token, "ContinueText", "続きから（準備中）", Vector2.ZERO, continue_token.size, 13, MUTED)
	var settings_token = _make_overlay_piece(title_overlay, "TitleSettings", panel_pos + Vector2(panel_size.x * 0.5 + 46, panel_size.y - 42), Vector2(160, 34), Color(0.024, 0.022, 0.020, 0.72), BOARD_LINE.darkened(0.42), 1, "card")
	settings_token.modulate = Color(1, 1, 1, 0.58)
	_add_label_to(settings_token, "SettingsText", "設定（準備中）", Vector2.ZERO, settings_token.size, 13, MUTED)

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
	if country_select_overlay != null:
		country_select_overlay.visible = entry_state == "country_select"

func _show_title_overlay() -> void:
	entry_state = "title"
	_apply_entry_state()

func _show_country_select() -> void:
	entry_state = "country_select"
	_apply_entry_state()

func _hide_entry_overlays() -> void:
	entry_state = "hidden"
	_apply_entry_state()

func _show_turn_news_overlay() -> void:
	if turn_news_panel == null:
		return
	turn_news_active = true
	turn_news_panel.visible = true
	if turn_news_label != null:
		turn_news_label.text = _turn_news_text()
	_bump(turn_news_panel)

func _hide_turn_news_overlay() -> void:
	turn_news_active = false
	if turn_news_panel != null:
		turn_news_panel.visible = false

func _select_start_country(country_index: int) -> void:
	player_country_index = country_index
	selected_country_index = country_index
	_hide_entry_overlays()
	_refresh_board(true)
	if country_index >= 0 and country_index < country_seats.size():
		_bump(country_seats[country_index])

func _build_hand_slots() -> void:
	var card_size: Vector2 = board_layout["hand_card_size"]
	for i in range(20):
		var slot = _make_piece("HandSlot_%d" % i, _policy_menu_position(i), card_size, Color(0.025, 0.020, 0.016, 0.72), BOARD_LINE.darkened(0.10), 1, "card")
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_status_panels() -> void:
	var score_pos: Vector2 = board_layout["score_pos"]
	var score_size: Vector2 = board_layout["score_size"]
	var score = _make_piece("ScorePanel", score_pos, score_size, Color(0.060, 0.044, 0.026, 0.94), BOARD_LINE, 1, "plaque")
	score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(score, "ScoreTitle", "威信", Vector2(8, 1), Vector2(40, 18), 13, WARN.lightened(0.18))
	score_panel = _add_label_to(score, "ScoreComponent", "", Vector2(52, 1), Vector2(score_size.x - 60, 18), 13, TEXT)
	score_panel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var log_pos: Vector2 = board_layout["log_pos"]
	var log_size: Vector2 = board_layout["log_size"]
	var log = _make_piece("LogPanel", log_pos, log_size, Color(0.78, 0.66, 0.45, 0.96), BOARD_LINE, 2, "card")
	log.tooltip_text = "クリックで最新ニュースに関係する世界トラックを強調"
	log.pressed = _on_log_panel_pressed
	_add_label_to(log, "LogTitle", "世界経済新聞", Vector2(0, 8), Vector2(log_size.x, 20), 14, INK)
	log_panel = Label.new()
	log_panel.name = "LogComponent"
	log_panel.position = Vector2(12, 34)
	log_panel.size = Vector2(log_size.x - 24, log_size.y - 44)
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_panel.add_theme_color_override("default_color", INK)
	log_panel.add_theme_font_size_override("font_size", 14)
	log_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_panel.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	log.add_child(log_panel)

func _build_country_detail_panel() -> void:
	var detail_pos: Vector2 = board_layout["country_detail_pos"]
	var detail_size: Vector2 = board_layout["country_detail_size"]
	var panel = _make_piece("CountryDetailPanel", detail_pos, detail_size, Color(0.060, 0.044, 0.028, 0.95), BOARD_LINE, 1, "card")
	panel.tooltip_text = "クリックで対応任務の対象を切替"
	panel.pressed = _on_country_detail_pressed
	_add_label_to(panel, "CountryDetailTitle", "国勢メモ", Vector2(0, 7), Vector2(detail_size.x, 22), 15, WARN.lightened(0.18))
	country_detail_label = _add_label_to(panel, "CountryDetailLabel", "", Vector2(14, 32), Vector2(detail_size.x - 28, detail_size.y - 36), 14, TEXT, true)
	country_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	country_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _build_worker_tokens() -> void:
	worker_nodes.clear()
	var start: Vector2 = board_layout["worker_origin"]
	var step: Vector2 = board_layout["worker_step"]
	var token_size: Vector2 = board_layout["worker_size"]
	for i in range(WORKERS.size()):
		var worker: String = WORKERS[i]
		var token = _make_piece("Worker_%s" % worker, start + step * i, token_size, Color(0, 0, 0, 0.04), BOARD_LINE, 1, "circle")
		token.tooltip_text = UiCatalogScript.worker_name(worker)
		token.pressed = func(worker_id := worker) -> void:
			if game.can_assign_worker():
				_on_worker_assigned(selected_country_index, worker_id, token.position)
		token.add_child(_make_icon(UiCatalogScript.worker_token(worker), Vector2(5, 5), token_size - Vector2(10, 10), Color.WHITE))
		worker_nodes[worker] = token

func _rebuild_hand(animate: bool, origin := Vector2.INF) -> void:
	for node in hand_nodes:
		node.queue_free()
	hand_nodes.clear()
	for node in hand_coin_nodes:
		node.queue_free()
	hand_coin_nodes.clear()
	var phase: String = game.current_phase()
	var show_menu: bool = phase == "policy_planning"
	var show_tray: bool = show_menu or phase == "worker_assignment"
	var hand_panel = board_layer.get_node_or_null("HandPanel")
	if hand_panel != null:
		hand_panel.visible = show_tray
		var title: Label = hand_panel.get_node_or_null("PolicyMenuTitle")
		if title != null:
			title.text = "政策メニュー（常設・デッキではない）" if show_menu else "担当ワーカー"
	for i in range(20):
		var slot = board_layer.get_node_or_null("HandSlot_%d" % i)
		if slot != null:
			slot.visible = show_menu
	if not show_menu:
		return
	var country = game.countries[selected_country_index]
	var source := origin
	if source == Vector2.INF and selected_country_index < country_seats.size():
		source = country_seats[selected_country_index].position + Vector2(60, 46)
	for i in range(country.policy_menu.size()):
		var card: Dictionary = country.policy_menu[i]
		var card_node = _make_policy_card(card, i, -1, true)
		var final_pos := _policy_menu_position(i)
		card_node.position = final_pos
		card_node.rotation_degrees = 0.0
		card_node.z_index = 12
		board_layer.add_child(card_node)
		hand_nodes.append(card_node)
		if animate:
			_animate_hand_deal(card_node, source, final_pos, 0.025 * i)

func _policy_menu_position(index: int) -> Vector2:
	var origin: Vector2 = board_layout["hand_origin"]
	var step: Vector2 = board_layout["hand_step"]
	var columns := int(board_layout.get("hand_columns", 10))
	var col := index % columns
	var row := floori(float(index) / float(columns))
	return origin + Vector2(step.x * col, step.y * row)

func _make_policy_card(card: Dictionary, hand_index: int, display_country_index := -1, include_coin := true):
	var country_index := selected_country_index if display_country_index < 0 else display_country_index
	var country = game.countries[country_index]
	var selected: bool = not country.selected_policy.is_empty() and country.selected_policy.get("id", "") == card.get("id", "")
	var face: Color = CARD_FACE if card.get("type", "") == "policy" else Color(0.16, 0.15, 0.12, 1.0)
	var border: Color = COUNTRY_ACCENTS[country_index] if selected else BOARD_LINE
	var card_size: Vector2 = board_layout.get("hand_card_size", Vector2(82, 108))
	var card_node = BoardPieceScript.new()
	card_node.name = "PolicyMenuCard_%d" % hand_index
	card_node.size = card_size
	card_node.set_skin(face, border, 3 if selected else 2, "card")
	card_node.tooltip_text = _plain_card_detail(country, card)
	card_node.pressed = func() -> void:
		if card.get("type", "") == "policy" and game.can_select_policy():
			_on_policy_selected(selected_country_index, hand_index, card_node.position)
	if include_coin:
		var coin_size := minf(card_size.y - 20.0, 32.0)
		var coin_layer := Control.new()
		coin_layer.name = "CardCoinLayer"
		coin_layer.position = _snap_vec(Vector2((card_size.x - coin_size) * 0.5, 3))
		coin_layer.size = _snap_vec(Vector2(coin_size, coin_size))
		coin_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin_layer.z_index = 4
		card_node.add_child(coin_layer)
		coin_layer.add_child(_make_icon(UiCatalogScript.card_token(card), Vector2.ZERO, coin_layer.size, Color.WHITE, "CardCoin"))
	var label_y := 36.0 if include_coin else 5.0
	var label := _add_label_to(card_node, "CardName", UiCatalogScript.short_card_name(card), Vector2(6, label_y), Vector2(card_size.x - 12, card_size.y - label_y - 4), 12, INK if card.get("type", "") == "policy" else TEXT, false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return card_node

func _plain_card_detail(country, card: Dictionary) -> String:
	var text := CardTextFormatterScript.card_detail(country, card)
	for token in ["[b]", "[/b]", "[center]", "[/center]"]:
		text = text.replace(token, "")
	text = text.replace("[color=#9aa0a4]", "").replace("[color=#999999]", "").replace("[/color]", "")
	return text

func _make_hand_card_coin(card: Dictionary, card_position: Vector2, card_size: Vector2) -> TextureRect:
	var coin_size := minf(card_size.x * 0.75, 78.0)
	var coin := _make_icon(
		UiCatalogScript.card_token(card),
		card_position + Vector2((card_size.x - coin_size) * 0.5, 6),
		Vector2(coin_size, coin_size),
		Color.WHITE,
		"HandCardCoin",
		true
	)
	coin.z_index = 13
	return coin

func _refresh_board(animate: bool) -> void:
	if board_layer == null:
		return
	_refresh_title()
	_refresh_phase()
	_refresh_world()
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
	_rebuild_hand(animate)

func _refresh_title() -> void:
	var turn := board_layer.get_node_or_null("TurnLabel")
	if turn != null:
		turn.text = "ターン %d/%d  %s" % [game.turn, game.turn_limit, game.current_phase_name()]
	_set_label("AdvanceTokenLabel", _advance_token_text())

func _refresh_phase() -> void:
	for i in range(phase_pips.size()):
		var active: bool = i == game.phase_index
		phase_pips[i].set_skin(WARN if active else Color(0.04, 0.035, 0.026, 0.55), BOARD_LINE)
		var label: Label = board_layer.get_node_or_null("PhaseLabel_%d" % i)
		if label != null:
			label.add_theme_color_override("font_color", TEXT if active else MUTED)

func _refresh_world() -> void:
	var event: Dictionary = game.world.current_event
	_set_label("EventTitle", String(event.get("display_name", "")))
	_set_label("EventMessage", String(event.get("message", "")))
	_set_label("EventDeck", "山札 %d / 捨札 %d" % [game.world.event_deck.size(), game.world.event_discard.size()])
	_set_label("WorldPanelHint", _persistent_crisis_summary())
	for key in WORLD_TRACKS:
		var tile = board_layer.get_node_or_null("WorldTrack_%s" % key)
		if tile == null:
			continue
		var value := int(game.world.tracks.get(key, 0))
		var color := TrackPresenterScript.track_color(key, value, _track_colors())
		var highlighted: bool = key == log_highlight_key
		tile.set_skin(Color(0.045, 0.032, 0.018, 0.86) if highlighted else Color(0.020, 0.019, 0.016, 0.72), WARN if highlighted else color, 3 if highlighted else 1, "card")
		var rail := tile.get_node("TrackRail")
		_clear_children(rail)
		var filled := TrackPresenterScript.marker_count(key, value)
		for i in range(7):
			var x := i * 12.0
			rail.add_child(_make_pip(Vector2(x, 0), 10, color if i < filled else TOKEN_EMPTY))
		var icon: TextureRect = tile.get_node_or_null("TrackIcon")
		if icon != null:
			icon.modulate = color.lightened(0.20)

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
	for item in AGENDA:
		var tag := String(item["tag"])
		var tile := board_layer.get_node("Agenda_%s" % tag)
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
		tile.set_skin(Color(0.18, 0.13, 0.065, 0.94) if declared_here else Color(0.15, 0.105, 0.055, 0.92), COUNTRY_ACCENTS[selected_country_index] if declared_here else BOARD_LINE, 3 if declared_here else 2, "card")
		for i in range(4):
			pips.add_child(_make_pip(Vector2(i * 14, 0), 8, WARN if i < count else TOKEN_EMPTY))

func _refresh_country_seats() -> void:
	for i in range(country_seats.size()):
		var country = game.countries[i]
		var accent: Color = COUNTRY_ACCENTS[i]
		var active: bool = i == selected_country_index
		var targeted_by_selected := _selected_policy_target_index() == i
		var seat = country_seats[i]
		var border_color: Color = WARN if targeted_by_selected else accent
		seat.set_skin(Color(0.090, 0.064, 0.034, 0.94) if active else Color(0.060, 0.046, 0.030, 0.86), border_color, 3 if active or targeted_by_selected else 2, "card")
		country_pressure_labels[i].text = _pressure_summary(country)
		country_state_labels[i].text = _state_hand_card_text(country)
		country_policy_labels[i].text = _policy_slot_summary(country)
		country_next_labels[i].text = "手:%s" % _state_card_summary(country)
		country_pipeline_labels[i].text = _pipeline_summary(country)
		country_election_labels[i].text = _election_short_status(country)
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

func _refresh_policy_slot(animate: bool) -> void:
	var country = game.countries[selected_country_index]
	var phase: String = game.current_phase()
	var country_name := "%s国" % UiCatalogScript.country_emblem(selected_country_index)
	if phase == "policy_planning":
		if not country.selected_policy.is_empty() and String(country.selected_policy.get("target", "")) == "country":
			policy_slot_label.text = "%sの対象国を指名\n%s" % [country_name, _target_effect_preview(country)]
		else:
			policy_slot_label.text = "%s 伏せ札提出済み\n次の国へ" % country_name if not country.selected_policy.is_empty() else "%sの政策案を伏せる\n政策メニューから1枚選択" % country_name
	elif phase == "worker_assignment":
		policy_slot_label.text = "%sの伏せ札に\n担当印を押す" % country_name
	elif phase == "simultaneous_reveal":
		policy_slot_label.text = "4国の政策案を\n同時公開"
	elif phase == "resolution":
		policy_slot_label.text = "%sを確認\n次で進める" % _resolution_step_name(resolution_step_index) if resolution_review_active else "公開済み政策を\n順に解決"
	else:
		policy_slot_label.text = CardTextFormatterScript.planned_text(country, game.revealed_policies, phase, game.is_finished).replace("[center]", "").replace("[/center]", "").replace("[b]", "").replace("[/b]", "")
	_refresh_cost_sockets(country)
	if animate:
		_bump(policy_slot)

func _refresh_cost_sockets(country) -> void:
	var policy: Dictionary = country.selected_policy
	if policy.is_empty():
		policy = CardTextFormatterScript.first_policy(country.policy_menu)
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
		log_panel.text = _news_headlines(game.log)

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
	var items: Array = _resolution_items()
	var has_items := not items.is_empty()
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

func _refresh_resolution_links() -> void:
	if resolution_overlay == null or resolution_marker_layer == null:
		return
	_clear_children(resolution_marker_layer)
	var items: Array = _resolution_items()
	if items.is_empty() or not _should_show_resolution_links():
		resolution_overlay.set_paths([])
		return
	var paths := []
	var world_path_count := 0
	var active_step := resolution_step_index if resolution_review_active else 5
	for item in items:
		var country_index := int(item.get("country_index", -1))
		if country_index < 0 or country_index >= country_seats.size():
			continue
		var accent: Color = COUNTRY_ACCENTS[country_index]
		var is_focus_country := country_index == selected_country_index
		if is_focus_country and _resolution_stage_visible(0, active_step):
			paths.append(_resolution_path(0, _country_pressure_center(country_index), GOOD if bool(item.get("pressure_satisfied", false)) else BAD, "圧"))
		if is_focus_country and _resolution_stage_visible(1, active_step):
			paths.append(_resolution_path(1, _control_center(country_stamp_slots[country_index]), WARN, "費"))
		if _diff_count(_as_dict(item.get("country_diffs", {}))) > 0 and _resolution_stage_visible(2, active_step):
			var country_diff_label := _diff_chip_label(_as_dict(_as_dict(item.get("country_diffs", {})).get(country_index, {})), "国")
			if is_focus_country:
				paths.append(_resolution_path(2, _control_center(country_seats[country_index]), accent, "国"))
			_add_result_chip("CountryResult_%d" % country_index, _country_result_chip_center(country_index, -14), country_diff_label, accent)
		if _resolution_stage_visible(3, active_step):
			for key in item.get("world_effect_keys", []):
				if world_path_count >= 2:
					break
				var track = board_layer.get_node_or_null("WorldTrack_%s" % String(key))
				if track != null:
					var track_color := TrackPresenterScript.track_color(String(key), int(game.world.tracks.get(String(key), 0)), _track_colors())
					paths.append(_resolution_path(3, _control_center(track), track_color, "世"))
					_add_result_chip("WorldResult_%d" % world_path_count, _control_center(track) + Vector2(12, -14), _single_diff_chip_label(_as_dict(item.get("world_diff", {})), String(key), "世"), track_color)
					world_path_count += 1
		if int(item.get("mutation_count", 0)) > 0 and _resolution_stage_visible(4, active_step):
			if is_focus_country:
				paths.append(_resolution_path(4, _control_center(country_seats[country_index]) + Vector2(0, 56), BAD, "変"))
			_add_result_chip("DeckResult_%d" % country_index, _country_result_chip_center(country_index, 18), "変", BAD)
	var macro: Dictionary = last_resolution_snapshot.get("macro", {})
	if not macro.is_empty() and _resolution_stage_visible(5, active_step):
		var macro_world: Dictionary = macro.get("world_diff", {})
		var macro_countries: Dictionary = macro.get("country_diffs", {})
		var macro_path_added := false
		if not macro_world.is_empty():
			paths.append(_resolution_path(5, _control_center(board_layer.get_node("WorldPanel")), WARN, "合"))
			_add_result_chip("MacroWorldResult", _control_center(board_layer.get_node("WorldPanel")) + Vector2(0, 38), _diff_chip_label(macro_world, "合"), WARN)
			macro_path_added = true
		for key in macro_countries.keys():
			var country_index := int(key)
			if country_index >= 0 and country_index < country_seats.size():
				if not macro_path_added:
					paths.append(_resolution_path(5, _control_center(country_seats[country_index]), COUNTRY_ACCENTS[country_index], "合"))
					macro_path_added = true
				_add_result_chip("MacroCountryResult_%d" % country_index, _control_center(country_seats[country_index]) + Vector2(0, -36), _diff_chip_label(_as_dict(macro_countries.get(key, {})), "合"), COUNTRY_ACCENTS[country_index])
	resolution_overlay.set_paths(paths)

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
		"financial_stress": "金",
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
		return "状態手札\nなし"
	var parts := []
	for card in country.hand:
		if not _is_state_card(card):
			continue
		parts.append(UiCatalogScript.short_card_name(card).substr(0, 6))
		if parts.size() >= 2:
			break
	return "状態手札\n%s" % (" / ".join(parts) if not parts.is_empty() else "なし")

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
	var lines: Array = [_news_headlines(game.log).replace("\n\n", "\n")]
	var welfare_parts: Array = []
	for i in range(game.countries.size()):
		var country = game.countries[i]
		welfare_parts.append("%s国 %s 累%d" % [
			UiCatalogScript.country_emblem(i),
			_welfare_check_summary(country),
			int(country.welfare_score)
		])
	lines.append("厚生: %s" % " / ".join(welfare_parts))
	return "\n".join(lines)

func _persistent_crisis_summary() -> String:
	var crises: Array = game.world.active_crises
	if crises.is_empty():
		return "持続危機なし"
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
	country_detail_label.text = "%s\n圧力:%s / 選挙:%s\n厚生:%d  条件:%s\n次札:%s / %s\n状態:%s\n対応:%s / 印:%s\nリスク:%s\n山札/捨札:%d/%d" % [
		country.display_name.substr(0, 12),
		pressure.substr(0, 14),
		_election_status(country),
		int(country.welfare_score),
		_welfare_condition_marks(country),
		_next_deck_name(country),
		_pipeline_summary(country),
		_state_card_summary(country),
		_response_target_summary(country),
		_worker_summary(country),
		_country_risk_words(country),
		country.deck.size(),
		country.discard.size()
	]

func _refresh_workers() -> void:
	var assigned: Array = game.countries[selected_country_index].assigned_worker_list()
	var show_workers: bool = game.current_phase() == "worker_assignment"
	var tray_pos: Vector2 = board_layout["hand_panel_pos"]
	var tray_size: Vector2 = board_layout["hand_panel_size"]
	var token_gap := 20.0
	var token_size: Vector2 = board_layout["worker_size"]
	var total_width := token_size.x * WORKERS.size() + token_gap * (WORKERS.size() - 1)
	var token_y := tray_pos.y + (tray_size.y - token_size.y) * 0.5
	var token_x := tray_pos.x + (tray_size.x - total_width) * 0.5
	for i in range(WORKERS.size()):
		var worker: String = WORKERS[i]
		var node = worker_nodes[worker]
		node.visible = show_workers
		if not show_workers:
			continue
		node.position = _snap_vec(Vector2(token_x + (token_size.x + token_gap) * i, token_y))
		node.home_position = node.position
		var selected: bool = assigned.has(worker)
		node.set_skin(Color(0, 0, 0, 0.04), COUNTRY_ACCENTS[selected_country_index] if selected else Color(0, 0, 0, 0.10), 3 if selected else 1, "circle")

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
			return "印確定"
		return "公開"
	if game.current_phase() == "simultaneous_reveal":
		return "公開"
	if resolution_review_active or game.current_phase() == "resolution":
		return "解決"
	if game.is_finished:
		return "終了"
	return "進行"

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

func _on_recommend_pressed() -> void:
	last_resolution_snapshot = {}
	resolution_review_active = false
	resolution_step_index = -1
	worker_assignment_confirmed = []
	_hide_turn_news_overlay()
	if game.can_select_policy():
		for i in range(game.countries.size()):
			var recommendation := PolicyRecommenderScript.recommend_for_country(game, i)
			if recommendation.is_empty():
				continue
			game.select_policy(i, int(recommendation["policy_index"]))
	elif game.can_assign_worker():
		_ensure_worker_confirmations()
		for i in range(game.countries.size()):
			var recommendation := PolicyRecommenderScript.recommend_for_country(game, i)
			if recommendation.is_empty():
				continue
			game.assign_workers(i, recommendation.get("workers", [String(recommendation["worker"])]))
			worker_assignment_confirmed[i] = true
	_refresh_board(true)

func _on_log_panel_pressed() -> void:
	log_highlight_key = _latest_log_world_track()
	_refresh_world()
	if not log_highlight_key.is_empty():
		var track = board_layer.get_node_or_null("WorldTrack_%s" % log_highlight_key)
		if track != null:
			_bump(track)

func _on_agenda_declared(tag: String) -> void:
	if game.current_phase() != "negotiation":
		return
	game.declare_agenda(selected_country_index, tag)
	game.request_support(selected_country_index, tag)
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
	var origin = country_seats[country_index].position + Vector2(60, 46)
	_refresh_title()
	_refresh_country_seats()
	_refresh_policy_slot(true)
	_refresh_workers()
	_rebuild_hand(true, origin)
	_animate_country_marker(previous, country_index)

func _on_policy_selected(country_index: int, policy_index: int, from_pos: Vector2) -> void:
	if not game.can_select_policy():
		return
	last_resolution_snapshot = {}
	resolution_review_active = false
	resolution_step_index = -1
	worker_assignment_confirmed = []
	var card: Dictionary = game.countries[country_index].policy_menu[policy_index]
	game.select_policy(country_index, policy_index)
	if String(card.get("target", "")) == "country":
		selected_country_index = country_index
	else:
		selected_country_index = _next_country_without_policy(country_index)
		if selected_country_index < 0:
			_enter_worker_assignment()
	_refresh_board(false)
	var card_size: Vector2 = board_layout.get("hand_card_size", Vector2(82, 108))
	var slot: Control = country_policy_slots[country_index]
	_animate_card_to_slot(country_index, card, from_pos, slot.global_position + (slot.size - card_size) * 0.5)

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

func _is_waiting_for_policy_target(source_index: int, target_index: int) -> bool:
	if not game.can_select_policy():
		return false
	if source_index < 0 or source_index >= game.countries.size():
		return false
	if source_index == target_index:
		return false
	var country = game.countries[source_index]
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

func _all_workers_confirmed() -> bool:
	_ensure_worker_confirmations()
	for confirmed in worker_assignment_confirmed:
		if not bool(confirmed):
			return false
	return true

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
	var token = _make_piece(node_name, position, size, Color(0.05, 0.038, 0.024, 0.72), BOARD_LINE, 1, "circle")
	token.pressed = action
	var font_size := 20 if size.x >= 44.0 else 16
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
	label.add_theme_font_size_override("font_size", font_size)
	_apply_label_outline(label, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_layer.add_child(label)
	return label

func _add_label_to(parent: Control, node_name: String, text: String, position: Vector2, label_size: Vector2, font_size: int, color: Color, wrap := false) -> Label:
	var label := Label.new()
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
	label.add_theme_font_size_override("font_size", font_size)
	_apply_label_outline(label, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

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
	var ghost = _make_policy_card(card, -1, country_index)
	ghost.name = "PolicyGhost"
	ghost.position = _snap_vec(from_pos)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_layer.add_child(ghost)
	var card_center: Vector2 = ghost.size * 0.5
	_animate_trail(from_pos + card_center, to_pos + card_center, COUNTRY_ACCENTS[country_index], 0.28)
	_animate_move_and_fade(ghost, to_pos, 0.28)

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

func _animate_hand_deal(node: Control, source: Vector2, final_pos: Vector2, delay: float) -> void:
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
	var viewport_size := get_viewport_rect().size
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x > 0 and window_size.y > 0:
		return Vector2(minf(viewport_size.x, window_size.x), minf(viewport_size.y, window_size.y))
	return viewport_size

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

func _short_news_line(line: String) -> String:
	var cleaned := line.replace("世界イベント「", "").replace("」: ", "：")
	cleaned = cleaned.replace("しました。", "。").replace("されています。", "。")
	if cleaned.length() > 42:
		return cleaned.substr(0, 41) + "…"
	return cleaned

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
		String(pressure.get("display_name", "国内圧力")),
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
		{"key": "financial_stress", "label": "金"},
		{"key": "political_capital", "label": "政"}
	]
	for i in range(chip_defs.size()):
		var def: Dictionary = chip_defs[i]
		var value := int(country.tracks.get(def["key"], 0))
		var key := String(def["key"])
		var color: Color = BAD if value >= 5 and key != "political_capital" else COUNTRY_ACCENTS[country_index]
		if key == "political_capital" and value <= 2:
			color = WARN
		var chip = _make_pip(Vector2(i * 18, 0), 10, color)
		chip.tooltip_text = "%s %d" % [def["label"], value]
		rack.add_child(chip)

func _track_colors() -> Dictionary:
	return {
		"good": GOOD,
		"warn": WARN,
		"bad": BAD,
		"blue": BLUE
	}
