extends RefCounted
class_name PolicyResolver

static func resolve_policy(country, countries: Array, world, policy: Dictionary, card_index: Dictionary) -> Array:
	var log: Array = []
	var paid: Dictionary = country.pay_costs(policy.get("costs", {}))
	var success: bool = paid["success"]
	var shortages: Dictionary = paid.get("shortages", {})
	var country_effects: Dictionary = policy.get("effects", {}).get("country", {}).duplicate(true)
	var world_effects: Dictionary = policy.get("effects", {}).get("world", {}).duplicate(true)
	if not success:
		country_effects = _soften_effects(country_effects)
		world_effects = _soften_effects(world_effects)
		country.apply_effects({"political_capital": -1})
		_apply_shortage_side_effects(country, world, shortages, log)
		log.append("%s の「%s」は %s 不足で骨抜きになりました。" % [country.display_name, policy.get("display_name", ""), _format_shortages(shortages)])
	else:
		log.append("%s は「%s」を実行しました。" % [country.display_name, policy.get("display_name", "")])
	country.apply_effects(country_effects)
	world.apply_effects(world_effects)
	_apply_spillovers(country, countries, policy, log)
	_apply_mutations(country, world, policy, card_index, log)
	if country.assigned_worker == "lobbyist" and card_index.has("rent_seeking"):
		country.discard.append(card_index["rent_seeking"])
		log.append("%s はロビイストを使ったため、利権カードがデッキに残りました。" % country.display_name)
	if country.assigned_worker == "auditor":
		_remove_one(country, ["corruption_risk", "rent_seeking"], log)
	return log

static func _soften_effects(effects: Dictionary) -> Dictionary:
	var result := {}
	for key in effects.keys():
		var value := int(effects[key])
		result[key] = int(sign(value) * ceili(abs(value) / 2.0))
	return result

static func _apply_shortage_side_effects(country, world, shortages: Dictionary, log: Array) -> void:
	for key in shortages.keys():
		var gap := int(shortages[key])
		if key == "administrative":
			country.apply_effects({"political_capital": -gap})
			log.append("%s は行政能力不足で実施調整が迷走しました。" % country.display_name)
		elif key == "credibility":
			country.apply_effects({"financial_stress": gap})
			log.append("%s は信認不足で市場の疑念を招きました。" % country.display_name)
		elif key == "international":
			world.apply_effects({"global_coordination": -gap, "international_financial_instability": gap})
			log.append("%s は国際調整不足で世界金融不安を高めました。" % country.display_name)
		elif key == "industrial":
			country.apply_effects({"gdp_gap": -gap, "unemployment": gap})
			log.append("%s は産業実行力不足で雇用への副作用を出しました。" % country.display_name)
		elif key == "political":
			country.apply_effects({"political_capital": -1})
			log.append("%s は政治資本不足で妥協を重ねました。" % country.display_name)
		elif key == "fiscal":
			country.apply_effects({"debt": gap, "financial_stress": gap})
			log.append("%s は財政余力不足で債務不安を高めました。" % country.display_name)

static func _format_shortages(shortages: Dictionary) -> String:
	if shortages.is_empty():
		return "能力"
	var names := {
		"fiscal": "財政",
		"political": "政治",
		"administrative": "行政",
		"credibility": "信認",
		"international": "国際",
		"industrial": "産業"
	}
	var parts := []
	for key in shortages.keys():
		parts.append("%s%d" % [names.get(key, key), int(shortages[key])])
	return "・".join(parts)

static func _apply_spillovers(source, countries: Array, policy: Dictionary, log: Array) -> void:
	for spillover in policy.get("spillovers", []):
		var target_tag := String(spillover.get("target_tag", ""))
		for target in countries:
			if target == source:
				continue
			if target.has_tag(target_tag):
				target.apply_effects(spillover.get("effects", {}))
				log.append("%s の政策が %s に波及しました。" % [source.display_name, target.display_name])

static func _apply_mutations(country, world, policy: Dictionary, card_index: Dictionary, log: Array) -> void:
	var mutations: Dictionary = policy.get("mutations", {})
	for card_id in mutations.get("add_to_deck", []):
		if card_index.has(card_id):
			country.discard.append(card_index[card_id])
			log.append("%s のデッキに「%s」が追加されました。" % [country.display_name, card_index[card_id].get("display_name", card_id)])
	for card_id in mutations.get("remove_from_deck", []):
		if _remove_card_by_id(country.deck, card_id) or _remove_card_by_id(country.discard, card_id) or _remove_card_by_id(country.hand, card_id):
			log.append("%s のデッキから「%s」が除去されました。" % [country.display_name, card_index.get(card_id, {}).get("display_name", card_id)])
	var world_card_id := String(mutations.get("add_world_card", ""))
	if not world_card_id.is_empty() and card_index.has(world_card_id):
		world.event_discard.append(card_index[world_card_id])
		log.append("世界デッキに「%s」が追加されました。" % card_index[world_card_id].get("display_name", world_card_id))

static func _remove_one(country, ids: Array, log: Array) -> void:
	for card_id in ids:
		if _remove_card_by_id(country.discard, card_id) or _remove_card_by_id(country.deck, card_id):
			log.append("%s の監査官が「%s」を抑え込みました。" % [country.display_name, card_id])
			return

static func _remove_card_by_id(cards: Array, card_id: String) -> bool:
	for i in range(cards.size()):
		if String(cards[i].get("id", "")) == card_id:
			cards.remove_at(i)
			return true
	return false
