extends SceneTree

const GameStateScript := preload("res://src/core/game_state.gd")

func _init() -> void:
	var game = GameStateScript.new()
	game.new_game()
	_assert(game.current_phase() == "negotiation", "new game starts at negotiation after setup")
	game.advance_phase()
	_assert(game.current_phase() == "policy_planning", "advance to policy planning")
	for i in range(game.countries.size()):
		_select_first_policy(game, i)
	game.advance_phase()
	_assert(game.current_phase() == "worker_assignment", "advance to worker assignment")
	for i in range(game.countries.size()):
		game.assign_worker(i, "bureaucrats")
	game.advance_phase()
	_assert(game.current_phase() == "simultaneous_reveal", "advance to simultaneous reveal")
	game.advance_phase()
	_assert(game.turn == 2, "simultaneous reveal resolves and starts next turn")
	_assert(game.current_phase() == "negotiation", "next turn returns to negotiation")
	for country in game.countries:
		_assert(country.hand.size() == 2, "next turn reveals two state cards")
		_assert(_policy_count(country.deck) + _policy_count(country.hand) + _policy_count(country.discard) == 0, "state deck zones do not contain policy cards")
	print("Smoke game flow passed.")
	quit(0)

func _select_first_policy(game, country_index: int) -> void:
	var country = game.countries[country_index]
	for i in range(country.policy_menu.size()):
		if country.policy_menu[i].get("type", "") == "policy":
			game.select_policy(country_index, i)
			return
	_assert(false, "country has at least one policy in menu")

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _policy_count(cards: Array) -> int:
	var count := 0
	for card in cards:
		if String(card.get("type", "")) == "policy":
			count += 1
	return count
