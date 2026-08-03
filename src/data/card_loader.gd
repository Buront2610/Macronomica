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
		if not (card is Dictionary):
			push_error("Card entry must be a dictionary.")
			continue
		var id := String(card.get("id", ""))
		if id.is_empty():
			push_error("Card entry is missing id.")
			continue
		result[id] = card
	return result
