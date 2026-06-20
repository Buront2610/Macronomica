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

	_assert(ui.title_overlay != null and ui.title_overlay.visible, "entry flow starts on title overlay")
	_assert(ui.title_overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "title overlay blocks board input behind it")
	_assert(ui.tutorial_overlay != null and not ui.tutorial_overlay.visible, "tutorial overlay is hidden on title")
	_assert(ui.country_select_overlay != null and not ui.country_select_overlay.visible, "country selection is hidden on title")
	var continue_label: Label = ui.title_overlay.find_child("ContinueText", true, false)
	var settings_label: Label = ui.title_overlay.find_child("SettingsText", true, false)
	_assert(continue_label != null and continue_label.text.contains("準備中"), "continue affordance is explicitly disabled")
	_assert(settings_label != null and settings_label.text.contains("準備中"), "settings affordance is explicitly disabled")
	var start: Control = ui.title_overlay.get_node_or_null("TitleStart")
	_assert(start != null and start.size.x >= 180.0 and start.size.y >= 56.0, "title start token is large enough")
	_click(start)
	await process_frame

	_assert(not ui.title_overlay.visible, "title overlay closes after start")
	_assert(ui.tutorial_overlay.visible, "tutorial opens after start")
	_assert(not ui.country_select_overlay.visible, "country selection stays hidden until tutorial continues")
	_assert(ui.tutorial_overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "tutorial overlay blocks board input behind it")
	var tutorial_primary: Control = ui.tutorial_overlay.get_node_or_null("TutorialPrimary")
	_assert(tutorial_primary != null and tutorial_primary.size.x >= 180.0 and tutorial_primary.size.y >= 40.0, "tutorial primary action is large enough")
	var tutorial_title: Label = ui.tutorial_overlay.find_child("TutorialTitle", true, false)
	_assert(tutorial_title != null and tutorial_title.text.contains("何をするゲーム"), "tutorial explains the game before country selection")
	_click(tutorial_primary)
	await process_frame

	_assert(not ui.tutorial_overlay.visible, "tutorial closes after primary action")
	_assert(ui.country_select_overlay.visible, "country selection opens after tutorial")
	_assert(ui.country_select_overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "country selection overlay blocks board input behind it")
	for i in range(ui.game.countries.size()):
		var choice: Control = ui.country_select_overlay.get_node_or_null("CountryChoice_%d" % i)
		_assert(choice != null, "country choice exists: %d" % i)
		_assert(choice.size.x >= 430.0 and choice.size.y >= 170.0, "country choice card remains readable: %d" % i)
	_click(ui.country_select_overlay.get_node("CountryChoice_2"))
	await process_frame

	_assert(not ui.title_overlay.visible and not ui.country_select_overlay.visible, "entry overlays close after country choice")
	_assert(ui.player_country_index == 2, "entry flow stores the chosen country")
	_assert(ui.selected_country_index == 2, "chosen country becomes the active board country")
	_assert(ui.policy_menu_nodes.is_empty(), "entry starts at negotiation without crowding the board with policy menu")

	if failed:
		quit(1)
	else:
		print("E2E entry flow passed.")
		quit(0)

func _click(control: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	control._gui_input(click)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
