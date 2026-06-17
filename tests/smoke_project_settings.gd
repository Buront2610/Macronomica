extends SceneTree

func _init() -> void:
	var custom_font := String(ProjectSettings.get_setting("gui/theme/custom_font", ""))
	_assert(custom_font == "res://assets/fonts/mplus1p_regular.tres", "project uses the bundled Japanese font resource")
	_assert(ResourceLoader.exists(custom_font), "bundled Japanese font resource exists")
	_assert(FileAccess.file_exists("res://assets/fonts/MPLUS1p-Regular.ttf"), "bundled Japanese source font exists")
	_assert(ResourceLoader.exists("res://assets/ui/tokens/expected_inflation_forecast.png"), "expected inflation token exists")
	_assert(ResourceLoader.exists("res://assets/ui/tokens/international_influence_globe.png"), "international influence token exists")
	_assert(ResourceLoader.exists("res://assets/ui/tokens/small/expected_inflation_forecast.png"), "small expected inflation token exists")
	_assert(ResourceLoader.exists("res://assets/ui/tokens/small/international_influence_globe.png"), "small international influence token exists")
	_assert(not ResourceLoader.exists("res://assets/ui/board_table_background.png"), "unused baked board background is not shipped")
	_assert(ResourceLoader.exists("res://assets/ui/policy_room_background.png"), "runtime board background exists")
	_assert(String(ProjectSettings.get_setting("display/window/stretch/mode", "")) == "canvas_items", "project uses canvas item stretch")
	_assert(String(ProjectSettings.get_setting("display/window/stretch/aspect", "")) == "expand", "project uses expand stretch aspect")
	print("Smoke project settings passed.")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
