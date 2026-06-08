extends SceneTree

const MainScript := preload("res://src/ui/main.gd")

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var ui = MainScript.new()
	ui.size = get_root().size
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(ui)
	await process_frame
	await process_frame

	ui.game.turn_limit = 1
	ui.game.advance_phase()
	ui._refresh_board(false)
	await process_frame

	for country_index in range(ui.game.countries.size()):
		var policy_index := _first_policy_index(ui.game.countries[country_index].hand)
		_assert(policy_index >= 0, "country %d has a policy card" % country_index)
		var card: Control = ui.hand_nodes[policy_index]
		ui._on_policy_selected(country_index, policy_index, card.position)
		await process_frame

	var workers := ["bureaucrats", "central_bank_staff", "diplomat", "auditor"]
	for country_index in range(ui.game.countries.size()):
		ui._on_worker_assigned(country_index, workers[country_index % workers.size()], ui.worker_nodes[workers[country_index % workers.size()]].position)
		await process_frame

	_assert(ui.game.current_phase() == "simultaneous_reveal", "final-score E2E reaches simultaneous reveal")
	ui._on_advance_pressed()
	await process_frame
	for _i in range(5):
		ui._on_advance_pressed()
		await process_frame

	_assert(ui.game.is_finished, "one-turn game finishes after resolution review")
	_assert(ui.final_score_panel != null and ui.final_score_panel.visible, "final score overlay appears")
	_assert(ui.final_score_labels.size() == 4, "final score overlay has four country result cards")
	for label in ui.final_score_labels:
		_assert(label.text.contains("点"), "final score card shows score text")
		_assert(label.text.contains("レガシー"), "final score card shows legacy text")
	_assert(ui.final_news_label != null and ui.final_news_label.text.contains("・"), "final score overlay shows newspaper summary")

	if failed:
		quit(1)
	else:
		print("E2E final score overlay passed.")
		quit(0)

func _first_policy_index(hand: Array) -> int:
	for i in range(hand.size()):
		if hand[i].get("type", "") == "policy":
			return i
	return -1

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
