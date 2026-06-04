extends RefCounted
class_name PolicyRecommender

static func recommend_for_country(game, country_index: int) -> Dictionary:
	if country_index < 0 or country_index >= game.countries.size():
		return {}
	var country = game.countries[country_index]
	var best_index := -1
	var best_score := -999
	for i in range(country.hand.size()):
		var card: Dictionary = country.hand[i]
		if card.get("type", "") != "policy":
			continue
		var score := score_policy(game, country, card)
		if score > best_score:
			best_score = score
			best_index = i
	if best_index < 0:
		return {}
	var selected: Dictionary = country.hand[best_index]
	return {
		"hand_index": best_index,
		"worker": worker_for_policy(game, country, selected),
		"score": best_score
	}

static func score_policy(game, country, card: Dictionary) -> int:
	var score := 0
	if pressure_matches(country, card):
		score += 40
	var effects: Dictionary = card.get("effects", {}).get("country", {})
	score += int(effects.get("gdp_gap", 0)) * 4
	score -= int(effects.get("unemployment", 0)) * 4
	score -= int(effects.get("financial_stress", 0)) * 3
	score -= int(effects.get("debt", 0)) * 2
	if int(game.world.tracks.get("depression", 0)) >= 3 and has_tag(card, "cooperation"):
		score += 18
	if has_tag(card, "beggar_thy_neighbor") and int(game.world.tracks.get("protectionism", 0)) >= 4:
		score -= 20
	return score

static func worker_for_policy(_game, country, card: Dictionary) -> String:
	if has_tag(card, "international") or has_tag(card, "cooperation"):
		return "diplomat"
	if int(country.tracks.get("financial_stress", 0)) >= 5:
		return "central_bank_staff"
	if int(country.tracks.get("political_capital", 0)) <= 2:
		return "lobbyist"
	return "bureaucrats"

static func pressure_matches(country, card: Dictionary) -> bool:
	var pressure_tags: Array = country.domestic_pressure.get("demand", {}).get("preferred_policy_tags", [])
	for tag in pressure_tags:
		if has_tag(card, tag):
			return true
	return false

static func has_tag(card: Dictionary, tag: String) -> bool:
	return card.get("tags", []).has(tag)
