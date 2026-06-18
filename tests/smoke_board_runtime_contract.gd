extends SceneTree

const MainScript := preload("res://src/ui/main.gd")
const BANNED_RUNTIME_CLASSES := [
	"PanelContainer",
	"HBoxContainer",
	"VBoxContainer",
	"ScrollContainer",
	"TabContainer",
	"Button"
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ui = MainScript.new()
	ui.size = get_root().size
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(ui)
	await process_frame
	await process_frame
	ui.game.world.active_crises = [{"display_name": "試験持続危機", "turns": 2, "clear_text": "協調4"}]
	ui._refresh_board(false)
	await process_frame

	var banned := []
	_collect_banned(ui, banned)
	_assert(banned.is_empty(), "main board runtime avoids banned UI nodes: %s" % ", ".join(banned))
	_assert(ui.country_seats.size() == 4, "runtime board shows four country seats without scroll")
	_assert(ui.worker_nodes.size() == 5, "runtime board shows worker tokens as board pieces")
	_assert(ui.phase_pips.size() == ui.GameStateScript.PHASES.size(), "runtime board shows phase pips as board markers")
	_assert(ui.policy_menu_nodes.is_empty(), "runtime board hides policy menu outside policy planning")
	_assert(ui.policy_slot != null, "runtime board has a physical policy slot")
	var domestic_state_panel: Control = ui.board_layer.get_node_or_null("DomesticStatePanel")
	_assert(domestic_state_panel != null, "runtime board has a revealed domestic state lane")
	for key in ui.WORLD_TRACKS:
		_assert(ui.board_layer.get_node_or_null("WorldTrack_%s" % key) != null, "runtime board shows world track: %s" % key)
	var crisis_hint: Label = ui.board_layer.get_node_or_null("WorldPanel/WorldPanelHint")
	_assert(crisis_hint != null and crisis_hint.text.contains("解除"), "world board shows persistent crisis counter and clear condition")
	_assert(ui.score_panel != null and not ui.score_panel.text.is_empty(), "runtime board shows scores")
	_assert(ui.log_panel != null and not ui.log_panel.text.is_empty(), "runtime board shows resolution log")
	_assert(ui.country_detail_label != null and ui.country_detail_label.text.contains("リスク"), "runtime board shows selected country risk summary")
	_assert(ui.country_detail_label.text.contains("次札"), "runtime board detail shows next deck forecast")
	_assert(ui.country_detail_label.text.contains("条件"), "runtime board detail shows welfare checklist")
	_assert(ui.board_layer.get_node_or_null("CollapseWarning") != null, "runtime board has collapse warning banner")
	for key in ui.COST_KEYS:
		_assert(ui.policy_slot.get_node_or_null("CostSocket_%s" % key) != null, "policy slot has cost socket: %s" % key)
	for seat in ui.country_seats:
		for label_name in ["NextDeckLabel", "PipelineLabel", "ElectionLabel", "WelfareLabel"]:
			var label: Label = seat.get_node_or_null(label_name)
			_assert(label != null, "country seat has %s node: %s" % [label_name, seat.name])
			if label.visible:
				_assert(not label.text.is_empty(), "visible country seat label is populated %s: %s" % [label_name, seat.name])

	var viewport := ui.get_viewport_rect()
	for seat in ui.country_seats:
		_assert(_inside_viewport(seat, viewport), "country seat remains inside the board viewport: %s" % seat.name)
	for card in ui.policy_menu_nodes:
		_assert(_inside_viewport(card, viewport), "policy menu card remains inside the board viewport: %s" % card.name)
		_assert(not _controls_overlap(card, ui.board_layer.get_node("EventCard")), "policy menu card does not overlap event card: %s" % card.name)
		_assert(not _controls_overlap(card, ui.policy_slot), "policy menu card does not overlap policy slot: %s" % card.name)
		if domestic_state_panel != null:
			_assert(not _controls_overlap(card, domestic_state_panel), "policy menu card does not overlap domestic state lane: %s" % card.name)
		for seat in ui.country_seats:
			_assert(not _controls_overlap(card, seat), "policy menu card does not overlap country seat: %s / %s" % [card.name, seat.name])
	for key in ui.WORLD_TRACKS:
		var track: Control = ui.board_layer.get_node("WorldTrack_%s" % key)
		for card in ui.policy_menu_nodes:
			_assert(not _controls_overlap(track, card), "world track does not overlap policy menu card: %s / %s" % [track.name, card.name])
	for worker in ui.worker_nodes.keys():
		_assert(_inside_viewport(ui.worker_nodes[worker], viewport), "worker token remains inside the board viewport: %s" % worker)
	for pip in ui.phase_pips:
		_assert(_inside_viewport(pip, viewport), "phase pip remains inside the board viewport: %s" % pip.name)
	for token_name in ["RestartToken", "RecommendToken", "AdvanceToken"]:
		var token: Control = ui.board_layer.get_node_or_null(token_name)
		_assert(token != null, "action token exists on the board: %s" % token_name)
		_assert(_inside_viewport(token, viewport), "action token remains inside the board viewport: %s" % token_name)
	_assert(_inside_viewport(ui.policy_slot, viewport), "policy slot remains inside the board viewport")
	var score_panel: Control = ui.board_layer.get_node("ScorePanel")
	var log_panel: Control = ui.board_layer.get_node("LogPanel")
	var country_detail_panel: Control = ui.board_layer.get_node("CountryDetailPanel")
	var play_surface: Control = ui.board_layer.get_node("PlaySurface")
	var world_panel: Control = ui.board_layer.get_node("WorldPanel")
	_assert(play_surface.size.x >= viewport.size.x * 0.66, "play surface owns the screen width")
	_assert(world_panel.size.x >= viewport.size.x * 0.58, "world board is visually dominant")
	_assert(world_panel.size.y >= 178.0, "world board is tall enough to read")
	_assert(log_panel.size.x * log_panel.size.y < viewport.size.x * viewport.size.y * 0.14, "newspaper rail stays secondary while remaining readable")
	_assert(_inside_viewport(country_detail_panel, viewport), "country detail panel remains inside the board viewport")
	_assert(country_detail_panel.size.y >= 88.0, "country detail panel remains large enough to read")
	_assert(ui.country_detail_label.get_theme_font_size("font_size") >= 13, "country detail text remains readable")
	for panel in [score_panel, log_panel, country_detail_panel]:
		_assert(_inside_viewport(panel, viewport), "status panel remains inside the board viewport: %s" % panel.name)
		_assert(not _controls_overlap(panel, ui.policy_slot), "status panel does not overlap policy slot: %s" % panel.name)
		_assert(not _controls_overlap(panel, ui.board_layer.get_node("EventCard")), "status panel does not overlap event card: %s" % panel.name)
		for seat in ui.country_seats:
			_assert(not _controls_overlap(panel, seat), "status panel does not overlap country seat: %s / %s" % [panel.name, seat.name])
		for card in ui.policy_menu_nodes:
			_assert(not _controls_overlap(panel, card), "status panel does not overlap policy menu card: %s / %s" % [panel.name, card.name])
		for key in ui.WORLD_TRACKS:
			var track: Control = ui.board_layer.get_node("WorldTrack_%s" % key)
			_assert(not _controls_overlap(panel, track), "status panel does not overlap world track: %s / %s" % [panel.name, track.name])
	for i in range(ui.AGENDA.size()):
		var agenda: Control = ui.board_layer.get_node("Agenda_%s" % String(ui.AGENDA[i]["tag"]))
		_assert(not _controls_overlap(score_panel, agenda), "score panel does not overlap agenda: %s" % agenda.name)
		_assert(not _controls_overlap(log_panel, agenda), "log panel does not overlap agenda: %s" % agenda.name)
	for key in ui.WORLD_TRACKS:
		var track: Control = ui.board_layer.get_node("WorldTrack_%s" % key)
		var rail: Control = track.get_node("TrackRail")
		_assert(track.size.x > track.size.y, "world crisis card is horizontal, not a vertical meter: %s" % key)
		_assert(rail.size.x > rail.size.y * 4.0, "world crisis pips run horizontally: %s" % key)

	print("Smoke board runtime contract passed.")
	quit(0)

func _collect_banned(node: Node, banned: Array) -> void:
	for runtime_class in BANNED_RUNTIME_CLASSES:
		if node.is_class(runtime_class):
			banned.append("%s<%s>" % [node.name, runtime_class])
	for child in node.get_children():
		_collect_banned(child, banned)

func _inside_viewport(control: Control, viewport: Rect2) -> bool:
	var rect := Rect2(control.global_position, control.size)
	return viewport.encloses(rect)

func _controls_overlap(a: Control, b: Control) -> bool:
	return Rect2(a.global_position, a.size).intersects(Rect2(b.global_position, b.size))

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
