extends RefCounted
class_name MacronomicaRng

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = 1) -> void:
	_rng.seed = int(seed_value)

func next_int() -> int:
	return int(_rng.randi() & 0x7fffffff)

func range_int(min_value: int, max_value: int) -> int:
	if max_value <= min_value:
		return min_value
	return _rng.randi_range(min_value, max_value)

func pick(array: Array) -> Variant:
	if array.is_empty():
		return null
	return array[range_int(0, array.size() - 1)]

func shuffle(array: Array) -> Array:
	var result := array.duplicate(true)
	for i in range(result.size() - 1, 0, -1):
		var j := range_int(0, i)
		var temp: Variant = result[i]
		result[i] = result[j]
		result[j] = temp
	return result
