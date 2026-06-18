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
var policy_menu: Array = []
var policy_catalog_deck: Array = []
var policy_catalog_discard: Array = []
var active_agenda: Array = []
var policy_cooldowns: Dictionary = {}
var tracks: Dictionary = {}
var deck: Array = []
var discard: Array = []
var hand: Array = []
var domestic_pressure: Dictionary = {}
var selected_policy: Dictionary = {}
var selected_target_index := -1
var selected_response_index := -1
var assigned_worker := ""
var assigned_workers: Array = []
var election_turn := 4
var election_period := 4
var welfare_score := 0
var welfare_history: Array = []
var track_history: Array = []
var pending_effects: Array = []
var declared_agenda := ""
var support_request_tag := ""
var support_pledge_target_index := -1
var support_pledge_tag := ""
var election_eve_active := false

func setup(preset: Dictionary, module_defs: Dictionary, built_deck: Array, built_policy_menu := []) -> void:
	country_id = preset["country_id"]
	display_name = preset["display_name"]
	summary = preset.get("summary", "")
	legacy_goal = preset.get("legacy_goal", "")
	modules = preset.get("modules", []).duplicate()
	tracks = preset.get("starting_tracks", {}).duplicate(true)
	tracks["expected_inflation"] = int(tracks.get("expected_inflation", tracks.get("inflation", 0)))
	tracks["influence"] = int(tracks.get("influence", 0))
	deck = built_deck.duplicate(true)
	election_turn = int(preset.get("election_turn", 4))
	election_period = int(preset.get("election_period", 4))
	welfare_score = 0
	welfare_history = []
	track_history = [tracks.duplicate(true)]
	pending_effects = []
	declared_agenda = ""
	support_request_tag = ""
	support_pledge_target_index = -1
	support_pledge_tag = ""
	selected_target_index = -1
	selected_response_index = -1
	assigned_worker = ""
	assigned_workers = []
	tags = []
	cost_modifiers = {}
	for module_id in modules:
		var module: Dictionary = module_defs.get(module_id, {})
		for tag in module.get("tags", []):
			if not tags.has(tag):
				tags.append(tag)
		for cost_key in module.get("cost_modifiers", {}).keys():
			cost_modifiers[cost_key] = int(cost_modifiers.get(cost_key, 0)) + int(module["cost_modifiers"][cost_key])
	policy_menu = built_policy_menu.duplicate(true)
	policy_catalog_deck = []
	policy_catalog_discard = []
	active_agenda = []
	for policy in policy_menu:
		if not _is_basic_policy(policy):
			policy_catalog_deck.append(policy.duplicate(true))
	if policy_catalog_deck.is_empty():
		policy_catalog_deck = policy_menu.duplicate(true)
	policy_cooldowns = {}

func draw_catalog_cards(count: int, rng) -> Array:
	var result: Array = []
	for _i in range(count):
		if policy_catalog_deck.is_empty():
			policy_catalog_deck = rng.shuffle(policy_catalog_discard)
			policy_catalog_discard = []
		if policy_catalog_deck.is_empty():
			return result
		result.append(policy_catalog_deck.pop_front())
	return result

func discard_active_agenda() -> void:
	for policy in active_agenda:
		if _is_basic_policy(policy):
			continue
		_append_policy_unique(policy_catalog_discard, policy)
	active_agenda = []

func _append_policy_unique(target: Array, policy: Dictionary) -> void:
	var policy_id := String(policy.get("id", ""))
	for existing in target:
		if String(existing.get("id", "")) == policy_id:
			return
	target.append(policy.duplicate(true))

func _is_basic_policy(policy: Dictionary) -> bool:
	var policy_id := String(policy.get("id", ""))
	if ["fiscal_stimulus", "austerity", "policy_rate_hike", "rate_cut_and_qe", "social_safety_net"].has(policy_id):
		return true
	return String(policy.get("catalog_type", "")) == "basic"

func draw_cards(count: int, rng) -> void:
	for _i in range(count):
		if deck.is_empty():
			deck = rng.shuffle(discard)
			discard = []
		if deck.is_empty():
			return
		hand.append(deck.pop_front())

func draw_pressure(pressure_deck: Array, rng) -> void:
	var pressure: Variant = rng.pick(pressure_deck)
	domestic_pressure = pressure if pressure is Dictionary else {}

func apply_effects(effects: Dictionary) -> void:
	for key in effects.keys():
		tracks[key] = int(tracks.get(key, 0)) + int(effects[key])

func has_tag(tag: String) -> bool:
	return tags.has(tag)

func pay_costs(costs: Dictionary) -> Dictionary:
	var adjusted := {}
	var shortages := {}
	var can_fully_pay := true
	var workers := assigned_worker_list()
	for key in costs.keys():
		var cost: int = maxi(0, int(costs[key]) + int(cost_modifiers.get(key, 0)))
		if key == "political" and election_eve_active:
			cost += 2
		if workers.has("bureaucrats") and key == "administrative":
			cost = maxi(0, cost - 1)
		if workers.has("central_bank_staff") and key == "credibility":
			cost = maxi(0, cost - 1)
		if workers.has("diplomat") and key == "international":
			cost = maxi(0, cost - 1)
		if workers.has("lobbyist") and key == "political":
			cost = maxi(0, cost - 2)
		adjusted[key] = cost
		var capacity := _cost_capacity(key)
		if capacity < cost:
			can_fully_pay = false
			shortages[key] = cost - capacity
	if adjusted.has("political"):
		var political_cost := int(adjusted["political"])
		tracks["political_capital"] = int(tracks.get("political_capital", 0)) - mini(int(tracks.get("political_capital", 0)), political_cost)
	if adjusted.has("fiscal"):
		tracks["debt"] = int(tracks.get("debt", 0)) + int(adjusted["fiscal"])
	return {"costs": adjusted, "shortages": shortages, "success": can_fully_pay}

func assign_worker(worker_id: String) -> void:
	if not WORKERS.has(worker_id):
		return
	assigned_workers = [worker_id]
	assigned_worker = worker_id

func assign_workers(worker_ids: Array) -> void:
	assigned_workers = []
	for worker_id in worker_ids:
		var worker := String(worker_id)
		if WORKERS.has(worker) and not assigned_workers.has(worker):
			assigned_workers.append(worker)
	assigned_worker = String(assigned_workers[0]) if not assigned_workers.is_empty() else ""

func toggle_worker(worker_id: String) -> void:
	if not WORKERS.has(worker_id):
		return
	var workers := assigned_worker_list()
	if workers.has(worker_id):
		workers.erase(worker_id)
	else:
		workers.append(worker_id)
	assign_workers(workers)

func assigned_worker_list() -> Array:
	if not assigned_workers.is_empty():
		return assigned_workers.duplicate()
	if not assigned_worker.is_empty() and WORKERS.has(assigned_worker):
		return [assigned_worker]
	return []

func has_assigned_worker(worker_id: String) -> bool:
	return assigned_worker_list().has(worker_id)

func is_policy_available(policy: Dictionary) -> bool:
	if _is_basic_policy(policy):
		return true
	return int(policy_cooldowns.get(String(policy.get("id", "")), 0)) <= 0

func put_policy_on_cooldown(policy: Dictionary, turns := 1) -> void:
	if _is_basic_policy(policy):
		return
	var policy_id := String(policy.get("id", ""))
	if policy_id.is_empty():
		return
	policy_cooldowns[policy_id] = maxi(int(policy_cooldowns.get(policy_id, 0)), turns)

func tick_policy_cooldowns() -> void:
	var expired := []
	for policy_id in policy_cooldowns.keys():
		policy_cooldowns[policy_id] = int(policy_cooldowns[policy_id]) - 1
		if int(policy_cooldowns[policy_id]) <= 0:
			expired.append(policy_id)
	for policy_id in expired:
		policy_cooldowns.erase(policy_id)

func _cost_capacity(key: String) -> int:
	if key == "political":
		return int(tracks.get("political_capital", 0))
	if key == "fiscal":
		return max(0, 9 - int(tracks.get("debt", 0)))
	if key == "administrative":
		return clampi(int(tracks.get("political_capital", 0)) + 1 - _rent_seeking_in_hand(), 0, 6)
	if key == "credibility":
		var reserve_bonus := 1 if has_tag("reserve_currency") else 0
		return clampi(8 - int(tracks.get("financial_stress", 0)) - maxi(0, int(tracks.get("inflation", 0)) - 2) + reserve_bonus, 0, 6)
	if key == "international":
		return clampi(int(tracks.get("current_account", 0)) + int(tracks.get("exchange_rate", 0)) + 3 + int(tracks.get("influence", 0)) / 3, 0, 6)
	if key == "industrial":
		return clampi(4 + int(tracks.get("gdp_gap", 0)) - int(tracks.get("unemployment", 0)) / 2, 0, 6)
	return 99

func clamp_tracks() -> void:
	for key in tracks.keys():
		if ["unemployment", "debt", "financial_stress", "political_capital", "influence"].has(key):
			tracks[key] = clampi(int(tracks[key]), 0, 10)
		elif key == "expected_inflation":
			tracks[key] = clampi(int(tracks[key]), -5, 5)
		else:
			tracks[key] = clampi(int(tracks[key]), -5, 10)

func is_election_turn(turn: int) -> bool:
	return turn >= election_turn and (turn - election_turn) % election_period == 0

func is_election_eve(turn: int) -> bool:
	return turn + 1 >= election_turn and ((turn + 1) - election_turn) % election_period == 0

func record_track_history() -> void:
	track_history.append(tracks.duplicate(true))

func _rent_seeking_in_hand() -> int:
	var count := 0
	for card in hand:
		if String(card.get("id", "")) == "rent_seeking":
			count += 1
	return count
