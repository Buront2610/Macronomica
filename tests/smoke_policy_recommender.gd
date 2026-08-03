extends SceneTree

const GameStateScript := preload("res://src/core/game_state.gd")
const PolicyRecommenderScript := preload("res://src/app/policy_recommender.gd")
const CountryStateScript := preload("res://src/core/country_state.gd")

func _init() -> void:
	var game = GameStateScript.new()
	game.new_game()
	for country_index in range(game.countries.size()):
		var recommendation := PolicyRecommenderScript.recommend_for_country(game, country_index)
		_assert(not recommendation.is_empty(), "recommendation exists for country %d" % country_index)
		_assert(int(recommendation["policy_index"]) >= 0, "recommendation points to an active agenda card")
		_assert(CountryStateScript.WORKERS.has(String(recommendation["worker"])), "recommendation assigns a known worker")
		var card: Dictionary = game.policy_options(country_index)[int(recommendation["policy_index"])]
		_assert(card.get("type", "") == "policy", "recommendation chooses a policy card")
	var constrained = game.countries[0]
	constrained.tracks = {"gdp_gap": -2, "inflation": 0, "unemployment": 3, "debt": 9, "financial_stress": 8, "political_capital": 0, "exchange_rate": -3, "current_account": -3}
	constrained.policy_menu = [
		{"id": "unpayable_boom", "display_name": "払えない大政策", "type": "policy", "costs": {"political": 5, "fiscal": 5, "credibility": 5}, "effects": {"country": {"gdp_gap": 6}, "world": {}}},
		{"id": "small_repair", "display_name": "小修復", "type": "policy", "costs": {}, "effects": {"country": {"gdp_gap": 1}, "world": {}}}
	]
	constrained.active_agenda = constrained.policy_menu.duplicate(true)
	var constrained_recommendation := PolicyRecommenderScript.recommend_for_country(game, 0)
	_assert(int(constrained_recommendation.get("policy_index", -1)) == 1, "recommendation prefers payable policy over oversized unpayable policy")
	constrained.deck = [{"id": "rent_seeking", "display_name": "利権化", "type": "vulnerability"}]
	constrained.policy_menu = [{"id": "clean_policy", "display_name": "通常政策", "type": "policy", "costs": {}, "effects": {"country": {}, "world": {}}}]
	constrained.active_agenda = constrained.policy_menu.duplicate(true)
	var audit_recommendation := PolicyRecommenderScript.recommend_for_country(game, 0)
	_assert(String(audit_recommendation.get("worker", "")) == "auditor", "recommendation assigns auditor when deck pollution can be removed")
	print("Smoke policy recommender passed.")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
