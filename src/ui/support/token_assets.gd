extends RefCounted
class_name TokenAssets

var cache: Dictionary = {}

func texture(token_name: String) -> Texture2D:
	if cache.has(token_name):
		return cache[token_name]
	var path := "res://assets/ui/tokens/small/%s.png" % token_name
	var loaded: Texture2D = load(path)
	if loaded == null:
		path = "res://assets/ui/tokens/%s.png" % token_name
		loaded = load(path)
	cache[token_name] = loaded
	return loaded
