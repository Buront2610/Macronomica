extends RefCounted
class_name WorldResolver

static func reveal_event(world, countries: Array, rng) -> Array:
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
	var effects: Dictionary = event.get("effects", {})
	world.apply_effects(effects.get("world", {}))
	for country in countries:
		country.apply_effects(effects.get("all_countries", {}))
	for tagged in effects.get("tagged_countries", []):
		var tag := String(tagged.get("tag", ""))
		for country in countries:
			if country.has_tag(tag):
				country.apply_effects(tagged.get("effects", {}))
				log.append("%s は「%s」の影響を強く受けました。" % [country.display_name, event.get("display_name", "")])
	return log

static func apply_start_of_turn_cards(countries: Array, world) -> Array:
	var log: Array = []
	for country in countries:
		var sampled := _sample_cards(country.hand + country.discard, 5)
		for card in sampled:
			var effects: Dictionary = card.get("effects", {})
			var on_turn: Dictionary = effects.get("on_turn_start", {})
			if not on_turn.is_empty():
				country.apply_effects(on_turn)
				log.append("%s に「%s」の蓄積効果が出ました。" % [country.display_name, card.get("display_name", "")])
			if int(world.tracks.get("world_demand", 0)) < 0 and effects.has("when_world_demand_negative"):
				country.apply_effects(effects["when_world_demand_negative"])
				log.append("%s は外需悪化に脆さを見せました。" % country.display_name)
			if int(country.tracks.get("exchange_rate", 0)) < -1 and effects.has("when_currency_down"):
				country.apply_effects(effects["when_currency_down"])
				log.append("%s は通貨安で外貨債務負担が増えました。" % country.display_name)
	return log

static func apply_macro_feedback(countries: Array, world) -> Array:
	var log: Array = []
	var simultaneous_austerity := 0
	var cooperation_count := 0
	for country in countries:
		var policy: Dictionary = country.selected_policy
		var tags: Array = policy.get("tags", [])
		if tags.has("austerity"):
			simultaneous_austerity += 1
		if tags.has("cooperation"):
			cooperation_count += 1
		_update_country_macro(country, world, log)
	if simultaneous_austerity >= 3:
		world.apply_effects({"world_demand": -1, "depression": 1})
		log.append("同時緊縮により世界需要が低下し、世界恐慌トラックが上昇しました。")
	if cooperation_count >= 2:
		var boost := cooperation_count - 1
		world.apply_effects({"world_demand": boost, "global_coordination": 1})
		log.append("%d国の協調により世界需要が押し上げられました。" % cooperation_count)
	if int(world.tracks.get("world_demand", 0)) <= -3 or int(world.tracks.get("international_financial_instability", 0)) >= 6 or int(world.tracks.get("protectionism", 0)) >= 5:
		world.apply_effects({"depression": 1})
		log.append("世界危機が深まり、世界恐慌トラックが上昇しました。")
	return log

static func _update_country_macro(country, world, log: Array) -> void:
	var gdp_gap := int(country.tracks.get("gdp_gap", 0))
	if gdp_gap < 0:
		country.apply_effects({"unemployment": 1, "inflation": -1})
	elif gdp_gap > 1:
		country.apply_effects({"unemployment": -1, "inflation": 1})
	if int(country.tracks.get("inflation", 0)) <= 0 and int(country.tracks.get("gdp_gap", 0)) < 0:
		country.apply_effects({"gdp_gap": -1, "unemployment": 1, "debt": 1, "financial_stress": 1})
		log.append("%s でデフレスパイラルが進行しました。" % country.display_name)
	if world.depression_level() >= 4:
		country.apply_effects({"gdp_gap": -1, "unemployment": 1, "financial_stress": 1})
		log.append("世界恐慌が %s の経済を圧迫しています。" % country.display_name)
	country.clamp_tracks()
	world.clamp_tracks()

static func _sample_cards(cards: Array, limit: int) -> Array:
	var result := []
	var count := mini(cards.size(), limit)
	for i in range(count):
		result.append(cards[i])
	return result
