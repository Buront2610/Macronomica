extends RefCounted
class_name CountryState

const WORKERS := ["bureaucrats", "central_bank_staff", "diplomat", "auditor", "lobbyist"]

var country_id := ""
var display_name := ""
var summary := ""
var legacy_goal := ""
var modules: Array = []
var tags: Array = []
var cost_modifiers: Dictionary = {}
var tracks: Dictionary = {}
var deck: Array = []
var discard: Array = []
var hand: Array = []
var domestic_pressure: Dictionary = {}
var selected_policy: Dictionary = {}
var assigned_worker := "bureaucrats"

func setup(preset: Dictionary, module_defs: Dictionary, built_deck: Array) -> void:
	country_id = preset["country_id"]
	display_name = preset["display_name"]
	summary = preset.get("summary", "")
	legacy_goal = preset.get("legacy_goal", "")
	modules = preset.get("modules", []).duplicate()
	tracks = preset.get("starting_tracks", {}).duplicate(true)
	deck = built_deck.duplicate(true)
	tags = []
	cost_modifiers = {}
	for module_id in modules:
		var module: Dictionary = module_defs.get(module_id, {})
		for tag in module.get("tags", []):
			if not tags.has(tag):
				tags.append(tag)
		for cost_key in module.get("cost_modifiers", {}).keys():
			cost_modifiers[cost_key] = int(cost_modifiers.get(cost_key, 0)) + int(module["cost_modifiers"][cost_key])

func draw_cards(count: int, rng) -> void:
	for _i in range(count):
		if deck.is_empty():
			deck = rng.shuffle(discard)
			discard = []
		if deck.is_empty():
			return
		hand.append(deck.pop_front())

func draw_pressure(pressure_deck: Array, rng) -> void:
	domestic_pressure = rng.pick(pressure_deck)

func apply_effects(effects: Dictionary) -> void:
	for key in effects.keys():
		tracks[key] = int(tracks.get(key, 0)) + int(effects[key])

func has_tag(tag: String) -> bool:
	return tags.has(tag)

func pay_costs(costs: Dictionary) -> Dictionary:
	var adjusted := {}
	var can_fully_pay := true
	for key in costs.keys():
		var cost: int = maxi(0, int(costs[key]) + int(cost_modifiers.get(key, 0)))
		if assigned_worker == "bureaucrats" and key == "administrative":
			cost = maxi(0, cost - 1)
		if assigned_worker == "central_bank_staff" and key == "credibility":
			cost = maxi(0, cost - 1)
		if assigned_worker == "diplomat" and key == "international":
			cost = maxi(0, cost - 1)
		if assigned_worker == "lobbyist" and key == "political":
			cost = maxi(0, cost - 1)
		adjusted[key] = cost
		if key == "political" and int(tracks.get("political_capital", 0)) < cost:
			can_fully_pay = false
		if key == "fiscal" and int(tracks.get("debt", 0)) + cost > 9:
			can_fully_pay = false
	if adjusted.has("political"):
		tracks["political_capital"] = int(tracks.get("political_capital", 0)) - int(adjusted["political"])
	if adjusted.has("fiscal"):
		tracks["debt"] = int(tracks.get("debt", 0)) + int(adjusted["fiscal"])
	return {"costs": adjusted, "success": can_fully_pay}

func clamp_tracks() -> void:
	for key in tracks.keys():
		if ["unemployment", "debt", "financial_stress", "political_capital"].has(key):
			tracks[key] = clampi(int(tracks[key]), 0, 10)
		else:
			tracks[key] = clampi(int(tracks[key]), -5, 10)
