extends SceneTree

const MainScript := preload("res://src/ui/main.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ui = MainScript.new()
	ui.size = get_root().size
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(ui)
	for i in range(5):
		await process_frame

	var policy_index := _first_policy_index(ui.game.countries[0].hand)
	if policy_index >= 0:
		ui._on_policy_selected(0, policy_index, Vector2(180, 620))
	for i in range(3):
		await process_frame

	var path := OS.get_environment("MACRONOMICA_PREVIEW_PATH")
	if path.is_empty():
		path = "res://tmp/screenshots/board_action_preview.png"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image := get_root().get_texture().get_image()
	image.save_png(path)
	print("Board action preview saved: %s" % path)
	quit(0)

func _first_policy_index(hand: Array) -> int:
	for i in range(hand.size()):
		if hand[i].get("type", "") == "policy":
			return i
	return -1
