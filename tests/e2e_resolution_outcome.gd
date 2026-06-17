extends SceneTree

const GameStateScript := preload("res://src/core/game_state.gd")

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = GameStateScript.new()
	game.new_game()
	game.advance_phase()
	game.turn_limit = 1
	for country_index in range(game.countries.size()):
		var policy_index := _first_policy_index(game.countries[country_index].policy_menu)
		_assert(policy_index >= 0, "country %d has a policy card" % country_index)
		game.select_policy(country_index, policy_index)
	game.advance_phase()
	var workers := ["bureaucrats", "central_bank_staff", "diplomat", "auditor"]
	for country_index in range(game.countries.size()):
		game.assign_worker(country_index, workers[country_index % workers.size()])
	var before_countries := _country_snapshots(game.countries)
	var before_world: Dictionary = game.world.tracks.duplicate(true)
	var outcome: Dictionary = game.preview_resolution_outcome()
	_assert(outcome.get("items", []).size() == 4, "resolution outcome covers all countries")
	game.reveal_policies()
	game.resolve_turn()
	var expected_country_diffs := _expected_country_diffs(outcome, game.countries.size())
	for country_index in range(game.countries.size()):
		var actual := _track_diff(before_countries[country_index], game.countries[country_index].tracks)
		_assert(_dicts_equal(actual, expected_country_diffs[country_index]), "country %d outcome diff matches resolve_turn" % country_index)
	var expected_world := _expected_world_diff(outcome)
	var actual_world := _track_diff(before_world, game.world.tracks)
	_assert(_dicts_equal(actual_world, expected_world), "world outcome diff matches resolve_turn")

	if failed:
		quit(1)
	else:
		print("E2E resolution outcome passed.")
		quit(0)

func _first_policy_index(hand: Array) -> int:
	for i in range(hand.size()):
		if hand[i].get("type", "") == "policy":
			return i
	return -1

func _country_snapshots(countries: Array) -> Array:
	var result := []
	for country in countries:
		result.append(country.tracks.duplicate(true))
	return result

func _expected_country_diffs(outcome: Dictionary, country_count: int) -> Array:
	var result := []
	for _i in range(country_count):
		result.append({})
	for item in outcome.get("items", []):
		var pressure_index := int(item.get("country_index", -1))
		if pressure_index >= 0:
			_add_diff(result[pressure_index], item.get("pressure_diff", {}))
		for key in item.get("country_diffs", {}).keys():
			_add_diff(result[int(key)], item["country_diffs"][key])
	var macro: Dictionary = outcome.get("macro", {})
	for key in macro.get("country_diffs", {}).keys():
		_add_diff(result[int(key)], macro["country_diffs"][key])
	return result

func _expected_world_diff(outcome: Dictionary) -> Dictionary:
	var result := {}
	for item in outcome.get("items", []):
		_add_diff(result, item.get("world_diff", {}))
	var macro: Dictionary = outcome.get("macro", {})
	_add_diff(result, macro.get("world_diff", {}))
	return result

func _add_diff(target: Dictionary, diff_value) -> void:
	if not (diff_value is Dictionary):
		return
	for key in diff_value.keys():
		target[key] = int(target.get(key, 0)) + int(diff_value[key])
		if int(target[key]) == 0:
			target.erase(key)

func _track_diff(before: Dictionary, after: Dictionary) -> Dictionary:
	var result := {}
	var keys := []
	for key in before.keys():
		if not keys.has(key):
			keys.append(key)
	for key in after.keys():
		if not keys.has(key):
			keys.append(key)
	for key in keys:
		var delta := int(after.get(key, 0)) - int(before.get(key, 0))
		if delta != 0:
			result[key] = delta
	return result

func _dicts_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		push_error("Diff mismatch actual=%s expected=%s" % [str(a), str(b)])
		return false
	for key in a.keys():
		if int(a[key]) != int(b.get(key, 999999)):
			push_error("Diff mismatch actual=%s expected=%s" % [str(a), str(b)])
			return false
	return true

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
