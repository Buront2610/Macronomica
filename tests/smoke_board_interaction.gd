extends SceneTree

const MainScript := preload("res://src/ui/main.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ui = MainScript.new()
	ui.size = get_root().size
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(ui)
	await process_frame
	await process_frame
	ui.game.advance_phase()
	ui._refresh_board(false)
	await process_frame

	var policy_index := _first_policy_index(ui.game.countries[0].hand)
	_assert(policy_index >= 0, "country has a playable policy card")
	var card_node: Control = ui.hand_nodes[policy_index]
	_assert(_descendants_ignore_mouse(card_node), "hand card children do not steal card clicks")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	card_node._gui_input(click)
	await process_frame
	_assert(not ui.game.countries[0].selected_policy.is_empty(), "policy card can be placed from the board hand")
	_assert(ui.board_layer.get_node_or_null("PolicyGhost") != null, "policy placement creates a moving card ghost")
	var policy_trail = ui.board_layer.get_node_or_null("BoardTrail")
	_assert(policy_trail != null, "policy placement creates a board trail")
	_assert(_colors_close(policy_trail.color, ui.COUNTRY_ACCENTS[0]), "policy placement trail keeps the submitting country color")
	_assert(ui.country_policy_labels[0].text.contains("伏せ札"), "submitted country policy slot hides selected card before reveal")
	_assert(not ui.country_policy_labels[0].text.contains(String(ui.game.countries[0].selected_policy.get("display_name", ""))), "submitted country policy slot does not leak the selected policy name before reveal")
	_assert(ui.selected_country_index == 1, "policy submission advances focus to the next country")

	ui.game.advance_phase()
	ui._refresh_board(false)
	await process_frame
	ui._on_worker_assigned(0, "diplomat", Vector2(650, 110))
	await process_frame
	_assert(ui.game.countries[0].assigned_worker == "diplomat", "worker token can be assigned from the board")
	_assert(ui.board_layer.get_node_or_null("WorkerGhost") != null, "worker assignment creates a moving token ghost")
	_assert(ui.board_layer.get_node_or_null("BoardTrail") != null, "worker assignment creates a board trail")

	ui._on_country_selected(2)
	await process_frame
	_assert(ui.selected_country_index == 2, "country seat can select another player board hand")
	_assert(ui.board_layer.get_node_or_null("CountryFocusGhost") != null, "country selection creates a moving focus marker")
	_assert(ui.board_layer.get_node_or_null("BoardTrail") != null, "country selection creates a board trail")
	_assert(ui.hand_nodes.size() == ui.game.countries[2].hand.size(), "selected country hand is redealt on the board")

	var previous_phase: int = ui.game.phase_index
	ui._on_advance_pressed()
	await process_frame
	_assert(ui.game.phase_index == previous_phase, "advance token does not skip unfinished worker assignment")
	_assert(ui.selected_country_index != 1, "advance token focuses the next unfinished country")

	var ui2 = MainScript.new()
	ui2.size = get_root().size
	ui2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(ui2)
	await process_frame
	await process_frame
	ui2._hide_entry_overlays()
	ui2.game.advance_phase()
	for country_index in range(ui2.game.countries.size()):
		var plan_index := _first_policy_index(ui2.game.countries[country_index].hand)
		_assert(plan_index >= 0, "policy exists for recommendation worker setup country %d" % country_index)
		ui2.game.select_policy(country_index, plan_index)
	ui2._enter_worker_assignment()
	ui2._on_recommend_pressed()
	await process_frame
	_assert(ui2._all_workers_confirmed(), "recommend helper confirms all worker assignments in UI state")
	ui2._on_advance_pressed()
	await process_frame
	_assert(ui2.game.current_phase() == "simultaneous_reveal", "recommended worker assignments can advance to simultaneous reveal")

	print("Smoke board interaction passed.")
	quit(0)

func _first_policy_index(hand: Array) -> int:
	for i in range(hand.size()):
		if hand[i].get("type", "") == "policy":
			return i
	return -1

func _descendants_ignore_mouse(node: Node) -> bool:
	for child in node.get_children():
		if child is Control and child.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return false
		if not _descendants_ignore_mouse(child):
			return false
	return true

func _colors_close(a: Color, b: Color) -> bool:
	return abs(a.r - b.r) < 0.01 and abs(a.g - b.g) < 0.01 and abs(a.b - b.b) < 0.01

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
