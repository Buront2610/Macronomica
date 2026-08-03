extends SceneTree

func _init() -> void:
	var font := FontFile.new()
	var error := font.load_dynamic_font("res://assets/fonts/MPLUS1p-Regular.ttf")
	if error != OK:
		push_error("Failed to load M PLUS 1p font: %s" % error)
		quit(1)
		return
	error = ResourceSaver.save(font, "res://assets/fonts/mplus1p_regular.tres")
	if error != OK:
		push_error("Failed to save font resource: %s" % error)
		quit(1)
		return
	print("Saved assets/fonts/mplus1p_regular.tres")
	quit(0)
