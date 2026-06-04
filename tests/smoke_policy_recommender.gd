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
		_assert(int(recommendation["hand_index"]) >= 0, "recommendation points to a hand card")
		_assert(CountryStateScript.WORKERS.has(String(recommendation["worker"])), "recommendation assigns a known worker")
		var card: Dictionary = game.countries[country_index].hand[int(recommendation["hand_index"])]
		_assert(card.get("type", "") == "policy", "recommendation chooses a policy card")
	print("Smoke policy recommender passed.")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
