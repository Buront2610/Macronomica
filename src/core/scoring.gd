extends RefCounted
class_name Scoring

static func score_country(country, world) -> Dictionary:
	var t: Dictionary = country.tracks
	var score := 50
	score += int(t.get("gdp_gap", 0)) * 3
	score += max(0, 5 - int(t.get("unemployment", 0))) * 3
	score += max(0, 4 - abs(int(t.get("inflation", 0)) - 2)) * 2
	score += max(0, 8 - int(t.get("financial_stress", 0))) * 2
	score += max(0, 8 - int(t.get("debt", 0))) * 2
	score += int(t.get("political_capital", 0)) * 2
	score -= int(world.tracks.get("depression", 0)) * 5
	score -= int(world.tracks.get("international_financial_instability", 0)) * 2
	score -= int(world.tracks.get("protectionism", 0)) * 2
	var legacy_bonus := legacy_score_bonus(country, world)
	score += legacy_bonus
	return {"country_id": country.country_id, "display_name": country.display_name, "score": score, "legacy_goal": country.legacy_goal, "legacy_bonus": legacy_bonus}

static func legacy_score_bonus(country, world) -> int:
	var t: Dictionary = country.tracks
	if country.country_id == "reserve_currency_financial_power":
		return max(0, 6 - int(world.tracks.get("international_financial_instability", 0))) + int(world.tracks.get("global_coordination", 0))
	if country.country_id == "export_industrial_deflationary_state":
		return max(0, 4 - abs(int(t.get("inflation", 0)) - 2)) + max(0, int(t.get("current_account", 0))) + max(0, int(t.get("gdp_gap", 0)))
	if country.country_id == "resource_exporter_state":
		return max(0, 6 - int(t.get("financial_stress", 0))) + max(0, int(t.get("current_account", 0))) + max(0, 4 - int(world.tracks.get("protectionism", 0)))
	if country.country_id == "emerging_foreign_debt_state":
		return max(0, int(t.get("gdp_gap", 0)) + 2) + max(0, int(t.get("exchange_rate", 0)) + 2) + max(0, 6 - int(t.get("financial_stress", 0)))
	return 0

static func final_scores(countries: Array, world) -> Array:
	var result := []
	for country in countries:
		result.append(score_country(country, world))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	return result
