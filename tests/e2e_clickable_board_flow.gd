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
	_assert(_policy_agenda_shelf_visible(ui), "policy agenda shelf is visible and explicitly labeled")

	_click(ui.board_layer.get_node("RecommendToken"))
	await _settle()
	_assert(ui.game.current_phase() == "worker_assignment", "testplay auto selects all policies and enters worker assignment")
	for country_index in range(ui.game.countries.size()):
		_assert(not ui.game.countries[country_index].selected_policy.is_empty(), "auto policy chooses for country %d" % country_index)

	_click(ui.board_layer.get_node("RecommendToken"))
	await _settle()
	_assert(ui.game.current_phase() == "simultaneous_reveal", "testplay auto assigns all workers and enters reveal")
	for country_index in range(ui.game.countries.size()):
		_assert(ui.game.countries[country_index].assigned_worker_list().size() >= 1, "auto worker assigns for country %d" % country_index)

	_click(ui.board_layer.get_node("AdvanceToken"))
	await _settle()
	_assert(ui.game.current_phase() == "resolution", "advance click opens resolution review")
	_assert(ui.resolution_review_active, "resolution review is active after click")

	_click(ui.board_layer.get_node("RecommendToken"))
	await _settle()
	_assert(ui.game.turn == 2, "testplay auto resolves the turn")
	_assert(ui.turn_news_active, "turn newspaper appears after auto resolution")

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

func _policy_agenda_shelf_visible(ui) -> bool:
	var panel: Control = ui.board_layer.get_node_or_null("PolicyMenuPanel")
	if panel == null or not panel.visible:
		return false
	var title: Label = panel.get_node_or_null("PolicyMenuTitle")
	if title == null or not title.text.contains("政策議題"):
		return false
	return true

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
