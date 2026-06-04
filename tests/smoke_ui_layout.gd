extends SceneTree

const MainScript := preload("res://src/ui/main.gd")

func _init() -> void:
	var ui = MainScript.new()
	_assert(ui.layout_mode_for_window_width(1199) == "compact", "1199px uses compact layout")
	_assert(ui.layout_mode_for_window_width(1200) == "mid", "1200px starts mid layout")
	_assert(ui.layout_mode_for_window_width(1499) == "mid", "1499px still uses mid layout")
	_assert(ui.layout_mode_for_window_width(1600) == "mid", "1600px uses mid layout")
	_assert(ui.layout_mode_for_window_width(1799) == "mid", "1799px still uses mid layout")
	_assert(ui.layout_mode_for_window_width(1800) == "wide", "1800px starts wide layout")
	_assert(ui.layout_mode_for_window_width(1920) == "wide", "1920px uses wide layout")
	_assert(ui.is_short_window_height(720), "720px uses short viewport behavior")
	_assert(not ui.is_short_window_height(900), "900px uses standard vertical behavior")
	print("Smoke UI layout passed.")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
