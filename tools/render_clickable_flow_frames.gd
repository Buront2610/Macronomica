extends SceneTree

const MainScript := preload("res://src/ui/main.gd")

var frame_index := 0
var out_dir := ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	out_dir = OS.get_environment("MACRONOMICA_GIF_FRAME_DIR")
	if out_dir.is_empty():
		out_dir = "res://tmp/screenshots/clickable_flow_frames"
	DirAccess.make_dir_recursive_absolute(out_dir)

	get_root().size = Vector2i(1920, 1080)
	var ui = MainScript.new()
	ui.size = get_root().size
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(ui)
	await _settle()
	await _save_frame("00_title")

	_click(ui.title_overlay.get_node("TitleStart"))
	await _settle()
	await _save_frame("01_tutorial")

	_click(ui.tutorial_overlay.get_node("TutorialPrimary"))
	await _settle()
	await _save_frame("02_country_select")

	_click(ui.country_select_overlay.get_node("CountryChoice_0"))
	await _settle()
	await _save_frame("03_negotiation")

	_click(ui.board_layer.get_node("AdvanceToken"))
	await _settle()
	await _save_frame("04_policy_menu")

	var next_page: Control = ui.board_layer.get_node_or_null("PolicyPageNext")
	if next_page != null and next_page.visible:
		_click(next_page)
		await _settle()
		await _save_frame("05_policy_menu_page_2")
		_click(ui.board_layer.get_node("PolicyPagePrev"))
		await _settle()

	_click(ui.board_layer.get_node("RecommendToken"))
	await _settle()
	await _save_frame("08_worker_assignment")

	_click(ui.board_layer.get_node("RecommendToken"))
	await _settle()
	await _save_frame("13_reveal_wait")
	_click(ui.board_layer.get_node("AdvanceToken"))
	await _settle()
	await _save_frame("14_resolution_pressure")
	_click(ui.board_layer.get_node("RecommendToken"))
	await _settle()
	await _save_frame("21_turn_news")
	print("Clickable flow frames saved: %s" % out_dir)
	quit(0)

func _click(control: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	control._gui_input(click)

func _settle() -> void:
	for i in range(90):
		await process_frame

func _save_frame(label: String) -> void:
	var image := get_root().get_texture().get_image()
	image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	var path := "%s/%02d_%s.png" % [out_dir, frame_index, label]
	image.save_png(path)
	frame_index += 1

func _first_simple_policy_index(cards: Array) -> int:
	for i in range(cards.size()):
		var card: Dictionary = cards[i]
		if String(card.get("type", "")) == "policy" and String(card.get("target", "")) != "country":
			return i
	return -1
