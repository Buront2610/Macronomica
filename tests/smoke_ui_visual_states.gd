extends SceneTree

const MainScript := preload("res://src/ui/main.gd")

var had_failure := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var sizes := [Vector2i(1920, 1080), Vector2i(1280, 720)]
	var states := ["default", "worker_assignment", "resolution", "final"]
	for viewport_size in sizes:
		get_root().size = viewport_size
		await process_frame
		for state in states:
			await _check_state(viewport_size, state)
	if had_failure:
		print("Smoke UI visual states failed.")
		quit(1)
	else:
		print("Smoke UI visual states passed.")
		quit(0)

func _check_state(viewport_size: Vector2i, state: String) -> void:
	var ui = MainScript.new()
	ui.size = Vector2(viewport_size)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(ui)
	for i in range(4):
		await process_frame
	ui._hide_entry_overlays()
	ui.game.advance_phase()
	ui._refresh_board(false)
	if state == "worker_assignment":
		_prepare_worker_assignment(ui)
	elif state == "resolution":
		_prepare_resolution(ui)
	elif state == "final":
		_prepare_final(ui)
	ui._refresh_board(false)
	for i in range(3):
		await process_frame

	var viewport := Rect2(Vector2.ZERO, ui.get_viewport_rect().size)
	_assert(ui.board_layer != null, "%s %s has board layer" % [state, viewport_size])
	_assert(ui.country_seats.size() == 4, "%s %s keeps four country seats" % [state, viewport_size])
	if state == "default":
		_assert(ui.policy_menu_nodes.size() == ui.game.countries[ui.selected_country_index].policy_menu.size(), "%s %s shows the selected policy menu" % [state, viewport_size])
	else:
		_assert(ui.policy_menu_nodes.is_empty(), "%s %s hides policy menu outside policy planning" % [state, viewport_size])
	for node_name in ["WorldPanel", "EventCard", "PolicySlot", "ResolutionFlow", "DomesticStatePanel", "PolicyPreviewPanel", "ScorePanel", "LogPanel", "CountryDetailPanel"]:
		var node: Control = ui.board_layer.get_node_or_null(node_name)
		_assert(node != null, "%s %s has %s" % [state, viewport_size, node_name])
		if node != null and node.visible:
			_assert(_inside_viewport(node, viewport), "%s %s keeps %s inside viewport" % [state, viewport_size, node_name])
	var collapse_warning: Control = ui.board_layer.get_node_or_null("CollapseWarning")
	_assert(collapse_warning != null, "%s %s has collapse warning node" % [state, viewport_size])
	if state == "resolution" and collapse_warning != null:
		_assert(collapse_warning.visible, "%s %s shows collapse warning at depression 8" % [state, viewport_size])
	for seat in ui.country_seats:
		if seat.visible:
			_assert(_inside_viewport(seat, viewport), "%s %s keeps country seat inside viewport: %s" % [state, viewport_size, seat.name])
		for label_name in ["NextDeckLabel", "PipelineLabel", "ElectionLabel", "WelfareLabel"]:
			var info_label: Label = seat.get_node_or_null(label_name)
			_assert(info_label != null and not info_label.text.is_empty(), "%s %s keeps %s populated on %s" % [state, viewport_size, label_name, seat.name])
	for card in ui.policy_menu_nodes:
		_assert(_inside_viewport(card, viewport), "%s %s keeps policy menu card inside viewport: %s" % [state, viewport_size, card.name])
	for token_name in ["RestartToken", "RecommendToken", "AdvanceToken"]:
		var token: Control = ui.board_layer.get_node_or_null(token_name)
		_assert(token != null and _inside_viewport(token, viewport), "%s %s keeps action token inside viewport: %s" % [state, viewport_size, token_name])
	var final_overlay: Control = ui.board_layer.get_node_or_null("FinalScoreOverlay")
	_assert(final_overlay != null, "%s %s has final overlay node" % [state, viewport_size])
	if final_overlay != null:
		_assert(final_overlay.visible == (state == "final"), "%s %s final overlay visibility matches state" % [state, viewport_size])
		if final_overlay.visible:
			_assert(_inside_viewport(final_overlay, viewport), "%s %s keeps final overlay inside viewport" % [state, viewport_size])
			_assert(not _label_text(final_overlay, "FinalScoreTitle").is_empty(), "%s %s final title is populated" % [state, viewport_size])
	ui.queue_free()
	await process_frame

func _prepare_worker_assignment(ui) -> void:
	for country_index in range(ui.game.countries.size()):
		var policy_index := _first_policy_index(ui.game.countries[country_index].policy_menu)
		if policy_index >= 0:
			ui.game.select_policy(country_index, policy_index)
	ui.game.move_to_phase("worker_assignment")
	ui._reset_worker_confirmations()

func _prepare_resolution(ui) -> void:
	_prepare_worker_assignment(ui)
	var workers := ["bureaucrats", "central_bank_staff", "diplomat", "auditor"]
	for country_index in range(ui.game.countries.size()):
		ui.game.assign_worker(country_index, workers[country_index % workers.size()])
		ui.worker_assignment_confirmed[country_index] = true
	ui.game.move_to_phase("resolution")
	ui.game.world.tracks["depression"] = 8
	ui.last_resolution_snapshot = ui._capture_resolution_snapshot()
	ui.resolution_review_active = true
	ui.resolution_step_index = 2

func _prepare_final(ui) -> void:
	_prepare_resolution(ui)
	ui.game.turn_limit = 1
	ui.game.turn = 1
	ui.resolution_step_index = 5
	ui._advance_resolution_review()

func _first_policy_index(hand: Array) -> int:
	for i in range(hand.size()):
		if hand[i].get("type", "") == "policy":
			return i
	return -1

func _inside_viewport(control: Control, viewport: Rect2) -> bool:
	return viewport.encloses(Rect2(control.global_position, control.size))

func _label_text(parent: Node, path: String) -> String:
	var label: Label = parent.get_node_or_null(path)
	return "" if label == null else label.text

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	had_failure = true
	push_error(message)
