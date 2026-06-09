extends RefCounted
class_name TokenAssets

var cache: Dictionary = {}
func texture(token_name: String, prefer_small := false) -> Texture2D:
	var cache_key := "%s:%s" % [token_name, "small" if prefer_small else "full"]
	if cache.has(cache_key):
		return cache[cache_key]
	var path := "res://assets/ui/tokens/small/%s.png" % token_name if prefer_small else "res://assets/ui/tokens/%s.png" % token_name
	var loaded: Texture2D = load(path)
	if loaded == null:
		path = "res://assets/ui/tokens/%s.png" % token_name if prefer_small else "res://assets/ui/tokens/small/%s.png" % token_name
		loaded = load(path)
	cache[cache_key] = loaded
	return loaded
