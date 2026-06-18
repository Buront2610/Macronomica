extends RefCounted
class_name PolicyRecommender

const CountryStateScript := preload("res://src/core/country_state.gd")

static func recommend_for_country(game, country_index: int) -> Dictionary:
	if country_index < 0 or country_index >= game.countries.size():
		return {}
	var country = game.countries[country_index]
	var options: Array = game.policy_options(country_index)
	var best_index := -1
	var best_score := -999
	for i in range(options.size()):
		var card: Dictionary = options[i]
		if not country.is_policy_available(card):
			continue
		var workers := workers_for_policy(game, country, card)
		var score := score_policy(game, country, card, workers)
		if score > best_score:
			best_score = score
			best_index = i
	if best_index < 0:
		return {}
	var selected: Dictionary = options[best_index]
	var workers := workers_for_policy(game, country, selected)
	return {
		"policy_index": best_index,
		"worker": String(workers[0]) if not workers.is_empty() else "",
		"workers": workers,
		"score": best_score
	}

static func score_policy(game, country, card: Dictionary, workers = []) -> int:
	var score := 0
	if pressure_matches(country, card):
		score += 25
	score += _response_candidate_count(country, card) * 18
	var effects: Dictionary = card.get("effects", {}).get("country", {})
	var before_gap := int(country.tracks.get("gdp_gap", 0))
	var after_gap := before_gap + int(effects.get("gdp_gap", 0))
	score += (abs(before_gap) - abs(after_gap)) * 4
	score -= int(effects.get("unemployment", 0)) * 4
	score -= int(effects.get("financial_stress", 0)) * 3
	score -= int(effects.get("debt", 0)) * 2
	if int(game.world.tracks.get("depression", 0)) >= 3 and has_tag(card, "cooperation"):
		score += 18
	if has_tag(card, "beggar_thy_neighbor") and int(game.world.tracks.get("protectionism", 0)) >= 4:
		score -= 20
	var assigned_workers: Array = workers if workers is Array else [String(workers)]
	if assigned_workers.is_empty() or String(assigned_workers[0]).is_empty():
		assigned_workers = workers_for_policy(game, country, card)
	var paid := _preview_policy_cost(country, card, assigned_workers)
	if bool(paid.get("success", false)):
		score += 30
	else:
		score -= _shortage_total(paid.get("shortages", {})) * 35
	return score

static func worker_for_policy(_game, country, card: Dictionary) -> String:
	var workers := workers_for_policy(_game, country, card)
	return String(workers[0]) if not workers.is_empty() else "bureaucrats"

static func workers_for_policy(_game, country, card: Dictionary) -> Array:
	var best_worker := "bureaucrats"
	var best_shortage := 999
	var best_priority := -999
	for worker in CountryStateScript.WORKERS:
		var paid := _preview_policy_cost(country, card, [worker])
		var shortage := _shortage_total(paid.get("shortages", {}))
		var priority := _worker_priority(country, card, worker)
		if shortage < best_shortage or (shortage == best_shortage and priority > best_priority):
			best_shortage = shortage
			best_priority = priority
			best_worker = worker
	var workers := [best_worker]
	var costs: Dictionary = card.get("costs", {})
	var worker_costs := {
		"bureaucrats": "administrative",
		"central_bank_staff": "credibility",
		"diplomat": "international",
		"lobbyist": "political"
	}
	for worker in worker_costs.keys():
		var cost_key := String(worker_costs[worker])
		if int(costs.get(cost_key, 0)) > 0 and not workers.has(worker):
			if worker != "lobbyist" or int(country.tracks.get("political_capital", 0)) <= int(costs.get("political", 0)) + 1:
				workers.append(worker)
	if _pollution_count(country) > 0 and not workers.has("auditor"):
		workers.append("auditor")
	var response_worker := _best_response_worker(country, card)
	if not response_worker.is_empty() and not workers.has(response_worker):
		workers.append(response_worker)
	return workers

static func pressure_matches(country, card: Dictionary) -> bool:
	var pressure_tags: Array = country.domestic_pressure.get("demand", {}).get("preferred_policy_tags", [])
	for tag in pressure_tags:
		if has_tag(card, tag):
			return true
	return false

static func has_tag(card: Dictionary, tag: String) -> bool:
	return card.get("tags", []).has(tag)

static func _preview_policy_cost(country, card: Dictionary, workers: Array) -> Dictionary:
	var clone = CountryStateScript.new()
	clone.country_id = country.country_id
	clone.display_name = country.display_name
	clone.summary = country.summary
	clone.legacy_goal = country.legacy_goal
	clone.modules = country.modules.duplicate(true)
	clone.tags = country.tags.duplicate(true)
	clone.cost_modifiers = country.cost_modifiers.duplicate(true)
	clone.tracks = country.tracks.duplicate(true)
	clone.deck = country.deck.duplicate(true)
	clone.discard = country.discard.duplicate(true)
	clone.hand = country.hand.duplicate(true)
	clone.domestic_pressure = country.domestic_pressure.duplicate(true)
	clone.selected_policy = country.selected_policy.duplicate(true)
	clone.assign_workers(workers)
	return clone.pay_costs(card.get("costs", {}))

static func _shortage_total(shortages: Dictionary) -> int:
	var total := 0
	for key in shortages.keys():
		total += int(shortages[key])
	return total

static func _worker_priority(country, card: Dictionary, worker: String) -> int:
	var priority := 0
	if worker == "diplomat" and (has_tag(card, "international") or has_tag(card, "cooperation")):
		priority += 3
	if worker == "central_bank_staff" and int(country.tracks.get("financial_stress", 0)) >= 5:
		priority += 2
	if worker == "lobbyist" and int(country.tracks.get("political_capital", 0)) <= 2:
		priority += 2
	if worker == "auditor" and _pollution_count(country) > 0:
		priority += 4
	if worker == "bureaucrats":
		priority += 1
	return priority

static func _pollution_count(country) -> int:
	var count := 0
	for zone in [country.deck, country.discard]:
		for card in zone:
			var card_id := String(card.get("id", ""))
			if ["corruption_risk", "rent_seeking", "patronage_network"].has(card_id):
				count += 1
	return count

static func _response_candidate_count(country, policy: Dictionary) -> int:
	var count := 0
	var policy_tags: Array = policy.get("tags", [])
	for card in country.hand:
		if String(card.get("type", "")) != "vulnerability":
			continue
		var response: Dictionary = card.get("response", {})
		if _tags_overlap(policy_tags, response.get("removed_by_tags", [])):
			count += 1
	return count

static func _best_response_worker(country, policy: Dictionary) -> String:
	var policy_tags: Array = policy.get("tags", [])
	for card in country.hand:
		if String(card.get("type", "")) != "vulnerability":
			continue
		var response: Dictionary = card.get("response", {})
		if not _tags_overlap(policy_tags, response.get("removed_by_tags", [])):
			continue
		var extra_costs: Dictionary = response.get("extra_costs", {})
		if extra_costs.has("administrative"):
			return "bureaucrats"
		if extra_costs.has("credibility"):
			return "central_bank_staff"
		if extra_costs.has("international"):
			return "diplomat"
		if extra_costs.has("political"):
			return "lobbyist"
		if card.get("tags", []).has("rent") or card.get("tags", []).has("corruption"):
			return "auditor"
	return ""

static func _tags_overlap(a: Array, b: Array) -> bool:
	for tag in b:
		if a.has(tag):
			return true
	return false
