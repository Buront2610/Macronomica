extends RefCounted
class_name ModuleLoader

static func load_modules(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open module data: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var result := {}
	if typeof(parsed) != TYPE_ARRAY:
		return result
	for module in parsed:
		result[module["id"]] = module
	return result

