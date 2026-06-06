extends SceneTree

const GameStateScript := preload("res://src/core/game_state.gd")
const CountryStateScript := preload("res://src/core/country_state.gd")
const PolicyResolverScript := preload("res://src/core/policy_resolver.gd")

func _init() -> void:
	var game = GameStateScript.new()
	game.new_game()
	_assert(game.current_phase() == "negotiation", "game starts before policy input")
	var initial_selection: Dictionary = game.countries[0].selected_policy
	game.select_policy(0, _first_policy_index(game.countries[0].hand))
	_assert(game.countries[0].selected_policy == initial_selection, "policy selection is blocked outside policy planning")

	game.advance_phase()
	game.select_policy(0, _first_policy_index(game.countries[0].hand))
	_assert(not game.countries[0].selected_policy.is_empty(), "policy selection is allowed during policy planning")
	var initial_worker: String = game.countries[0].assigned_worker
	game.assign_worker(0, "diplomat")
	_assert(game.countries[0].assigned_worker == initial_worker, "worker assignment is blocked outside worker assignment")

	game.advance_phase()
	game.assign_worker(0, "diplomat")
	_assert(game.countries[0].assigned_worker == "diplomat", "worker assignment is allowed during worker assignment")

	var country = CountryStateScript.new()
	country.display_name = "試験国"
	country.tracks = {"gdp_gap": -2, "inflation": 1, "unemployment": 8, "debt": 9, "financial_stress": 8, "political_capital": 0, "exchange_rate": -3, "current_account": -3}
	country.assigned_worker = "bureaucrats"
	var world = game.world
	var policy := {
		"display_name": "高難度政策",
		"costs": {"political": 2, "fiscal": 2, "administrative": 3, "credibility": 3, "international": 3, "industrial": 3},
		"effects": {"country": {"gdp_gap": 2}, "world": {"world_demand": 1}}
	}
	var log := PolicyResolverScript.resolve_policy(country, [], world, policy, {})
	_assert(_contains(log, "不足で骨抜き"), "non-payable costs weaken policy resolution")
	_assert(_contains(log, "行政能力不足"), "administrative shortage is logged")
	_assert(_contains(log, "信認不足"), "credibility shortage is logged")
	_assert(_contains(log, "国際調整不足"), "international shortage is logged")
	_assert(_contains(log, "産業実行力不足"), "industrial shortage is logged")

	var scores: Array = game.get_scores()
	_assert(scores[0].has("legacy_bonus"), "scores include legacy bonus")
	print("Smoke domain rules passed.")
	quit(0)

func _first_policy_index(hand: Array) -> int:
	for i in range(hand.size()):
		if hand[i].get("type", "") == "policy":
			return i
	return -1

func _contains(lines: Array, needle: String) -> bool:
	for line in lines:
		if String(line).contains(needle):
			return true
	return false

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
