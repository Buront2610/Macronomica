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

	var policy_index := _first_policy_index(ui.game.countries[0].hand)
	_assert(policy_index >= 0, "country has a playable policy card")
	ui._on_policy_selected(0, policy_index, Vector2(180, 620))
	await process_frame
	_assert(not ui.game.countries[0].selected_policy.is_empty(), "policy card can be placed from the board hand")
	_assert(ui.board_layer.get_node_or_null("PolicyGhost") != null, "policy placement creates a moving card ghost")
	_assert(ui.board_layer.get_node_or_null("BoardTrail") != null, "policy placement creates a board trail")
	_assert(ui.policy_slot_label.text != "政策案なし\n手札からカードを伏せます", "policy slot reflects selected card")

	ui._on_worker_assigned(0, "diplomat", Vector2(650, 110))
	await process_frame
	_assert(ui.game.countries[0].assigned_worker == "diplomat", "worker token can be assigned from the board")
	_assert(ui.board_layer.get_node_or_null("WorkerGhost") != null, "worker assignment creates a moving token ghost")
	_assert(ui.board_layer.get_node_or_null("BoardTrail") != null, "worker assignment creates a board trail")

	ui._on_country_selected(1)
	await process_frame
	_assert(ui.selected_country_index == 1, "country seat can select another player board hand")
	_assert(ui.board_layer.get_node_or_null("CountryFocusGhost") != null, "country selection creates a moving focus marker")
	_assert(ui.board_layer.get_node_or_null("BoardTrail") != null, "country selection creates a board trail")
	_assert(ui.hand_nodes.size() == ui.game.countries[1].hand.size(), "selected country hand is redealt on the board")

	var previous_phase: int = ui.game.phase_index
	ui._on_advance_pressed()
	await process_frame
	_assert(ui.game.phase_index != previous_phase, "advance token changes the game phase")
	_assert(ui.board_layer.get_node_or_null("PhaseGhost") != null, "advance token creates a moving phase marker")
	_assert(ui.board_layer.get_node_or_null("BoardTrail") != null, "advance token creates a board trail")

	print("Smoke board interaction passed.")
	quit(0)

func _first_policy_index(hand: Array) -> int:
	for i in range(hand.size()):
		if hand[i].get("type", "") == "policy":
			return i
	return -1

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
