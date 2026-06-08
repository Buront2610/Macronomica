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
	_assert(ui.country_select_overlay != null and not ui.country_select_overlay.visible, "country selection is hidden on title")
	var start: Control = ui.title_overlay.get_node_or_null("TitleStart")
	_assert(start != null and start.size.x >= 180.0 and start.size.y >= 56.0, "title start token is large enough")
	_click(start)
	await process_frame

	_assert(not ui.title_overlay.visible, "title overlay closes after start")
	_assert(ui.country_select_overlay.visible, "country selection opens after start")
	for i in range(ui.game.countries.size()):
		var choice: Control = ui.country_select_overlay.get_node_or_null("CountryChoice_%d" % i)
		_assert(choice != null, "country choice exists: %d" % i)
		_assert(choice.size.x >= 430.0 and choice.size.y >= 170.0, "country choice card remains readable: %d" % i)
	_click(ui.country_select_overlay.get_node("CountryChoice_2"))
	await process_frame

	_assert(not ui.title_overlay.visible and not ui.country_select_overlay.visible, "entry overlays close after country choice")
	_assert(ui.player_country_index == 2, "entry flow stores the chosen country")
	_assert(ui.selected_country_index == 2, "chosen country becomes the active board hand")
	_assert(ui.hand_nodes.size() == ui.game.countries[2].hand.size(), "chosen country hand is visible on the board")

	if failed:
		quit(1)
	else:
		print("E2E entry flow passed.")
		quit(0)

func _click(control: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	control._gui_input(click)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
