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
	if loaded != null:
		loaded = _cut_dark_backdrop(loaded)
	cache[token_name] = loaded
	return loaded

func _cut_dark_backdrop(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image == null:
		return texture
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			var luma := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
			var chroma := maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))
			if luma < 0.20 and chroma < 0.12:
				color.a *= clampf((luma - 0.06) / 0.14, 0.0, 1.0)
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
