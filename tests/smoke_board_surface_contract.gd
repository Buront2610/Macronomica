extends SceneTree

const MAIN_PATH := "res://src/ui/main.gd"
const BANNED_SURFACE_TOKENS := [
	"PanelContainer",
	"HBoxContainer",
	"VBoxContainer",
	"ScrollContainer",
	"TabContainer",
	"Button.new",
	"StyleBoxFlat",
	"draw_rect"
]
const REQUIRED_SURFACE_TOKENS := [
	"class BoardPiece",
	"class BoardTrail",
	"_animate_trail",
	"_animate_card_to_slot",
	"_animate_token_to_seat",
	"_animate_country_marker",
	"_animate_phase_marker"
]

func _init() -> void:
	var source := FileAccess.get_file_as_string(MAIN_PATH)
	_assert(not source.is_empty(), "main UI source can be read")
	for token in BANNED_SURFACE_TOKENS:
		_assert(not source.contains(token), "main board surface does not use banned UI token: %s" % token)
	for token in REQUIRED_SURFACE_TOKENS:
		_assert(source.contains(token), "main board surface keeps board-game animation token: %s" % token)
	print("Smoke board surface contract passed.")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
