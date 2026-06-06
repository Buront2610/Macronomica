extends SceneTree

const MAIN_PATH := "res://src/ui/main.gd"
const BOARD_PIECE_PATH := "res://src/ui/support/board_piece.gd"
const BOARD_TRAIL_PATH := "res://src/ui/support/board_trail.gd"
const BOARD_LAYOUT_PATH := "res://src/ui/support/board_layout.gd"
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
	"BoardPieceScript.new",
	"BoardTrailScript.new",
	"BoardLayoutScript.for_screen",
	"_animate_trail",
	"_animate_card_to_slot",
	"_animate_token_to_seat",
	"_animate_country_marker",
	"_animate_phase_marker"
]

func _init() -> void:
	var source := FileAccess.get_file_as_string(MAIN_PATH)
	_assert(not source.is_empty(), "main UI source can be read")
	_assert(FileAccess.file_exists(BOARD_PIECE_PATH), "board piece drawing class is extracted")
	_assert(FileAccess.file_exists(BOARD_TRAIL_PATH), "board trail drawing class is extracted")
	_assert(FileAccess.file_exists(BOARD_LAYOUT_PATH), "board layout definition is extracted")
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
