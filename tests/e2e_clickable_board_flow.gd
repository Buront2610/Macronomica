extends SceneTree

const MainScript := preload("res://src/ui/main.gd")

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1920, 1080)
	var ui = MainScript.new()
	ui.size = get_root().size
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(ui)
	await _settle()

	_click(ui.title_overlay.get_node("TitleStart"))
	await _settle()
	_assert(ui.country_select_overlay.visible, "start click opens country selection")
	_click(ui.country_select_overlay.get_node("CountryChoice_0"))
	await _settle()
	_assert(ui.game.current_phase() == "negotiation", "country click enters negotiation")
	_assert(ui.selected_country_index == 0, "country click focuses selected country")

	_click(ui.board_layer.get_node("AdvanceToken"))
	await _settle()
	_assert(ui.game.current_phase() == "policy_planning", "advance click enters policy planning")
	_assert(_policy_menu_visible(ui), "policy menu is visible and explicitly labeled")
	_assert(_state_cards_visible(ui), "state hand cards are visible on country mats")

	for country_index in range(ui.game.countries.size()):
		_assert(ui.selected_country_index == country_index, "policy planning focuses country %d" % country_index)
		var policy_index := _first_simple_policy_index(ui.game.countries[country_index].policy_menu)
		_assert(policy_index >= 0, "country %d has a non-target policy for click flow" % country_index)
		_click(ui.hand_nodes[policy_index])
		await _settle()
		_assert(not ui.game.countries[country_index].selected_policy.is_empty(), "country %d policy card click submits policy" % country_index)

	_assert(ui.game.current_phase() == "worker_assignment", "policy clicks enter worker assignment")
	for country_index in range(ui.game.countries.size()):
		_assert(ui.selected_country_index == country_index, "worker assignment focuses country %d" % country_index)
		_click(ui.worker_nodes["bureaucrats"])
		await _settle()
		_assert(ui.game.countries[country_index].assigned_worker_list().has("bureaucrats"), "country %d worker token click assigns worker" % country_index)
		_click(ui.board_layer.get_node("AdvanceToken"))
		await _settle()

	_assert(ui.game.current_phase() == "simultaneous_reveal", "worker clicks reach simultaneous reveal")
	_click(ui.board_layer.get_node("AdvanceToken"))
	await _settle()
	_assert(ui.game.current_phase() == "resolution", "advance click opens resolution review")
	_assert(ui.resolution_review_active, "resolution review is active after click")

	for i in range(6):
		_click(ui.board_layer.get_node("AdvanceToken"))
		await _settle()
	_assert(ui.game.turn == 2, "clicking through resolution resolves the turn")
	_assert(ui.turn_news_active, "turn newspaper appears after clicked resolution flow")

	if failed:
		quit(1)
	else:
		print("E2E clickable board flow passed.")
		quit(0)

func _click(control: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	control._gui_input(click)

func _settle() -> void:
	for i in range(3):
		await process_frame

func _first_simple_policy_index(cards: Array) -> int:
	for i in range(cards.size()):
		var card: Dictionary = cards[i]
		if String(card.get("type", "")) == "policy" and String(card.get("target", "")) != "country":
			return i
	return -1

func _policy_menu_visible(ui) -> bool:
	var panel: Control = ui.board_layer.get_node_or_null("HandPanel")
	if panel == null or not panel.visible:
		return false
	var title: Label = panel.get_node_or_null("PolicyMenuTitle")
	if title == null or not title.text.contains("政策メニュー"):
		return false
	return ui.hand_nodes.size() >= 8 and String(ui.hand_nodes[0].name).begins_with("PolicyMenuCard")

func _state_cards_visible(ui) -> bool:
	for i in range(ui.game.countries.size()):
		var seat: Control = ui.country_seats[i]
		var state_card: Control = seat.get_node_or_null("StateHandCard")
		if state_card == null or not state_card.visible:
			return false
		var label: Label = state_card.get_node_or_null("StateHandLabel")
		if label == null or not label.text.contains("状態手札"):
			return false
	return true

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
