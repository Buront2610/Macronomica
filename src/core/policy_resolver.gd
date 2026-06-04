extends RefCounted
class_name PolicyResolver

static func resolve_policy(country, countries: Array, world, policy: Dictionary, card_index: Dictionary) -> Array:
	var log: Array = []
	var paid: Dictionary = country.pay_costs(policy.get("costs", {}))
	var success: bool = paid["success"]
	var country_effects: Dictionary = policy.get("effects", {}).get("country", {}).duplicate(true)
	var world_effects: Dictionary = policy.get("effects", {}).get("world", {}).duplicate(true)
	if not success:
		country_effects = _soften_effects(country_effects)
		world_effects = _soften_effects(world_effects)
		country.apply_effects({"political_capital": -1})
		log.append("%s の「%s」はコスト不足で骨抜きになりました。" % [country.display_name, policy.get("display_name", "")])
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
