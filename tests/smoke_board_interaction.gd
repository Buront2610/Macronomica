extends SceneTree

const MainScript := preload("res://src/ui/main.gd")
const BoardTrailScript := preload("res://src/ui/support/board_trail.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ui = MainScript.new()
	ui.size = get_root().size
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(ui)
	await process_frame
	await process_frame
	ui.game.log.append("世界恐慌トラックが 1 変化しました。")
	ui._refresh_board(false)
	var log_click := InputEventMouseButton.new()
	log_click.button_index = MOUSE_BUTTON_LEFT
	log_click.pressed = false
	ui.board_layer.get_node("LogPanel")._gui_input(log_click)
	await process_frame
	_assert(ui.log_highlight_key == "depression", "news log click highlights the related world track")
	_assert(ui.turn_news_active and ui.turn_news_panel.visible, "news log click opens the newspaper drawer")
	ui._hide_turn_news_overlay()
	var agenda_tile: Control = ui.board_layer.get_node("Agenda_cooperation")
	var agenda_click := InputEventMouseButton.new()
	agenda_click.button_index = MOUSE_BUTTON_LEFT
	agenda_click.pressed = false
	agenda_tile._gui_input(agenda_click)
	await process_frame
	_assert(ui.game.countries[0].declared_agenda == "cooperation", "agenda tile places a joint declaration for the selected country")
	_assert(ui.selected_country_index == 1, "agenda declaration advances focus to the next undeclared country")
	_assert(_agenda_filled_pip_count(ui, "cooperation") == 1, "joint declaration pips are public during negotiation")
	ui.game.countries[0].declared_agenda = ""
	ui.selected_country_index = 0
	ui.game.advance_phase()
	ui._refresh_board(false)
	await process_frame

	var policy_index := _first_policy_index(ui.game.policy_options(0))
	_assert(policy_index >= 0, "country has a playable policy card")
	var card_node: Control = ui.policy_menu_nodes[policy_index]
	_assert(_descendants_ignore_mouse(card_node), "policy menu card children do not steal card clicks")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	card_node._gui_input(click)
	await process_frame
	_assert(not ui.game.countries[0].selected_policy.is_empty(), "policy can be placed from the board policy menu")
	if String(ui.game.countries[0].selected_policy.get("target", "")) == "country":
		_assert(ui.selected_country_index == 0, "targeted policy keeps focus until a target country is chosen")
		ui._on_country_selected(1)
		await process_frame
		_assert(ui.game.countries[0].selected_target_index == 1, "targeted policy can choose a target country from the board")
	_assert(ui.board_layer.get_node_or_null("PolicyGhost") == null, "policy placement avoids a full-size moving card ghost")
	_assert(_first_board_trail(ui) == null, "policy placement avoids noisy board trails")
	_assert(ui.country_policy_labels[0].text.contains("伏せ札"), "submitted country policy slot hides selected card before reveal")
	_assert(not ui.country_policy_labels[0].text.contains(String(ui.game.countries[0].selected_policy.get("display_name", ""))), "submitted country policy slot does not leak the selected policy name before reveal")
	var hidden_policy: Dictionary = ui.game.countries[0].selected_policy.duplicate(true)
	hidden_policy["tags"] = ["cooperation"]
	ui.game.countries[0].selected_policy = hidden_policy
	ui._refresh_board(false)
	await process_frame
	_assert(_agenda_filled_pip_count(ui, "cooperation") == 0, "agenda pips do not leak planned policy tags before reveal")
	ui.game.reveal_policies()
	ui._refresh_board(false)
	await process_frame
	_assert(_agenda_filled_pip_count(ui, "cooperation") > 0, "agenda pips show planned policy tags after reveal")
	ui.game.set_policies_revealed(false)
	_assert(ui.selected_country_index == 1, "policy submission advances focus to the next country")

	ui._enter_worker_assignment()
	ui._refresh_board(false)
	await process_frame
	ui._on_worker_assigned(0, "diplomat", Vector2(650, 110))
	await process_frame
	_assert(ui.game.countries[0].assigned_worker_list().has("diplomat"), "worker token can be assigned from the board")
	_assert(ui.board_layer.get_node_or_null("WorkerGhost") != null, "worker assignment creates a moving token ghost")
	_assert(_first_board_trail(ui) != null, "worker assignment creates a board trail")
	ui._on_worker_assigned(0, "lobbyist", Vector2(922, 110))
	await process_frame
	_assert(ui.game.countries[0].assigned_worker_list().has("diplomat") and ui.game.countries[0].assigned_worker_list().has("lobbyist"), "multiple worker tokens can attach to one country")
	_assert(ui.selected_country_index == 0, "multiple worker selection keeps focus on the same country until advanced")
	ui._on_advance_pressed()
	await process_frame
	_assert(ui.selected_country_index == 1, "advance confirms worker allocation and moves to the next country")

	ui._on_country_selected(2)
	await process_frame
	_assert(ui.selected_country_index == 2, "country seat can select another player policy menu")
	_assert(ui.board_layer.get_node_or_null("CountryFocusGhost") != null, "country selection creates a moving focus marker")
	_assert(_first_board_trail(ui) != null, "country selection creates a board trail")
	_assert(ui.policy_menu_nodes.is_empty(), "worker assignment hides the policy menu to keep the board operable")

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
		var plan_index := _first_policy_index(ui2.game.policy_options(country_index))
		_assert(plan_index >= 0, "policy exists for recommendation worker setup country %d" % country_index)
		ui2.game.select_policy(country_index, plan_index)
	ui2._enter_worker_assignment()
	ui2._on_recommend_pressed()
	await process_frame
	_assert(ui2._all_workers_confirmed(), "recommend helper confirms all worker assignments in UI state")
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

func _agenda_filled_pip_count(ui, tag: String) -> int:
	var pips: Control = ui.board_layer.get_node("Agenda_%s/AgendaPips" % tag)
	var count := 0
	for child in pips.get_children():
		if not _colors_close(child.fill, ui.TOKEN_EMPTY):
			count += 1
	return count

func _first_board_trail(ui):
	for child in ui.board_layer.get_children():
		if child is BoardTrailScript or String(child.name).contains("BoardTrail"):
			return child
	return null

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
