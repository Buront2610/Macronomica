extends RefCounted
class_name MacronomicaRng

var _state: int

func _init(seed_value: int = 1) -> void:
	_state = max(seed_value, 1)

func next_int() -> int:
	_state = int((_state * 1103515245 + 12345) & 0x7fffffff)
	return _state

func range_int(min_value: int, max_value: int) -> int:
	if max_value <= min_value:
		return min_value
	return min_value + (next_int() % (max_value - min_value + 1))

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

