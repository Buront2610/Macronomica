extends SceneTree

const MainScript := preload("res://src/ui/main.gd")

var failures := []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var states := ["policy_planning", "worker_assignment", "resolution", "final"]
	for state in states:
		await _audit_state(state)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
	else:
		print("UI label fit audit passed.")
		quit(0)

func _audit_state(state: String) -> void:
	get_root().size = Vector2i(1920, 1080)
	var ui = MainScript.new()
	ui.size = Vector2(1920, 1080)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(ui)
	await _settle()
	ui._hide_entry_overlays()
	ui.game.move_to_phase("policy_planning")
	if state == "worker_assignment":
		_prepare_worker_assignment(ui)
	elif state == "resolution":
		_prepare_resolution(ui)
	elif state == "final":
		_prepare_final(ui)
	ui._refresh_board(false)
	await _settle()
	_audit_node(ui, state)
	ui.queue_free()
	await _settle()

func _prepare_worker_assignment(ui) -> void:
	for country_index in range(ui.game.countries.size()):
		var policy_index := _first_simple_policy_index(ui.game.policy_options(country_index))
		if policy_index >= 0:
			ui.game.select_policy(country_index, policy_index)
	ui.game.move_to_phase("worker_assignment")
	ui._reset_worker_confirmations()

func _prepare_resolution(ui) -> void:
	_prepare_worker_assignment(ui)
	for country_index in range(ui.game.countries.size()):
		ui.game.assign_worker(country_index, "bureaucrats")
		ui.worker_assignment_confirmed[country_index] = true
	ui.game.move_to_phase("resolution")
	ui.last_resolution_snapshot = ui._capture_resolution_snapshot()
	ui.resolution_review_active = true
	ui.resolution_step_index = 2

func _prepare_final(ui) -> void:
	_prepare_resolution(ui)
	ui.game.turn_limit = 1
	ui.game.turn = 1
	ui.resolution_step_index = 5
	ui._advance_resolution_review()

func _first_simple_policy_index(cards: Array) -> int:
	for i in range(cards.size()):
		var card: Dictionary = cards[i]
		if String(card.get("type", "")) == "policy" and String(card.get("target", "")) != "country":
			return i
	return -1

func _audit_node(node: Node, state: String) -> void:
	if node is Label:
		_audit_label(node, state)
	for child in node.get_children():
		_audit_node(child, state)

func _audit_label(label: Label, state: String) -> void:
	if not label.visible or not label.is_visible_in_tree():
		return
	if label.text.strip_edges().is_empty():
		return
	if label.size.x <= 0 or label.size.y <= 0:
		return
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var line_height := font.get_height(font_size)
	var estimated_lines := 0
	var max_line_width := 0.0
	for raw_line in label.text.split("\n"):
		var line := String(raw_line)
		var line_width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		max_line_width = maxf(max_line_width, line_width)
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			estimated_lines += 1
		else:
			estimated_lines += maxi(1, ceili(line_width / maxf(1.0, label.size.x)))
	var estimated_height := float(estimated_lines) * line_height
	var path := String(label.get_path())
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF and max_line_width > label.size.x + 2.0 and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
		failures.append("%s text overflows without ellipsis: %s width=%.1f rect=%.1f text=%s" % [state, path, max_line_width, label.size.x, label.text])
	if estimated_height > label.size.y + line_height * 0.25:
		failures.append("%s label likely clips: %s h=%.1f rect=%.1f text=%s" % [state, path, estimated_height, label.size.y, label.text.replace("\n", " / ")])

func _settle() -> void:
	for i in range(8):
		await process_frame
