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
	_assert(ui.board_layer.get_node_or_null("BoardTrail") != null, "policy placement creates a board trail")
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

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
