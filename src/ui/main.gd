extends Control

const GameStateScript := preload("res://src/core/game_state.gd")
const PolicyRecommenderScript := preload("res://src/app/policy_recommender.gd")
const TokenAssetsScript := preload("res://src/ui/support/token_assets.gd")
const UiCatalogScript := preload("res://src/ui/support/ui_catalog.gd")
const TrackPresenterScript := preload("res://src/ui/support/track_presenter.gd")
const ResponsiveLayoutScript := preload("res://src/ui/support/responsive_layout.gd")
const CardTextFormatterScript := preload("res://src/ui/support/card_text_formatter.gd")
const BoardLayoutScript := preload("res://src/ui/support/board_layout.gd")
const BoardPieceScript := preload("res://src/ui/support/board_piece.gd")
const BoardTrailScript := preload("res://src/ui/support/board_trail.gd")
const LegacyScorePanelScript := preload("res://src/ui/components/legacy_score_panel.gd")
const ResolutionLogScript := preload("res://src/ui/components/resolution_log.gd")
const BG_TEXTURE := preload("res://assets/ui/board_table_background.png")

const INK := Color(0.13, 0.10, 0.065)
const TEXT := Color(0.94, 0.90, 0.78)
const MUTED := Color(0.67, 0.64, 0.54)
const BOARD_LINE := Color(0.58, 0.39, 0.17, 0.96)
const CARD_FACE := Color(0.83, 0.76, 0.58, 0.98)
const CARD_BACK := Color(0.08, 0.10, 0.09, 0.88)
const GOOD := Color(0.22, 0.64, 0.43)
const WARN := Color(0.90, 0.58, 0.18)
const BAD := Color(0.78, 0.23, 0.18)
const BLUE := Color(0.28, 0.58, 0.82)
const TOKEN_EMPTY := Color(0.18, 0.13, 0.07, 0.90)
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

var game
var token_assets
var board_layer: Control
var selected_country_index := 0
var phase_pips: Array = []
var country_seats: Array = []
var hand_nodes: Array = []
var worker_nodes := {}
var policy_slot
var policy_slot_label: Label
var log_panel
var score_panel
var country_detail_label: Label
var last_selected_country_index := 0
var board_layout: Dictionary = {}

func _ready() -> void:
	token_assets = TokenAssetsScript.new()
	game = GameStateScript.new()
	game.new_game()
	_build_board()
	_refresh_board(true)

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
	_build_table_marks()
	_build_event_card()
	_build_world_tracks()
	_build_agenda_tiles()
	_build_country_seats()
	_build_policy_slot()
	_build_worker_tokens()
	_build_status_panels()
	_build_country_detail_panel()

func _add_background() -> void:
	var bg := TextureRect.new()
	bg.texture = BG_TEXTURE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

func _build_table_marks() -> void:
	_add_label("Title", "マクロノミカ", board_layout["title_pos"], board_layout["title_size"], 34, TEXT)
	_add_label("TurnLabel", "", board_layout["turn_pos"], board_layout["turn_size"], 14, MUTED)
	phase_pips.clear()
	var phase_start: Vector2 = board_layout["phase_pip_start"]
	var phase_step: Vector2 = board_layout["phase_pip_step"]
	for i in range(GameStateScript.PHASES.size()):
		var pip = _make_piece("PhasePip_%d" % i, phase_start + phase_step * i, board_layout["phase_pip_size"], Color(0.04, 0.035, 0.026, 0.55), BOARD_LINE)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		phase_pips.append(pip)
	var command_origin: Vector2 = board_layout["command_origin"]
	_add_action_token("RestartToken", "↺", command_origin + Vector2(12, 12), Vector2(48, 48), _on_restart_pressed)
	_add_action_token("RecommendToken", "推", command_origin + Vector2(76, 6), Vector2(58, 58), _on_recommend_pressed)
	_add_action_token("AdvanceToken", "次", command_origin + Vector2(150, 0), Vector2(68, 68), _on_advance_pressed)

func _build_event_card() -> void:
	var card = _make_piece("EventCard", board_layout["event_pos"], board_layout["event_size"], Color(0.15, 0.105, 0.050, 0.82), WARN, 2, "card")
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.rotation_degrees = -0.4
	card.add_child(_make_icon("world_demand_globe", Vector2(18, 52), Vector2(58, 58), WARN))
	_add_label_to(card, "EventCaption", "公開イベント", Vector2(78, 12), Vector2(130, 20), 12, WARN.lightened(0.2))
	_add_label_to(card, "EventTitle", "", Vector2(78, 34), Vector2(160, 32), 17, TEXT)
	_add_label_to(card, "EventMessage", "", Vector2(78, 68), Vector2(160, 52), 13, TEXT, true)
	_add_label_to(card, "EventDeck", "", Vector2(78, 122), Vector2(140, 20), 14, TEXT)

func _build_world_tracks() -> void:
	var start: Vector2 = board_layout["world_tracks_origin"]
	var step: Vector2 = board_layout["world_track_step"]
	for i in range(WORLD_TRACKS.size()):
		var key: String = WORLD_TRACKS[i]
		var tile = _make_piece("WorldTrack_%s" % key, start + Vector2((i % 3) * step.x, int(i / 3) * step.y), board_layout["world_track_size"], Color(0.035, 0.030, 0.023, 0.56), BLUE, 1, "plaque")
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(_make_icon(UiCatalogScript.track_token(key), Vector2(25, 2), Vector2(28, 18), Color.WHITE))
		_add_label_to(tile, "TrackLabel", _world_short_name(key), Vector2(0, 20), Vector2(78, 15), 10, TEXT)
		var rail := Control.new()
		rail.name = "TrackRail"
		rail.position = Vector2(5, 36)
		rail.size = Vector2(68, 8)
		tile.add_child(rail)

func _build_agenda_tiles() -> void:
	var start: Vector2 = board_layout["agenda_origin"]
	var step: Vector2 = board_layout["agenda_step"]
	for i in range(AGENDA.size()):
		var item: Dictionary = AGENDA[i]
		var tile = _make_piece("Agenda_%s" % item["tag"], start + step * i, board_layout["agenda_size"], Color(0.15, 0.10, 0.045, 0.64), BOARD_LINE, 1, "plaque")
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_add_label_to(tile, "AgendaIcon", String(item["icon"]), Vector2(0, 7), Vector2(104, 22), 18, WARN)
		_add_label_to(tile, "AgendaName", String(item["name"]), Vector2(0, 31), Vector2(104, 18), 11, TEXT)
		var pips := Control.new()
		pips.name = "AgendaPips"
		pips.position = Vector2(20, 55)
		pips.size = Vector2(64, 8)
		tile.add_child(pips)

func _build_country_seats() -> void:
	country_seats.clear()
	var positions: Array = board_layout["country_seat_positions"]
	for i in range(game.countries.size()):
		var seat = _make_piece("CountrySeat_%d" % i, positions[i], board_layout["country_seat_size"], Color(0.04, 0.035, 0.028, 0.52), COUNTRY_ACCENTS[i], 1, "seat")
		seat.pressed = func(country_index := i) -> void:
			_on_country_selected(country_index)
		seat.add_child(_make_disc_label("Emblem", UiCatalogScript.country_emblem(i), Vector2(10, 14), 42, COUNTRY_ACCENTS[i]))
		var state := _add_label_to(seat, "PolicyState", "伏", Vector2(58, 18), Vector2(58, 34), 12, TEXT)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		seat.add_child(_make_icon("bureaucrat_seal", Vector2(122, 14), Vector2(38, 38), COUNTRY_ACCENTS[i].lightened(0.12), "WorkerIcon"))
		country_seats.append(seat)

func _build_policy_slot() -> void:
	policy_slot = _make_piece("PolicySlot", board_layout["policy_slot_pos"], board_layout["policy_slot_size"], Color(0.04, 0.032, 0.022, 0.48), BOARD_LINE, 1, "plaque")
	policy_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(policy_slot, "PolicySlotTitle", "提出札", Vector2(0, 10), Vector2(178, 20), 13, WARN.lightened(0.18))
	policy_slot_label = _add_label_to(policy_slot, "PolicySlotLabel", "", Vector2(14, 36), Vector2(150, 44), 14, TEXT, true)

func _build_status_panels() -> void:
	var x: float = board_layout["status_x"]
	var score = _make_piece("ScorePanel", Vector2(x, 178), Vector2(222, 108), Color(0.04, 0.032, 0.022, 0.58), WARN, 1, "plaque")
	score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(score, "ScoreTitle", "暫定スコア", Vector2(0, 8), Vector2(222, 18), 12, WARN.lightened(0.18))
	score_panel = LegacyScorePanelScript.new()
	score_panel.name = "ScoreComponent"
	score_panel.position = Vector2(12, 28)
	score_panel.size = Vector2(198, 70)
	score_panel.add_theme_color_override("default_color", TEXT)
	score_panel.add_theme_font_size_override("normal_font_size", 12)
	score_panel.setup()
	score.add_child(score_panel)

	var log = _make_piece("LogPanel", Vector2(x, 302), Vector2(222, 286), Color(0.04, 0.032, 0.022, 0.58), BOARD_LINE, 1, "plaque")
	log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(log, "LogTitle", "解決ログ", Vector2(0, 10), Vector2(222, 18), 12, WARN.lightened(0.18))
	log_panel = ResolutionLogScript.new()
	log_panel.name = "LogComponent"
	log_panel.position = Vector2(12, 34)
	log_panel.size = Vector2(198, 238)
	log_panel.add_theme_color_override("default_color", TEXT)
	log_panel.add_theme_font_size_override("normal_font_size", 11)
	log_panel.setup(238)
	log.add_child(log_panel)

func _build_country_detail_panel() -> void:
	var x: float = board_layout["status_x"]
	var panel = _make_piece("CountryDetailPanel", Vector2(x, 600), Vector2(222, 104), Color(0.04, 0.032, 0.022, 0.58), BOARD_LINE, 1, "plaque")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(panel, "CountryDetailTitle", "国家マット", Vector2(0, 8), Vector2(222, 18), 12, WARN.lightened(0.18))
	country_detail_label = _add_label_to(panel, "CountryDetailLabel", "", Vector2(12, 30), Vector2(198, 64), 10, TEXT, true)
	country_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	country_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _build_worker_tokens() -> void:
	worker_nodes.clear()
	var start: Vector2 = board_layout["worker_origin"]
	var step: Vector2 = board_layout["worker_step"]
	for i in range(WORKERS.size()):
		var worker: String = WORKERS[i]
		var token = _make_piece("Worker_%s" % worker, start + step * i, Vector2(62, 62), Color(0.045, 0.035, 0.025, 0.70), BOARD_LINE, 1, "circle")
		token.tooltip_text = UiCatalogScript.worker_name(worker)
		token.pressed = func(worker_id := worker) -> void:
			if game.can_assign_worker():
				_on_worker_assigned(selected_country_index, worker_id, token.position)
		token.add_child(_make_icon(UiCatalogScript.worker_token(worker), Vector2(4, 4), Vector2(54, 54), Color.WHITE))
		worker_nodes[worker] = token

func _rebuild_hand(animate: bool, origin := Vector2.INF) -> void:
	for node in hand_nodes:
		node.queue_free()
	hand_nodes.clear()
	var country = game.countries[selected_country_index]
	var hand_origin: Vector2 = board_layout["hand_origin"]
	var hand_step: Vector2 = board_layout["hand_step"]
	var source := origin
	if source == Vector2.INF and selected_country_index < country_seats.size():
		source = country_seats[selected_country_index].position + Vector2(60, 46)
	for i in range(country.hand.size()):
		var card: Dictionary = country.hand[i]
		var card_node = _make_policy_card(card, i)
		var final_pos := hand_origin + hand_step * i + Vector2(0, abs(i - 2) * 5.0)
		card_node.position = final_pos
		card_node.rotation_degrees = (i - 2) * 3.0
		board_layer.add_child(card_node)
		hand_nodes.append(card_node)
		if animate:
			_animate_hand_deal(card_node, source, final_pos, 0.025 * i)

func _make_policy_card(card: Dictionary, hand_index: int):
	var country = game.countries[selected_country_index]
	var selected: bool = not country.selected_policy.is_empty() and country.selected_policy.get("id", "") == card.get("id", "")
	var face: Color = CARD_FACE if card.get("type", "") == "policy" else Color(0.18, 0.16, 0.12, 0.96)
	var border: Color = COUNTRY_ACCENTS[selected_country_index] if selected else BOARD_LINE
	var card_node = BoardPieceScript.new()
	card_node.name = "HandCard_%d" % hand_index
	card_node.size = Vector2(82, 108)
	card_node.set_skin(face, border, 2, "card")
	card_node.tooltip_text = String(card.get("description", ""))
	card_node.pressed = func() -> void:
		if card.get("type", "") == "policy" and game.can_select_policy():
			_on_policy_selected(selected_country_index, hand_index, card_node.position)
	card_node.add_child(_make_icon_medallion(UiCatalogScript.card_token(card), Vector2(20, 18), COUNTRY_ACCENTS[selected_country_index], 42))
	var label := _add_label_to(card_node, "CardName", UiCatalogScript.short_card_name(card), Vector2(6, 72), Vector2(70, 28), 11, INK if card.get("type", "") == "policy" else TEXT, true)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return card_node

func _refresh_board(animate: bool) -> void:
	if board_layer == null:
		return
	_refresh_title()
	_refresh_phase()
	_refresh_world()
	_refresh_agenda()
	_refresh_country_seats()
	_refresh_policy_slot(animate)
	_refresh_workers()
	_refresh_status_panels()
	_refresh_country_detail_panel()
	_rebuild_hand(animate)

func _refresh_title() -> void:
	var turn := board_layer.get_node_or_null("TurnLabel")
	if turn != null:
		turn.text = "ターン %d/%d  %s" % [game.turn, game.turn_limit, game.current_phase_name()]

func _refresh_phase() -> void:
	for i in range(phase_pips.size()):
		var active: bool = i == game.phase_index
		phase_pips[i].set_skin(WARN if active else Color(0.04, 0.035, 0.026, 0.55), BOARD_LINE)

func _refresh_world() -> void:
	var event: Dictionary = game.world.current_event
	_set_label("EventTitle", String(event.get("display_name", "")))
	_set_label("EventMessage", String(event.get("message", "")))
	_set_label("EventDeck", "山札 %d / 捨札 %d" % [game.world.event_deck.size(), game.world.event_discard.size()])
	for key in WORLD_TRACKS:
		var tile = board_layer.get_node_or_null("WorldTrack_%s" % key)
		if tile == null:
			continue
		var value := int(game.world.tracks.get(key, 0))
		var color := TrackPresenterScript.track_color(key, value, _track_colors())
		tile.set_skin(Color(0.035, 0.030, 0.023, 0.56), color, 1, "plaque")
		var rail := tile.get_node("TrackRail")
		_clear_children(rail)
		var filled := TrackPresenterScript.marker_count(key, value)
		for i in range(7):
			rail.add_child(_make_pip(Vector2(i * 9, 0), 7, color if i < filled else TOKEN_EMPTY))

func _refresh_agenda() -> void:
	for item in AGENDA:
		var tag := String(item["tag"])
		var tile := board_layer.get_node("Agenda_%s" % tag)
		var pips := tile.get_node("AgendaPips")
		_clear_children(pips)
		var count := 0
		for country in game.countries:
			if not country.selected_policy.is_empty() and PolicyRecommenderScript.has_tag(country.selected_policy, tag):
				count += 1
		for i in range(4):
			pips.add_child(_make_pip(Vector2(i * 14, 0), 8, WARN if i < count else TOKEN_EMPTY))

func _refresh_country_seats() -> void:
	for i in range(country_seats.size()):
		var country = game.countries[i]
		var accent: Color = COUNTRY_ACCENTS[i]
		var active: bool = i == selected_country_index
		var seat = country_seats[i]
		seat.set_skin(Color(0.07, 0.055, 0.035, 0.78) if active else Color(0.04, 0.035, 0.028, 0.52), accent, 2 if active else 1, "seat")
		_set_label_in(seat, "PolicyState", "政策" if not country.selected_policy.is_empty() and game.revealed_policies else "伏")
		var worker: TextureRect = seat.get_node("WorkerIcon")
		worker.texture = token_assets.texture(UiCatalogScript.worker_token(country.assigned_worker))
		worker.modulate = accent.lightened(0.12)

func _refresh_policy_slot(animate: bool) -> void:
	var country = game.countries[selected_country_index]
	policy_slot_label.text = CardTextFormatterScript.planned_text(country, game.revealed_policies, game.current_phase(), game.is_finished).replace("[center]", "").replace("[/center]", "").replace("[b]", "").replace("[/b]", "")
	if animate:
		_bump(policy_slot)

func _refresh_status_panels() -> void:
	if score_panel != null:
		score_panel.refresh(game.get_scores())
	if log_panel != null:
		log_panel.refresh(game.log)

func _refresh_country_detail_panel() -> void:
	if country_detail_label == null:
		return
	var country = game.countries[selected_country_index]
	var pressure := String(country.domestic_pressure.get("display_name", "国内圧力なし"))
	var track_line := "GDP %d  物価 %d  失業 %d  債務 %d\n金融 %d  政治 %d  為替 %d  経常 %d" % [
		int(country.tracks.get("gdp_gap", 0)),
		int(country.tracks.get("inflation", 0)),
		int(country.tracks.get("unemployment", 0)),
		int(country.tracks.get("debt", 0)),
		int(country.tracks.get("financial_stress", 0)),
		int(country.tracks.get("political_capital", 0)),
		int(country.tracks.get("exchange_rate", 0)),
		int(country.tracks.get("current_account", 0))
	]
	country_detail_label.text = "%s\n圧力: %s\n%s\n山 %d / 捨 %d" % [
		country.display_name.substr(0, 8),
		pressure.substr(0, 10),
		track_line,
		country.deck.size(),
		country.discard.size()
	]

func _refresh_workers() -> void:
	var assigned: String = game.countries[selected_country_index].assigned_worker
	for worker in worker_nodes.keys():
		var node = worker_nodes[worker]
		var selected: bool = worker == assigned
		node.set_skin(Color(0.08, 0.055, 0.028, 0.82) if selected else Color(0.045, 0.035, 0.025, 0.70), COUNTRY_ACCENTS[selected_country_index] if selected else BOARD_LINE, 2 if selected else 1, "circle")

func _on_advance_pressed() -> void:
	var previous_phase: int = game.phase_index
	game.advance_phase()
	_refresh_board(true)
	_animate_phase_marker(previous_phase, game.phase_index)

func _on_recommend_pressed() -> void:
	if game.can_select_policy():
		for i in range(game.countries.size()):
			var recommendation := PolicyRecommenderScript.recommend_for_country(game, i)
			if recommendation.is_empty():
				continue
			game.select_policy(i, int(recommendation["hand_index"]))
	elif game.can_assign_worker():
		for i in range(game.countries.size()):
			var recommendation := PolicyRecommenderScript.recommend_for_country(game, i)
			if recommendation.is_empty():
				continue
			game.assign_worker(i, String(recommendation["worker"]))
	_refresh_board(true)

func _on_restart_pressed() -> void:
	game.new_game()
	last_selected_country_index = 0
	selected_country_index = 0
	_refresh_board(true)

func _on_country_selected(country_index: int) -> void:
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

func _on_policy_selected(country_index: int, hand_index: int, from_pos: Vector2) -> void:
	if not game.can_select_policy():
		return
	var card: Dictionary = game.countries[country_index].hand[hand_index]
	game.select_policy(country_index, hand_index)
	selected_country_index = country_index
	_refresh_board(false)
	_animate_card_to_slot(card, from_pos, policy_slot.position + Vector2(46, -10))

func _on_worker_assigned(country_index: int, worker_id: String, from_pos: Vector2) -> void:
	if not game.can_assign_worker():
		return
	game.assign_worker(country_index, worker_id)
	selected_country_index = country_index
	_refresh_board(false)
	_animate_token_to_seat(UiCatalogScript.worker_token(worker_id), from_pos, country_seats[country_index].position + Vector2(122, 14), COUNTRY_ACCENTS[country_index])

func _add_action_token(node_name: String, text: String, position: Vector2, size: Vector2, action: Callable) -> void:
	var token = _make_piece(node_name, position, size, Color(0.05, 0.038, 0.024, 0.72), BOARD_LINE, 1, "circle")
	token.pressed = action
	_add_label_to(token, "%sLabel" % node_name, text, Vector2.ZERO, size, 20, TEXT)

func _make_piece(node_name: String, position: Vector2, piece_size: Vector2, fill: Color, border: Color, border_width := 1.0, shape := "rect"):
	var piece = BoardPieceScript.new()
	piece.name = node_name
	piece.position = position
	piece.size = piece_size
	piece.set_skin(fill, border, border_width, shape)
	board_layer.add_child(piece)
	return piece

func _make_icon(token_name: String, position: Vector2, icon_size: Vector2, tint: Color, node_name := "") -> TextureRect:
	var icon := TextureRect.new()
	if not node_name.is_empty():
		icon.name = node_name
	icon.texture = token_assets.texture(token_name)
	icon.position = position
	icon.size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _make_icon_medallion(token_name: String, position: Vector2, accent: Color, diameter := 46):
	var medallion = BoardPieceScript.new()
	medallion.position = position
	medallion.size = Vector2(diameter, diameter)
	medallion.set_skin(Color(0.050, 0.043, 0.032, 0.98), accent, 1, "circle")
	medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medallion.add_child(_make_icon(token_name, Vector2(5, 5), Vector2(diameter - 10, diameter - 10), Color.WHITE))
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
	label.position = position
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if node_name != "Title" and node_name != "TurnLabel" else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_layer.add_child(label)
	return label

func _add_label_to(parent: Control, node_name: String, text: String, position: Vector2, label_size: Vector2, font_size: int, color: Color, wrap := false) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = position
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

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

func _animate_card_to_slot(card: Dictionary, from_pos: Vector2, to_pos: Vector2) -> void:
	var ghost = _make_policy_card(card, -1)
	ghost.name = "PolicyGhost"
	ghost.position = from_pos
	ghost.rotation_degrees = -5
	board_layer.add_child(ghost)
	_animate_trail(from_pos + Vector2(42, 54), to_pos + Vector2(42, 54), COUNTRY_ACCENTS[selected_country_index], 0.28)
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

func _track_colors() -> Dictionary:
	return {
		"good": GOOD,
		"warn": WARN,
		"bad": BAD,
		"blue": BLUE
	}

func layout_mode_for_window_width(width: int) -> String:
	return ResponsiveLayoutScript.mode_for_width(width)

func is_short_window_height(height: int) -> bool:
	return ResponsiveLayoutScript.is_short_height(height)
