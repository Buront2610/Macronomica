extends RefCounted
class_name Scoring

const GLOBAL_COLLAPSE_DEPRESSION := 10

static func is_global_collapse(world) -> bool:
	return int(world.tracks.get("depression", 0)) >= GLOBAL_COLLAPSE_DEPRESSION

static func score_country(country, world) -> Dictionary:
	var global_collapse := is_global_collapse(world)
	var score := int(country.welfare_score) * 10
	if score == 0 and country.welfare_history.is_empty():
		score = welfare_points(country) * 10
	score += int(country.tracks.get("influence", 0)) * 2
	score -= _world_exposure_penalty(country, world)
	var legacy_bonus := legacy_score_bonus(country, world)
	if not global_collapse:
		score += legacy_bonus
	else:
		score = 0
	return {
		"country_id": country.country_id,
		"display_name": country.display_name,
		"score": score,
		"welfare_score": int(country.welfare_score),
		"influence": int(country.tracks.get("influence", 0)),
		"legacy_goal": country.legacy_goal,
		"legacy_bonus": legacy_bonus if not global_collapse else 0,
		"global_collapse": global_collapse
	}

static func legacy_score_bonus(country, world) -> int:
	var t: Dictionary = country.tracks
	if country.has_tag("reserve_currency"):
		return max(0, 6 - int(world.tracks.get("international_financial_instability", 0))) + int(world.tracks.get("global_coordination", 0))
	if country.has_tag("exporter"):
		return max(0, 4 - abs(int(t.get("inflation", 0)) - 2)) + max(0, int(t.get("current_account", 0))) + max(0, int(t.get("gdp_gap", 0)))
	if country.has_tag("resource") or country.has_tag("resource_dependence"):
		return max(0, 6 - int(t.get("financial_stress", 0))) + max(0, int(t.get("current_account", 0))) + max(0, 4 - int(world.tracks.get("protectionism", 0)))
	if country.has_tag("foreign_debt") or country.has_tag("fragile_currency"):
		return max(0, int(t.get("gdp_gap", 0)) + 2) + max(0, int(t.get("exchange_rate", 0)) + 2) + max(0, 6 - int(t.get("financial_stress", 0)))
	return 0

static func welfare_points(country) -> int:
	var t: Dictionary = country.tracks
	var points := 0
	var gdp_gap := int(t.get("gdp_gap", 0))
	if gdp_gap >= 0 and gdp_gap <= 1:
		points += 1
	if int(t.get("unemployment", 0)) <= 3:
		points += 1
	if abs(int(t.get("inflation", 0)) - 2) <= 1:
		points += 1
	if int(t.get("financial_stress", 0)) <= 4:
		points += 1
	return points

static func final_scores(countries: Array, world) -> Array:
	var result := []
	for country in countries:
		result.append(score_country(country, world))
	if not is_global_collapse(world):
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	return result

static func _world_exposure_penalty(country, world) -> int:
	var tags: Array = country.tags
	var depression := int(world.tracks.get("depression", 0))
	var exposure := 1.0
	if tags.has("exporter"):
		exposure = 2.0
	elif tags.has("resource") or tags.has("resource_dependence") or tags.has("foreign_debt") or tags.has("fragile_currency"):
		exposure = 1.5
	return int(round(float(depression) * exposure))
