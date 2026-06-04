extends RefCounted
class_name CardLoader

static func load_cards(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open card data: %s" % path)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Card data must be an array: %s" % path)
		return []
	return parsed

static func index_by_id(cards: Array) -> Dictionary:
	var result := {}
	for card in cards:
		result[card["id"]] = card
	return result

