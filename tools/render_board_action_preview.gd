extends SceneTree

const MainScript := preload("res://src/ui/main.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var width := int(OS.get_environment("MACRONOMICA_PREVIEW_WIDTH"))
	var height := int(OS.get_environment("MACRONOMICA_PREVIEW_HEIGHT"))
	if width > 0 and height > 0:
		get_root().size = Vector2i(width, height)
		await process_frame
	var ui = MainScript.new()
	ui.size = get_root().size
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(ui)
	for i in range(5):
		await process_frame
	var preview_state := OS.get_environment("MACRONOMICA_PREVIEW_STATE")
	if preview_state == "title":
		_save_preview()
		return
	if preview_state == "country_select":
		ui._show_country_select()
		await process_frame
		_save_preview()
		return
	ui._hide_entry_overlays()

	ui.game.advance_phase()
	ui._refresh_board(false)
	if preview_state == "policy_submitted":
		_prepare_policy_submitted_preview(ui)
		ui._refresh_board(false)
		await process_frame
		await process_frame
		_save_preview()
		return
	if preview_state == "worker_assignment":
		_prepare_worker_assignment_preview(ui)
		ui._refresh_board(false)
		await process_frame
		await process_frame
		_save_preview()
		return
	if preview_state == "simultaneous_reveal":
		_prepare_simultaneous_reveal_preview(ui)
		ui._refresh_board(false)
		await process_frame
		await process_frame
		_save_preview()
		return
	if preview_state == "final":
		_prepare_final_preview(ui)
		ui._refresh_board(false)
		await process_frame
		await process_frame
		_save_preview()
		return
	if preview_state == "turn_news":
		_prepare_turn_news_preview(ui)
		ui._refresh_board(false)
		ui._show_turn_news_overlay()
		await process_frame
		await process_frame
		_save_preview()
		return
	if preview_state == "resolution":
		_prepare_resolution_preview(ui)
		ui._refresh_board(false)
		await process_frame
		await process_frame
		_save_preview()
		return
	await process_frame
	if OS.get_environment("MACRONOMICA_PREVIEW_ACTION") != "0":
		var policy_index := _first_policy_index(ui.game.countries[0].hand)
		if policy_index >= 0:
			var card_node: Control = ui.hand_nodes[policy_index]
			ui._on_policy_selected(0, policy_index, card_node.position)
		for i in range(3):
			await process_frame

	_save_preview()

func _save_preview() -> void:
	var path := OS.get_environment("MACRONOMICA_PREVIEW_PATH")
	if path.is_empty():
		path = "res://tmp/screenshots/board_action_preview.png"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image := get_root().get_texture().get_image()
	image.save_png(path)
	print("Board action preview saved: %s" % path)
	quit(0)

func _prepare_policy_submitted_preview(ui) -> void:
	var policy_index := _first_policy_index(ui.game.countries[0].hand)
	if policy_index >= 0:
		ui.game.select_policy(0, policy_index)
	ui.selected_country_index = 1

func _prepare_worker_assignment_preview(ui) -> void:
	for country_index in range(ui.game.countries.size()):
		var policy_index := _first_policy_index(ui.game.countries[country_index].hand)
		if policy_index >= 0:
			ui.game.select_policy(country_index, policy_index)
	ui._set_game_phase("worker_assignment")
	ui._reset_worker_confirmations()
	ui.selected_country_index = 0

func _prepare_simultaneous_reveal_preview(ui) -> void:
	_prepare_worker_assignment_preview(ui)
	var workers := ["bureaucrats", "central_bank_staff", "diplomat", "auditor"]
	for country_index in range(ui.game.countries.size()):
		ui.game.assign_worker(country_index, workers[country_index % workers.size()])
		ui.worker_assignment_confirmed[country_index] = true
	ui._set_game_phase("simultaneous_reveal")
	ui.selected_country_index = 0

func _prepare_resolution_preview(ui) -> void:
	_prepare_simultaneous_reveal_preview(ui)
	ui._set_game_phase("resolution")
	ui.game.revealed_policies = true
	ui.last_resolution_snapshot = ui._capture_resolution_snapshot()
	ui.resolution_review_active = true
	ui.resolution_step_index = clampi(int(OS.get_environment("MACRONOMICA_PREVIEW_RESOLUTION_STEP")), 0, 5)
	ui.selected_country_index = 0

func _prepare_final_preview(ui) -> void:
	_prepare_resolution_preview(ui)
	ui.game.turn_limit = 1
	ui.game.turn = 1
	ui.resolution_step_index = 5
	ui._advance_resolution_review()

func _prepare_turn_news_preview(ui) -> void:
	_prepare_resolution_preview(ui)
	ui.resolution_step_index = 5
	ui._advance_resolution_review()

func _first_policy_index(hand: Array) -> int:
	for i in range(hand.size()):
		if hand[i].get("type", "") == "policy":
			return i
	return -1
