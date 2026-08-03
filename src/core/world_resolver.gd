extends RefCounted
class_name WorldResolver

static func reveal_event(world, countries: Array, rng, card_index := {}, policy_index := {}) -> Array:
	var log: Array = []
	if world.event_deck.is_empty():
		world.event_deck = rng.shuffle(world.event_discard)
		world.event_discard = []
	if world.event_deck.is_empty():
		return log
	var event: Dictionary = world.event_deck.pop_front()
	world.current_event = event
	world.event_discard.append(event)
	log.append("世界イベント「%s」: %s" % [event.get("display_name", ""), event.get("message", "")])
	_apply_event_effects(event.get("effects", {}), countries, world, log, String(event.get("display_name", "")), card_index, policy_index)
	if event.has("persistent_crisis"):
		_start_persistent_crisis(world, event, log)
	return log

static func apply_persistent_crises(countries: Array, world) -> Array:
	var log: Array = []
	var remaining: Array = []
	for entry in world.active_crises:
		if not (entry is Dictionary):
			continue
		var crisis: Dictionary = entry
		var name := String(crisis.get("display_name", "持続危機"))
		if _crisis_clear_condition_met(world, crisis):
			log.append("持続危機「%s」は解除条件を満たして終息しました。" % name)
			continue
		_apply_event_effects(crisis.get("effects", {}), countries, world, log, name)
		var turns_left := int(crisis.get("turns", 1)) - 1
		if turns_left <= 0:
			log.append("持続危機「%s」は時間経過で収束しました。" % name)
			continue
		crisis["turns"] = turns_left
		remaining.append(crisis)
		log.append("持続危機「%s」が継続中です。残り%dターン / 解除: %s" % [name, turns_left, String(crisis.get("clear_text", "条件未設定"))])
	world.active_crises = remaining
	return log

static func _start_persistent_crisis(world, event: Dictionary, log: Array) -> void:
	var crisis: Dictionary = event.get("persistent_crisis", {}).duplicate(true)
	crisis["id"] = String(event.get("id", crisis.get("id", "")))
	crisis["display_name"] = String(crisis.get("display_name", event.get("display_name", "持続危機")))
	crisis["turns"] = int(crisis.get("duration", crisis.get("turns", 2)))
	for i in range(world.active_crises.size()):
		if String(world.active_crises[i].get("id", "")) == String(crisis.get("id", "")):
			world.active_crises[i] = crisis
			log.append("持続危機「%s」が再燃しました。解除: %s" % [crisis["display_name"], String(crisis.get("clear_text", "条件未設定"))])
			return
	world.active_crises.append(crisis)
	log.append("持続危機「%s」が発生しました。解除: %s" % [crisis["display_name"], String(crisis.get("clear_text", "条件未設定"))])

static func _apply_event_effects(effects: Dictionary, countries: Array, world, log: Array, source_name: String, card_index := {}, policy_index := {}) -> void:
	world.apply_effects(effects.get("world", {}))
	for country in countries:
		country.apply_effects(effects.get("all_countries", {}))
	for tagged in effects.get("tagged_countries", []):
		var tag := String(tagged.get("tag", ""))
		for country in countries:
			if country.has_tag(tag):
				country.apply_effects(tagged.get("effects", {}))
				log.append("%s は「%s」の影響を強く受けました。" % [country.display_name, source_name])
				_add_state_cards_to_country(country, tagged.get("add_state_cards", []), card_index, log, source_name)
				_add_policies_to_country(country, tagged.get("add_policy_menu", []), policy_index, log, source_name)

static func _add_state_cards_to_country(country, card_ids: Array, card_index, log: Array, source_name: String) -> void:
	if not (card_index is Dictionary):
		return
	for i in range(card_ids.size() - 1, -1, -1):
		var card_id := String(card_ids[i])
		if not card_index.has(card_id):
			continue
		var card: Dictionary = card_index[card_id].duplicate(true)
		if String(card.get("type", "")) == "policy":
			continue
		country.deck.push_front(card)
		log.append("%s の状態デッキに「%s」が「%s」の痕跡として刻まれました。" % [country.display_name, card.get("display_name", card_id), source_name])

static func _add_policies_to_country(country, policy_ids: Array, policy_index, log: Array, source_name: String) -> void:
	if not (policy_index is Dictionary):
		return
	for policy_id_value in policy_ids:
		var policy_id := String(policy_id_value)
		if not policy_index.has(policy_id) or _policy_menu_has(country, policy_id):
			continue
		var policy: Dictionary = policy_index[policy_id].duplicate(true)
		policy["_menu_source"] = "crisis:%s" % source_name
		country.policy_menu.append(policy)
		_append_policy_unique(country.policy_catalog_deck, policy)
		log.append("%s は「%s」を受け、危機対応政策「%s」を得ました。" % [country.display_name, source_name, policy.get("display_name", policy_id)])

static func _append_policy_unique(target: Array, policy: Dictionary) -> void:
	var policy_id := String(policy.get("id", ""))
	for existing in target:
		if String(existing.get("id", "")) == policy_id:
			return
	target.push_front(policy.duplicate(true))

static func _policy_menu_has(country, policy_id: String) -> bool:
	for policy in country.policy_menu:
		if String(policy.get("id", "")) == policy_id:
			return true
	return false

static func _crisis_clear_condition_met(world, crisis: Dictionary) -> bool:
	var clear_when: Dictionary = crisis.get("clear_when", {})
	var world_min: Dictionary = clear_when.get("world_min", {})
	for key in world_min.keys():
		if int(world.tracks.get(key, 0)) < int(world_min[key]):
			return false
	var world_max: Dictionary = clear_when.get("world_max", {})
	for key in world_max.keys():
		if int(world.tracks.get(key, 0)) > int(world_max[key]):
			return false
	return not world_min.is_empty() or not world_max.is_empty()

static func apply_start_of_turn_cards(countries: Array, world) -> Array:
	var log: Array = []
	for country in countries:
		var sampled := _sample_cards(country.hand, 5)
		for card in sampled:
			var effects: Dictionary = card.get("effects", {})
			var on_turn: Dictionary = effects.get("on_turn_start", {})
			if not on_turn.is_empty():
				country.apply_effects(on_turn)
				log.append("%s に「%s」の蓄積効果が出ました。" % [country.display_name, card.get("display_name", "")])
			if _is_commodity_shock(world) and effects.has("when_commodity_shock"):
				country.apply_effects(effects["when_commodity_shock"])
				log.append("%s は資源価格ショックに脆さを見せました。" % country.display_name)
			if int(country.tracks.get("exchange_rate", 0)) < -1 and effects.has("when_currency_down"):
				country.apply_effects(effects["when_currency_down"])
				log.append("%s は通貨安で外貨債務負担が増えました。" % country.display_name)
	return log

static func apply_macro_feedback(countries: Array, world, previous_world_tracks := {}) -> Array:
	var log: Array = []
	var simultaneous_austerity := 0
	for country in countries:
		var policy: Dictionary = country.selected_policy
		var tags: Array = policy.get("tags", [])
		if tags.has("austerity"):
			simultaneous_austerity += 1
		_apply_trade_channel(country, world, log)
	for country in countries:
		_apply_phillips_curve(country, log)
	for country in countries:
		_update_expectations(country, log)
	for country in countries:
		_apply_debt_dynamics(country, world, log)
	for country in countries:
		_apply_capital_mobility(country, world, previous_world_tracks, log)
	for country in countries:
		_apply_deflation_spiral(country, log)
	_apply_financial_contagion(countries, world, log)
	if simultaneous_austerity >= 3:
		world.apply_effects({"world_demand": -1})
		log.append("同時緊縮により世界需要が低下しました。")
	_update_depression_track(world, simultaneous_austerity, log)
	if int(world.tracks.get("depression", 0)) >= 4:
		for country in countries:
			country.apply_effects({"gdp_gap": -1, "unemployment": 1, "financial_stress": 1, "expected_inflation": -1})
			country.clamp_tracks()
		log.append("世界恐慌が各国の需要・雇用・金融安定を圧迫しました。")
	return log

static func _apply_phillips_curve(country, log: Array) -> void:
	var gdp_gap := int(country.tracks.get("gdp_gap", 0))
	if gdp_gap < 0:
		country.apply_effects({"unemployment": 1, "inflation": -1})
	elif gdp_gap > 1:
		country.apply_effects({"unemployment": -1, "inflation": 1})
	country.clamp_tracks()

static func _apply_debt_dynamics(country, world, log: Array) -> void:
	if int(world.tracks.get("world_interest_rate", 0)) >= 1 and int(country.tracks.get("debt", 0)) >= 6:
		var effects := {"debt": 1}
		if country.has_tag("foreign_debt"):
			effects["financial_stress"] = 1
		country.apply_effects(effects)
		log.append("世界金利の高さが %s の債務負担を重くしました。" % country.display_name)
	country.clamp_tracks()
	world.clamp_tracks()

static func _apply_deflation_spiral(country, log: Array) -> void:
	if int(country.tracks.get("inflation", 0)) <= 0 and int(country.tracks.get("gdp_gap", 0)) < 0 and int(country.tracks.get("expected_inflation", 0)) == 1:
		log.append("%s はデフレスパイラルの予兆があります。" % country.display_name)
	if int(country.tracks.get("inflation", 0)) <= 0 and int(country.tracks.get("gdp_gap", 0)) < 0 and int(country.tracks.get("expected_inflation", 0)) <= 0:
		country.apply_effects({"gdp_gap": -1, "unemployment": 1, "debt": 1, "financial_stress": 1})
		log.append("%s でデフレスパイラルが進行しました。" % country.display_name)
	country.clamp_tracks()

static func _apply_trade_channel(country, world, log: Array) -> void:
	var weight := _trade_weight(country)
	if weight <= 0:
		return
	var export_effect := int(sign(int(world.tracks.get("world_demand", 0))))
	if int(country.tracks.get("exchange_rate", 0)) <= -1:
		export_effect += 1
	if int(country.tracks.get("exchange_rate", 0)) >= 2:
		export_effect -= 1
	if int(world.tracks.get("trade_openness", 0)) <= 3:
		export_effect -= 1
	if int(world.tracks.get("protectionism", 0)) >= 5:
		export_effect -= 1
	if export_effect != 0:
		country.apply_effects({"gdp_gap": export_effect * weight, "current_account": export_effect * weight})
		log.append("貿易チャネルが %s の需給と経常収支を動かしました。" % country.display_name)

static func _trade_weight(country) -> int:
	if country.has_tag("exporter"):
		return 2
	if country.has_tag("resource") or country.has_tag("resource_dependence"):
		return 1
	if country.has_tag("domestic_demand"):
		return 1
	return 1

static func _update_expectations(country, log: Array) -> void:
	var expected := int(country.tracks.get("expected_inflation", country.tracks.get("inflation", 0)))
	var actual := int(country.tracks.get("inflation", 0))
	var target := actual
	if country._cost_capacity("credibility") >= 4:
		target = 2
	if expected < target:
		country.tracks["expected_inflation"] = expected + 1
	elif expected > target:
		country.tracks["expected_inflation"] = expected - 1
	if int(country.tracks.get("expected_inflation", 0)) != expected:
		log.append("%s の期待インフレが更新されました。" % country.display_name)

static func _apply_capital_mobility(country, world, previous_world_tracks, log: Array) -> void:
	var previous_rate := int(previous_world_tracks.get("world_interest_rate", world.tracks.get("world_interest_rate", 0))) if previous_world_tracks is Dictionary else int(world.tracks.get("world_interest_rate", 0))
	var current_rate := int(world.tracks.get("world_interest_rate", 0))
	if current_rate > previous_rate and (country.has_tag("fragile_currency") or country.has_tag("foreign_debt")):
		country.apply_effects({"exchange_rate": -1, "financial_stress": 1})
		log.append("世界金利上昇で %s から資本が流出しました。" % country.display_name)
	if int(country.tracks.get("financial_stress", 0)) >= 7:
		country.apply_effects({"exchange_rate": -1})
		log.append("%s は金融ストレスから資本逃避を招きました。" % country.display_name)

static func _apply_financial_contagion(countries: Array, world, log: Array) -> void:
	var shock_count := 0
	for source in countries:
		if int(source.tracks.get("financial_stress", 0)) >= 8:
			var intensity := 2 if source.has_tag("reserve_currency") else 1
			shock_count += intensity
			for target in countries:
				if target != source:
					target.apply_effects({"financial_stress": intensity})
	if shock_count > 0:
		world.apply_effects({"international_financial_instability": shock_count})
		log.append("金融危機が国境を越えて伝染しました。")

static func _update_depression_track(world, simultaneous_austerity: int, log: Array) -> void:
	var crisis_count := 0
	if int(world.tracks.get("world_demand", 0)) <= -3:
		crisis_count += 1
	if int(world.tracks.get("international_financial_instability", 0)) >= 6:
		crisis_count += 1
	if int(world.tracks.get("protectionism", 0)) >= 5:
		crisis_count += 1
	if simultaneous_austerity >= 3:
		crisis_count += 1
	if int(world.tracks.get("depression", 0)) >= 6 and crisis_count > 0:
		crisis_count += 1
	var delta := mini(crisis_count, 3)
	if int(world.tracks.get("global_coordination", 0)) >= 6:
		delta -= 1
	if delta != 0:
		world.apply_effects({"depression": delta})
		log.append("世界恐慌トラックが %d 変化しました。" % delta)

static func _is_commodity_shock(world) -> bool:
	return bool(world.current_event.get("commodity_shock", false))

static func _sample_cards(cards: Array, limit: int) -> Array:
	var result := []
	var count := mini(cards.size(), limit)
	for i in range(count):
		result.append(cards[i])
	return result
