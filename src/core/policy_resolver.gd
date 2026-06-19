extends RefCounted
class_name PolicyResolver

static func resolve_policy(country, countries: Array, world, policy: Dictionary, card_index: Dictionary, policy_index := {}) -> Array:
	var paid: Dictionary = country.pay_costs(policy.get("costs", {}))
	return resolve_paid_policy(country, countries, world, policy, card_index, paid, policy_index)

static func resolve_paid_policy(country, countries: Array, world, policy: Dictionary, card_index: Dictionary, paid: Dictionary, policy_index := {}) -> Array:
	var log: Array = []
	var success: bool = bool(paid.get("success", true))
	var shortages: Dictionary = paid.get("shortages", {})
	var effects: Dictionary = policy.get("effects", {})
	var target_country = _target_country(country, countries, policy)
	var country_effects: Dictionary = effects.get("donor", effects.get("country", {})).duplicate(true) if target_country != null else effects.get("country", {}).duplicate(true)
	var target_effects: Dictionary = effects.get("recipient", {}).duplicate(true) if target_country != null else {}
	var world_effects: Dictionary = effects.get("world", {}).duplicate(true)
	if _liquidity_trap_active(country, policy):
		country_effects["gdp_gap"] = int(country_effects.get("gdp_gap", 0)) - 1
	if country.has_assigned_worker("diplomat") and _has_tag(policy, "cooperation"):
		world_effects = _boost_positive_effects(world_effects)
	var delay_turns := int(policy.get("lag", 0))
	if shortages.has("administrative"):
		delay_turns += 1
	if not success and shortages.has("political") and shortages.size() == 1:
		country.apply_effects({"debt": 1})
		if card_index.has("rent_seeking"):
			country.deck.push_front(card_index["rent_seeking"])
		log.append("%s の「%s」は補助金混入で成立し、利権を残しました。" % [country.display_name, policy.get("display_name", "")])
	elif not success and delay_turns <= 0:
		country_effects = _soften_effects(country_effects)
		target_effects = _soften_effects(target_effects)
		world_effects = _soften_effects(world_effects)
		country.apply_effects({"political_capital": -1})
		_apply_shortage_side_effects(country, world, shortages, log)
		log.append("%s の「%s」は %s 不足で骨抜きになりました。" % [country.display_name, policy.get("display_name", ""), _format_shortages(shortages)])
	elif delay_turns > 0:
		_schedule_effects(country, policy, country_effects, world_effects, delay_turns, log)
		if target_country != null and not target_effects.is_empty():
			_schedule_effects(target_country, policy, target_effects, {}, delay_turns, log)
		country_effects = {}
		target_effects = {}
		world_effects = {}
		if success:
			log.append("%s の「%s」は成立し、%dターン後に発現します。" % [country.display_name, policy.get("display_name", ""), delay_turns])
		else:
			_apply_shortage_side_effects(country, world, shortages, log)
			log.append("%s の「%s」は行政不足で延期されました。" % [country.display_name, policy.get("display_name", "")])
	else:
		log.append("%s は「%s」を実行しました。" % [country.display_name, policy.get("display_name", "")])
	var stress_before := int(country.tracks.get("financial_stress", 0))
	country.apply_effects(country_effects)
	if target_country != null and not target_effects.is_empty():
		target_country.apply_effects(target_effects)
		log.append("%s は %s に「%s」を供与しました。" % [country.display_name, target_country.display_name, policy.get("display_name", "")])
	if country.has_assigned_worker("central_bank_staff"):
		var stress_after := int(country.tracks.get("financial_stress", 0))
		if stress_after > stress_before:
			country.tracks["financial_stress"] = stress_after - 1
	world.apply_effects(world_effects)
	if delay_turns <= 0:
		_apply_spillovers(country, countries, policy, log)
	_apply_mutations(country, world, policy, card_index, policy_index, log)
	if country.has_assigned_worker("lobbyist") and card_index.has("rent_seeking"):
		country.deck.push_front(card_index["rent_seeking"])
		log.append("%s はロビイストを使ったため、利権カードがデッキに残りました。" % country.display_name)
	if country.has_assigned_worker("auditor"):
		_remove_one(country, ["corruption_risk", "rent_seeking", "patronage_network"], log)
	if not country.assigned_worker_list().is_empty():
		_resolve_response_task(country, policy, log)
	return log

static func policy_resolution_state(country, policy: Dictionary, paid: Dictionary) -> String:
	var success: bool = bool(paid.get("success", true))
	var shortages: Dictionary = paid.get("shortages", {})
	var delay_turns := int(policy.get("lag", 0))
	if shortages.has("administrative"):
		delay_turns += 1
	if success:
		return "full"
	if shortages.has("political") and shortages.size() == 1:
		return "subsidized"
	if delay_turns > 0:
		return "delayed"
	return "softened"

static func _soften_effects(effects: Dictionary) -> Dictionary:
	var result := {}
	for key in effects.keys():
		var value := int(effects[key])
		result[key] = int(sign(value) * ceili(abs(value) / 2.0))
	return result

static func _boost_positive_effects(effects: Dictionary) -> Dictionary:
	var result := effects.duplicate(true)
	for key in result.keys():
		if int(result[key]) > 0:
			result[key] = int(result[key]) + 1
	return result

static func _liquidity_trap_active(country, policy: Dictionary) -> bool:
	return _has_tag(policy, "monetary") and int(country.tracks.get("expected_inflation", 0)) <= -1

static func _has_tag(policy: Dictionary, tag: String) -> bool:
	return policy.get("tags", []).has(tag)

static func _target_country(source, countries: Array, policy: Dictionary):
	if String(policy.get("target", "")) != "country":
		return null
	var target_index := int(source.selected_target_index)
	if target_index < 0 or target_index >= countries.size():
		return null
	if countries[target_index] == source:
		return null
	return countries[target_index]

static func _schedule_effects(country, policy: Dictionary, country_effects: Dictionary, world_effects: Dictionary, turns: int, _log: Array) -> void:
	country.pending_effects.append({
		"turns": turns,
		"display_name": String(policy.get("display_name", "")),
		"country": country_effects.duplicate(true),
		"world": world_effects.duplicate(true)
	})

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

static func _apply_mutations(country, world, policy: Dictionary, card_index: Dictionary, policy_index: Dictionary, log: Array) -> void:
	var mutations: Dictionary = policy.get("mutations", {})
	var added_cards: Array = mutations.get("add_to_deck", [])
	for i in range(added_cards.size() - 1, -1, -1):
		var card_id := String(added_cards[i])
		if card_index.has(card_id):
			country.deck.push_front(card_index[card_id])
			log.append("%s のデッキに「%s」が追加されました。" % [country.display_name, card_index[card_id].get("display_name", card_id)])
	for card_id in mutations.get("remove_from_deck", []):
		if _remove_card_by_id(country.deck, card_id) or _remove_card_by_id(country.discard, card_id) or _remove_card_by_id(country.hand, card_id):
			log.append("%s のデッキから「%s」が除去されました。" % [country.display_name, card_index.get(card_id, {}).get("display_name", card_id)])
	var world_card_id := String(mutations.get("add_world_card", ""))
	if not world_card_id.is_empty() and card_index.has(world_card_id):
		world.event_discard.append(card_index[world_card_id])
		log.append("世界デッキに「%s」が追加されました。" % card_index[world_card_id].get("display_name", world_card_id))
	for entry in mutations.get("add_to_policy_catalog", []):
		var added_policy := _policy_from_mutation_entry(entry, policy_index)
		if not added_policy.is_empty() and country.add_policy_to_catalog(added_policy):
			log.append("%s の政策カタログに「%s」が追加されました。" % [country.display_name, added_policy.get("display_name", added_policy.get("id", ""))])
	for entry in mutations.get("remove_from_policy_catalog", []):
		var policy_id := _mutation_entry_id(entry)
		if country.remove_policy_from_catalog(policy_id):
			var display_name := String(policy_index.get(policy_id, {}).get("display_name", policy_id))
			log.append("%s の政策カタログから「%s」が除去されました。" % [country.display_name, display_name])
	for replacement in mutations.get("replace_in_policy_catalog", []):
		var old_id := String(replacement.get("from", replacement.get("remove", "")))
		var new_entry = replacement.get("to", replacement.get("add", ""))
		var new_policy := _policy_from_mutation_entry(new_entry, policy_index)
		if old_id.is_empty() or new_policy.is_empty():
			continue
		if country.remove_policy_from_catalog(old_id) and country.add_policy_to_catalog(new_policy):
			var old_name := String(policy_index.get(old_id, {}).get("display_name", old_id))
			log.append("%s の政策カタログで「%s」が「%s」に置き換わりました。" % [country.display_name, old_name, new_policy.get("display_name", new_policy.get("id", ""))])

static func _policy_from_mutation_entry(entry, policy_index: Dictionary) -> Dictionary:
	if entry is Dictionary:
		return entry.duplicate(true)
	var policy_id := String(entry)
	if policy_index.has(policy_id):
		return policy_index[policy_id].duplicate(true)
	return {}

static func _mutation_entry_id(entry) -> String:
	if entry is Dictionary:
		return String(entry.get("id", ""))
	return String(entry)

static func _remove_one(country, ids: Array, log: Array) -> void:
	for card_id in ids:
		if _remove_card_by_id(country.discard, card_id) or _remove_card_by_id(country.deck, card_id):
			log.append("%s の監査官が「%s」を抑え込みました。" % [country.display_name, card_id])
			return

static func _resolve_response_task(country, policy: Dictionary, log: Array) -> void:
	var policy_tags: Array = policy.get("tags", [])
	var selected_index := int(country.selected_response_index)
	if selected_index >= 0 and selected_index < country.hand.size():
		if _try_resolve_response_at(country, selected_index, policy_tags, log):
			return
	for i in range(country.hand.size()):
		if _try_resolve_response_at(country, i, policy_tags, log):
			return

static func _try_resolve_response_at(country, index: int, policy_tags: Array, log: Array) -> bool:
	var card: Dictionary = country.hand[index]
	if String(card.get("type", "")) != "vulnerability":
		return false
	var response: Dictionary = card.get("response", {})
	if response.is_empty() or not _response_matches(policy_tags, response.get("removed_by_tags", [])):
		return false
	var paid: Dictionary = country.pay_costs(response.get("extra_costs", {}))
	if bool(paid.get("success", false)):
		country.hand.remove_at(index)
		country.selected_response_index = -1
		log.append("%s は対応任務で「%s」を除去しました。" % [country.display_name, card.get("display_name", card.get("id", ""))])
	else:
		log.append("%s は「%s」への対応任務を試みましたが %s 不足でした。" % [country.display_name, card.get("display_name", card.get("id", "")), _format_shortages(paid.get("shortages", {}))])
	return true

static func _response_matches(policy_tags: Array, removed_by_tags: Array) -> bool:
	for tag in removed_by_tags:
		if policy_tags.has(tag):
			return true
	return false

static func _remove_card_by_id(cards: Array, card_id: String) -> bool:
	for i in range(cards.size()):
		if String(cards[i].get("id", "")) == card_id:
			cards.remove_at(i)
			return true
	return false
