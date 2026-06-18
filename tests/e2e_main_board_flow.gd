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

	ui.game.advance_phase()
	ui._refresh_board(false)
	await process_frame
	_assert(ui.game.current_phase() == "policy_planning", "E2E reaches policy planning")
	_assert(_major_icons_are_visible_and_inside(ui), "major icons are visible and stay inside their frames")
	_assert(_major_icons_are_pixel_snapped(ui), "major icons are snapped to whole pixels")

	for country_index in range(ui.game.countries.size()):
		_assert(ui.selected_country_index == country_index, "policy planning focuses country %d automatically" % country_index)
		var menu_title: Label = ui.board_layer.get_node_or_null("PolicyMenuPanel/PolicyMenuTitle")
		_assert(menu_title != null and menu_title.text.contains("%s国" % String.chr(65 + country_index)), "large policy shelf title switches to country %d" % country_index)
		_assert(ui.planning_country_panel == null or not ui.planning_country_panel.visible, "small active country frame is removed from focused planning")
		var policy_index := _first_policy_index(ui.game.countries[country_index].policy_menu)
		_assert(policy_index >= 0, "country %d has a playable policy card" % country_index)
		var card_node: Control = ui.policy_menu_nodes[policy_index]
		_assert(_control_min_size(card_node, Vector2(220, 158)), "policy card is a large planning tile: %s" % card_node.name)
		_assert(_policy_card_icon_is_large(card_node), "policy menu card uses a large readable icon: %s" % card_node.name)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = false
		card_node._gui_input(click)
		await process_frame
		_assert(not ui.game.countries[country_index].selected_policy.is_empty(), "country %d can submit a policy through the policy menu" % country_index)

	_assert(ui.game.current_phase() == "worker_assignment", "E2E auto-reaches worker assignment after all policies")
	_assert(ui.selected_country_index == 0, "worker assignment returns focus to country 0")

	var workers := ["bureaucrats", "central_bank_staff", "diplomat", "auditor"]
	for country_index in range(ui.game.countries.size()):
		_assert(ui.selected_country_index == country_index, "worker assignment focuses country %d automatically" % country_index)
		ui._on_worker_assigned(country_index, workers[country_index % workers.size()], ui.worker_nodes[workers[country_index % workers.size()]].position)
		await process_frame
		_assert(ui.game.countries[country_index].assigned_worker_list().has(workers[country_index % workers.size()]), "country %d can place a worker stamp" % country_index)
		if country_index == 0:
			ui._on_worker_assigned(country_index, "diplomat", ui.worker_nodes["diplomat"].position)
			await process_frame
			_assert(ui.game.countries[country_index].assigned_worker_list().size() >= 2, "country %d can place multiple worker stamps" % country_index)
		_assert(_control_min_size(ui.country_stamp_slots[country_index], Vector2(42, 42)), "stamp slot remains readable for country %d" % country_index)
		ui._on_advance_pressed()
		await process_frame

	_assert(ui.game.current_phase() == "simultaneous_reveal", "E2E auto-reaches simultaneous reveal after all worker stamps")
	for country_index in range(ui.game.countries.size()):
		var hidden_policy_name := String(ui.game.countries[country_index].selected_policy.get("display_name", ""))
		_assert(not ui.country_policy_labels[country_index].text.contains(hidden_policy_name), "simultaneous reveal wait does not leak policy name for country %d" % country_index)
	_assert(ui.resolution_step_labels[1].text.contains("未"), "resolution flow does not reveal costs before simultaneous reveal")
	ui._on_advance_pressed()
	await process_frame
	_assert(ui.game.current_phase() == "resolution", "simultaneous reveal opens resolution review")
	_assert(ui.resolution_review_active, "resolution review stays on the board before resolving the turn")
	_assert(ui.resolution_step_index == 0, "resolution review starts at pressure step")
	_assert(not ui.last_resolution_snapshot.is_empty(), "resolution keeps a board snapshot after simultaneous reveal")
	_assert(ui.last_resolution_snapshot.get("items", []).size() == 4, "resolution snapshot covers all four countries")
	_assert(ui.resolution_step_nodes.size() == 6, "resolution flow shows six board steps")
	_assert(ui.resolution_overlay != null and ui.resolution_overlay.paths.size() >= 1, "resolution overlay draws focused board result links")
	var first_item: Dictionary = ui.last_resolution_snapshot.get("items", [])[0]
	_assert(first_item.has("country_diffs") and first_item.has("world_diff"), "resolution snapshot is based on actual outcome diffs")
	for i in range(ui.resolution_step_nodes.size()):
		var step: Control = ui.resolution_step_nodes[i]
		_assert(_control_min_size(step, Vector2(70, 34)), "resolution step remains readable: %s" % step.name)
		var label: Label = ui.resolution_step_labels[i]
		_assert(not label.text.is_empty() and label.text != "-", "resolution step has visible result text: %s" % step.name)
	for expected_step in range(1, 6):
		ui._on_advance_pressed()
		await process_frame
		_assert(ui.resolution_review_active, "resolution review remains active at step %d" % expected_step)
		_assert(ui.resolution_step_index == expected_step, "resolution review advances to step %d" % expected_step)
		_assert(ui.resolution_overlay.paths.size() >= 1, "resolution step %d keeps a visible board link" % expected_step)
		if expected_step >= 2:
			_assert(ui.resolution_marker_layer.get_child_count() >= 1, "resolution step %d shows result chips" % expected_step)
	for marker in ui.resolution_marker_layer.get_children():
		_assert(marker is Control and _control_min_size(marker, Vector2(26, 26)), "resolution marker remains visible: %s" % marker.name)
	ui._on_advance_pressed()
	await process_frame
	_assert(not ui.resolution_review_active, "final resolution advance closes review")
	_assert(ui.game.turn == 2, "final resolution advance resolves the turn and starts the next turn")
	_assert(ui.game.current_phase() == "negotiation", "next turn returns to the main board negotiation phase")
	_assert(ui.turn_news_active and ui.turn_news_panel.visible, "turn result newspaper appears after resolution")
	ui._on_advance_pressed()
	await process_frame
	_assert(not ui.turn_news_active and not ui.turn_news_panel.visible, "advance closes the turn result newspaper")

	var log_panel: Label = ui.log_panel
	_assert(log_panel != null and log_panel.text.contains("・"), "newspaper shows summarized headlines")
	_assert(_control_min_size(ui.board_layer.get_node("AdvanceToken"), Vector2(104, 104)), "advance token is a large primary action")
	_assert(_control_min_size(ui.board_layer.get_node("ResolutionFlow"), Vector2(520, 48)), "resolution flow has enough physical size")

	if failed:
		quit(1)
	else:
		print("E2E main board flow passed.")
		quit(0)

func _first_policy_index(hand: Array) -> int:
	for i in range(hand.size()):
		if hand[i].get("type", "") == "policy":
			return i
	return -1

func _control_min_size(control: Control, minimum: Vector2) -> bool:
	return control.size.x >= minimum.x and control.size.y >= minimum.y

func _policy_card_icon_is_large(card_node: Control) -> bool:
	var icon: TextureRect = card_node.get_node_or_null("CardCoin")
	if icon == null:
		push_error("Policy card has no CardCoin icon: %s" % card_node.name)
		return false
	return icon.size.x >= 56.0 and icon.size.y >= 56.0

func _major_icons_are_visible_and_inside(ui) -> bool:
	for icon in _collect_texture_rects(ui):
		if not icon.visible:
			continue
		if icon.size.x < 32.0 or icon.size.y < 32.0:
			push_error("Icon is too small: %s size=%s" % [icon.get_path(), icon.size])
			return false
		var parent: Node = icon.get_parent()
		if parent is Control:
			var icon_rect := Rect2(icon.global_position, icon.size)
			var parent_rect := Rect2(parent.global_position, parent.size).grow(1.0)
			if not parent_rect.encloses(icon_rect):
				push_error("Icon is outside parent: %s icon=%s parent=%s" % [icon.get_path(), icon_rect, parent_rect])
				return false
	return true

func _major_icons_are_pixel_snapped(ui) -> bool:
	for icon in _collect_texture_rects(ui):
		if not icon.visible:
			continue
		if _has_transient_ancestor(icon):
			continue
		var pos: Vector2 = icon.global_position
		var size: Vector2 = icon.size
		if absf(pos.x - roundf(pos.x)) > 0.01 or absf(pos.y - roundf(pos.y)) > 0.01:
			push_error("Icon is on a fractional pixel: %s pos=%s" % [icon.get_path(), pos])
			return false
		if absf(size.x - roundf(size.x)) > 0.01 or absf(size.y - roundf(size.y)) > 0.01:
			push_error("Icon has fractional size: %s size=%s" % [icon.get_path(), size])
			return false
	return true

func _has_transient_ancestor(node: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if String(current.name).contains("Ghost"):
			return true
		current = current.get_parent()
	return false

func _collect_texture_rects(node: Node) -> Array:
	var icons := []
	if node is TextureRect:
		icons.append(node)
	for child in node.get_children():
		icons.append_array(_collect_texture_rects(child))
	return icons

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
