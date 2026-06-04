extends Control

const GameStateScript := preload("res://src/core/game_state.gd")
const PolicyRecommenderScript := preload("res://src/app/policy_recommender.gd")
const TokenAssetsScript := preload("res://src/ui/support/token_assets.gd")
const UiCatalogScript := preload("res://src/ui/support/ui_catalog.gd")
const TrackPresenterScript := preload("res://src/ui/support/track_presenter.gd")
const ResponsiveLayoutScript := preload("res://src/ui/support/responsive_layout.gd")
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
	"international_financial_instability"
]
const WORKERS := ["bureaucrats", "central_bank_staff", "diplomat", "auditor", "lobbyist"]

class BoardPiece:
	extends Control

	var fill := Color.WHITE
	var border := Color.BLACK
	var border_width := 1.0
	var shape := "plaque"
	var pressed := Callable()
	var hover_lift := 4.0
	var home_position := Vector2.ZERO

	func _ready() -> void:
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

class BoardTrail:
	extends Control

	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var color := Color.WHITE
	var progress := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(_delta: float) -> void:
		if progress > 0.0 and progress < 1.0:
			queue_redraw()

	func _draw() -> void:
		var end := from.lerp(to, progress)
		var glow := Color(color.r, color.g, color.b, 0.20)
		var core := Color(color.r, color.g, color.b, 0.68)
		draw_line(from, end, glow, 8.0, true)
		draw_line(from, end, core, 2.0, true)
		draw_circle(end, 5.0, core)

	func set_path(start: Vector2, finish: Vector2, trail_color: Color) -> void:
		from = start
		to = finish
		color = trail_color
		queue_redraw()

var game
var token_assets
var board_layer: Control
var selected_country_index := 0
var phase_pips: Array[BoardPiece] = []
var country_seats: Array[BoardPiece] = []
var hand_nodes: Array[BoardPiece] = []
var worker_nodes := {}
var policy_slot: BoardPiece
var policy_slot_label: Label
var last_selected_country_index := 0

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

func _add_background() -> void:
	var bg := TextureRect.new()
	bg.texture = BG_TEXTURE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

func _build_table_marks() -> void:
	var size := _screen()
	_add_label("Title", "マクロノミカ", Vector2(30, 72), Vector2(180, 42), 34, TEXT)
	_add_label("TurnLabel", "", Vector2(210, 88), Vector2(190, 24), 14, MUTED)
	phase_pips.clear()
	for i in range(GameStateScript.PHASES.size()):
		var pip := _make_piece("PhasePip_%d" % i, Vector2(38 + i * 50, 128), Vector2(36, 16), Color(0.04, 0.035, 0.026, 0.55), BOARD_LINE)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		phase_pips.append(pip)
	var command_x := minf(size.x - 250.0, 1080.0)
	_add_action_token("RestartToken", "↺", Vector2(command_x + 12, 102), Vector2(48, 48), _on_restart_pressed)
	_add_action_token("RecommendToken", "推", Vector2(command_x + 76, 96), Vector2(58, 58), _on_recommend_pressed)
	_add_action_token("AdvanceToken", "次", Vector2(command_x + 150, 90), Vector2(68, 68), _on_advance_pressed)

func _build_event_card() -> void:
	var card := _make_piece("EventCard", Vector2(48, 182), Vector2(258, 156), Color(0.15, 0.105, 0.050, 0.82), WARN, 2, "card")
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.rotation_degrees = -0.4
	card.add_child(_make_icon("world_demand_globe", Vector2(18, 52), Vector2(58, 58), WARN))
	_add_label_to(card, "EventCaption", "公開イベント", Vector2(78, 12), Vector2(130, 20), 12, WARN.lightened(0.2))
	_add_label_to(card, "EventTitle", "", Vector2(78, 34), Vector2(160, 32), 17, TEXT)
	_add_label_to(card, "EventMessage", "", Vector2(78, 68), Vector2(160, 52), 13, TEXT, true)
	_add_label_to(card, "EventDeck", "", Vector2(78, 122), Vector2(140, 20), 14, TEXT)

func _build_world_tracks() -> void:
	var start := Vector2(50, 356)
	for i in range(WORLD_TRACKS.size()):
		var key: String = WORLD_TRACKS[i]
		var tile := _make_piece("WorldTrack_%s" % key, start + Vector2((i % 2) * 136, int(i / 2) * 82), Vector2(122, 68), Color(0.035, 0.030, 0.023, 0.56), BLUE, 1, "plaque")
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(_make_icon(UiCatalogScript.track_token(key), Vector2(46, 4), Vector2(30, 24), Color.WHITE))
		_add_label_to(tile, "TrackLabel", _world_short_name(key), Vector2(0, 30), Vector2(122, 18), 11, TEXT)
		var rail := Control.new()
		rail.name = "TrackRail"
		rail.position = Vector2(8, 50)
		rail.size = Vector2(108, 10)
		tile.add_child(rail)

func _build_agenda_tiles() -> void:
	var start := Vector2(626, 248)
	for i in range(AGENDA.size()):
		var item: Dictionary = AGENDA[i]
		var tile := _make_piece("Agenda_%s" % item["tag"], start + Vector2(i * 112.0, 0), Vector2(104, 74), Color(0.15, 0.10, 0.045, 0.64), BOARD_LINE, 1, "plaque")
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
	var positions := [Vector2(356, 372), Vector2(562, 372), Vector2(356, 498), Vector2(562, 498)]
	for i in range(game.countries.size()):
		var seat := _make_piece("CountrySeat_%d" % i, positions[i], Vector2(170, 72), Color(0.04, 0.035, 0.028, 0.52), COUNTRY_ACCENTS[i], 1, "seat")
		seat.pressed = func(country_index := i) -> void:
			_on_country_selected(country_index)
		seat.add_child(_make_disc_label("Emblem", UiCatalogScript.country_emblem(i), Vector2(10, 14), 42, COUNTRY_ACCENTS[i]))
		var state := _add_label_to(seat, "PolicyState", "伏", Vector2(58, 18), Vector2(58, 34), 12, TEXT)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		seat.add_child(_make_icon("bureaucrat_seal", Vector2(122, 14), Vector2(38, 38), COUNTRY_ACCENTS[i].lightened(0.12), "WorkerIcon"))
		country_seats.append(seat)

func _build_policy_slot() -> void:
	policy_slot = _make_piece("PolicySlot", Vector2(818, 604), Vector2(178, 92), Color(0.04, 0.032, 0.022, 0.48), BOARD_LINE, 1, "plaque")
	policy_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(policy_slot, "PolicySlotTitle", "提出札", Vector2(0, 10), Vector2(178, 20), 13, WARN.lightened(0.18))
	policy_slot_label = _add_label_to(policy_slot, "PolicySlotLabel", "", Vector2(14, 36), Vector2(150, 44), 14, TEXT, true)

func _build_worker_tokens() -> void:
	worker_nodes.clear()
	var start := Vector2(484, 82)
	for i in range(WORKERS.size()):
		var worker: String = WORKERS[i]
		var token := _make_piece("Worker_%s" % worker, start + Vector2(i * 82, 0), Vector2(62, 62), Color(0.045, 0.035, 0.025, 0.70), BOARD_LINE, 1, "circle")
		token.tooltip_text = UiCatalogScript.worker_name(worker)
		token.pressed = func(worker_id := worker) -> void:
			_on_worker_assigned(selected_country_index, worker_id, token.position)
		token.add_child(_make_icon(UiCatalogScript.worker_token(worker), Vector2(4, 4), Vector2(54, 54), Color.WHITE))
		worker_nodes[worker] = token

func _rebuild_hand(animate: bool, origin := Vector2.INF) -> void:
	for node in hand_nodes:
		node.queue_free()
	hand_nodes.clear()
	var country = game.countries[selected_country_index]
	var start_x := 70.0
	var y := 532.0
	var source := origin
	if source == Vector2.INF and selected_country_index < country_seats.size():
		source = country_seats[selected_country_index].position + Vector2(60, 46)
	for i in range(country.hand.size()):
		var card: Dictionary = country.hand[i]
		var card_node := _make_policy_card(card, i)
		var final_pos := Vector2(start_x + i * 88.0, y + abs(i - 2) * 5.0)
		card_node.position = final_pos
		card_node.rotation_degrees = (i - 2) * 3.0
		board_layer.add_child(card_node)
		hand_nodes.append(card_node)
		if animate:
			_animate_hand_deal(card_node, source, final_pos, 0.025 * i)

func _make_policy_card(card: Dictionary, hand_index: int) -> BoardPiece:
	var country = game.countries[selected_country_index]
	var selected: bool = not country.selected_policy.is_empty() and country.selected_policy.get("id", "") == card.get("id", "")
	var face: Color = CARD_FACE if card.get("type", "") == "policy" else Color(0.18, 0.16, 0.12, 0.96)
	var border: Color = COUNTRY_ACCENTS[selected_country_index] if selected else BOARD_LINE
	var card_node := BoardPiece.new()
	card_node.name = "HandCard_%d" % hand_index
	card_node.size = Vector2(82, 108)
	card_node.set_skin(face, border, 2, "card")
	card_node.tooltip_text = String(card.get("description", ""))
	card_node.pressed = func() -> void:
		if card.get("type", "") == "policy" and game.current_phase() != "simultaneous_reveal":
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
		var tile: BoardPiece = board_layer.get_node_or_null("WorldTrack_%s" % key)
		if tile == null:
			continue
		var value := int(game.world.tracks.get(key, 0))
		var color := TrackPresenterScript.track_color(key, value, _track_colors())
		tile.set_skin(Color(0.035, 0.030, 0.023, 0.56), color, 1, "plaque")
		var rail := tile.get_node("TrackRail")
		_clear_children(rail)
		var filled := TrackPresenterScript.marker_count(key, value)
		for i in range(7):
			rail.add_child(_make_pip(Vector2(i * 14, 0), 9, color if i < filled else TOKEN_EMPTY))

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
		var seat := country_seats[i]
		seat.set_skin(Color(0.07, 0.055, 0.035, 0.78) if active else Color(0.04, 0.035, 0.028, 0.52), accent, 2 if active else 1, "seat")
		_set_label_in(seat, "PolicyState", "政策" if not country.selected_policy.is_empty() and game.revealed_policies else "伏")
		var worker: TextureRect = seat.get_node("WorkerIcon")
		worker.texture = token_assets.texture(UiCatalogScript.worker_token(country.assigned_worker))
		worker.modulate = accent.lightened(0.12)

func _refresh_policy_slot(animate: bool) -> void:
	var country = game.countries[selected_country_index]
	if country.selected_policy.is_empty():
		policy_slot_label.text = "政策案なし\n手札からカードを伏せます"
	else:
		policy_slot_label.text = UiCatalogScript.short_card_name(country.selected_policy)
	if animate:
		_bump(policy_slot)

func _refresh_workers() -> void:
	var assigned: String = game.countries[selected_country_index].assigned_worker
	for worker in worker_nodes.keys():
		var node: BoardPiece = worker_nodes[worker]
		var selected: bool = worker == assigned
		node.set_skin(Color(0.08, 0.055, 0.028, 0.82) if selected else Color(0.045, 0.035, 0.025, 0.70), COUNTRY_ACCENTS[selected_country_index] if selected else BOARD_LINE, 2 if selected else 1, "circle")

func _on_advance_pressed() -> void:
	var previous_phase: int = game.phase_index
	game.advance_phase()
	_refresh_board(true)
	_animate_phase_marker(previous_phase, game.phase_index)

func _on_recommend_pressed() -> void:
	for i in range(game.countries.size()):
		var recommendation := PolicyRecommenderScript.recommend_for_country(game, i)
		if recommendation.is_empty():
			continue
		game.select_policy(i, int(recommendation["hand_index"]))
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
	var origin := country_seats[country_index].position + Vector2(60, 46)
	_refresh_title()
	_refresh_country_seats()
	_refresh_policy_slot(true)
	_refresh_workers()
	_rebuild_hand(true, origin)
	_animate_country_marker(previous, country_index)

func _on_policy_selected(country_index: int, hand_index: int, from_pos: Vector2) -> void:
	var card: Dictionary = game.countries[country_index].hand[hand_index]
	game.select_policy(country_index, hand_index)
	selected_country_index = country_index
	_refresh_board(false)
	_animate_card_to_slot(card, from_pos, policy_slot.position + Vector2(46, -10))

func _on_worker_assigned(country_index: int, worker_id: String, from_pos: Vector2) -> void:
	game.assign_worker(country_index, worker_id)
	selected_country_index = country_index
	_refresh_board(false)
	_animate_token_to_seat(UiCatalogScript.worker_token(worker_id), from_pos, country_seats[country_index].position + Vector2(122, 14), COUNTRY_ACCENTS[country_index])

func _add_action_token(node_name: String, text: String, position: Vector2, size: Vector2, action: Callable) -> void:
	var token := _make_piece(node_name, position, size, Color(0.05, 0.038, 0.024, 0.72), BOARD_LINE, 1, "circle")
	token.pressed = action
	_add_label_to(token, "%sLabel" % node_name, text, Vector2.ZERO, size, 20, TEXT)

func _make_piece(node_name: String, position: Vector2, piece_size: Vector2, fill: Color, border: Color, border_width := 1.0, shape := "rect") -> BoardPiece:
	var piece := BoardPiece.new()
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

func _make_icon_medallion(token_name: String, position: Vector2, accent: Color, diameter := 46) -> BoardPiece:
	var medallion := BoardPiece.new()
	medallion.position = position
	medallion.size = Vector2(diameter, diameter)
	medallion.set_skin(Color(0.050, 0.043, 0.032, 0.98), accent, 1, "circle")
	medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medallion.add_child(_make_icon(token_name, Vector2(5, 5), Vector2(diameter - 10, diameter - 10), Color.WHITE))
	return medallion

func _make_disc_label(node_name: String, text: String, position: Vector2, diameter: float, accent: Color) -> BoardPiece:
	var disc := BoardPiece.new()
	disc.name = node_name
	disc.position = position
	disc.size = Vector2(diameter, diameter)
	disc.set_skin(Color(0.02, 0.022, 0.020, 0.62), accent, 1, "circle")
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label_to(disc, "%sText" % node_name, text, Vector2.ZERO, disc.size, 20, accent.lightened(0.2))
	return disc

func _make_pip(position: Vector2, pip_size: int, color: Color) -> BoardPiece:
	var pip := BoardPiece.new()
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
	var ghost := _make_policy_card(card, -1)
	ghost.name = "PolicyGhost"
	ghost.position = from_pos
	ghost.rotation_degrees = -5
	board_layer.add_child(ghost)
	_animate_trail(from_pos + Vector2(42, 54), to_pos + Vector2(42, 54), COUNTRY_ACCENTS[selected_country_index], 0.28)
	_animate_move_and_fade(ghost, to_pos, 0.28)

func _animate_token_to_seat(token_name: String, from_pos: Vector2, to_pos: Vector2, tint: Color) -> void:
	var ghost := _make_piece("WorkerGhost", from_pos, Vector2(46, 46), Color(0.045, 0.035, 0.025, 0.82), tint, 2, "circle")
	ghost.add_child(_make_icon(token_name, Vector2(4, 4), Vector2(38, 38), tint.lightened(0.12)))
	_animate_trail(from_pos + Vector2(23, 23), to_pos + Vector2(23, 23), tint, 0.24)
	_animate_move_and_fade(ghost, to_pos, 0.24)

func _animate_phase_marker(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= phase_pips.size() or to_index < 0 or to_index >= phase_pips.size():
		return
	var from_pip := phase_pips[from_index]
	var to_pip := phase_pips[to_index]
	var ghost := _make_piece("PhaseGhost", from_pip.position + Vector2(7, -5), Vector2(22, 22), WARN, BOARD_LINE, 2, "circle")
	_animate_trail(from_pip.position + Vector2(18, 3), to_pip.position + Vector2(18, 3), WARN, 0.22)
	_animate_move_and_fade(ghost, to_pip.position + Vector2(7, -5), 0.22)

func _animate_country_marker(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= country_seats.size() or to_index < 0 or to_index >= country_seats.size():
		return
	var from_seat := country_seats[from_index]
	var to_seat := country_seats[to_index]
	var accent: Color = COUNTRY_ACCENTS[to_index]
	var ghost := _make_piece("CountryFocusGhost", from_seat.position + Vector2(6, 10), Vector2(46, 46), Color(0.02, 0.022, 0.020, 0.50), accent, 2, "circle")
	_add_label_to(ghost, "CountryFocusLetter", UiCatalogScript.country_emblem(to_index), Vector2.ZERO, Vector2(46, 46), 20, accent.lightened(0.25))
	_animate_trail(from_seat.position + Vector2(28, 34), to_seat.position + Vector2(28, 34), accent, 0.24)
	_animate_move_and_fade(ghost, to_seat.position + Vector2(6, 10), 0.24)

func _animate_trail(from_pos: Vector2, to_pos: Vector2, color: Color, duration: float) -> void:
	var trail := BoardTrail.new()
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
		"international_financial_instability": "金融不安"
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
