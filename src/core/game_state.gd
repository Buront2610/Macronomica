extends RefCounted
class_name GameState

const MacronomicaRngScript := preload("res://src/core/rng.gd")
const WorldStateScript := preload("res://src/core/world_state.gd")
const CountryStateScript := preload("res://src/core/country_state.gd")
const DeckBuilderScript := preload("res://src/core/deck_builder.gd")
const PolicyResolverScript := preload("res://src/core/policy_resolver.gd")
const PublicChoiceResolverScript := preload("res://src/core/public_choice_resolver.gd")
const WorldResolverScript := preload("res://src/core/world_resolver.gd")
const ScoringScript := preload("res://src/core/scoring.gd")
const CardLoaderScript := preload("res://src/data/card_loader.gd")
const ModuleLoaderScript := preload("res://src/data/module_loader.gd")
const EventLoaderScript := preload("res://src/data/event_loader.gd")

const SCENARIO_PATH := "res://data/scenarios/v0_1.json"
const COUNTRIES_PATH := "res://data/countries/presets.json"
const MODULES_PATH := "res://data/modules/modules.json"
const POLICIES_PATH := "res://data/cards/policies.json"
const PRESSURES_PATH := "res://data/cards/domestic_pressures.json"
const VULNERABILITIES_PATH := "res://data/cards/vulnerabilities.json"
const EVENTS_PATH := "res://data/events/world_events.json"
const PHASES := [
	"negotiation",
	"policy_planning",
	"worker_assignment",
	"simultaneous_reveal",
	"resolution"
]
const REQUIRED_COUNTRY_TRACKS := [
	"gdp_gap",
	"inflation",
	"unemployment",
	"debt",
	"financial_stress",
	"political_capital",
	"exchange_rate",
	"current_account",
	"expected_inflation",
	"influence"
]
const BASIC_POLICY_IDS := [
	"fiscal_stimulus",
	"austerity",
	"policy_rate_hike",
	"rate_cut_and_qe",
	"social_safety_net"
]
const ACTIVE_AGENDA_BASIC_COUNT := 3
const ACTIVE_AGENDA_CATALOG_COUNT := 4
const ACTIVE_AGENDA_MAX := 7

var turn := 1
var turn_limit := 10
var rng
var world
var countries: Array = []
var log: Array = []
var policy_index: Dictionary = {}
var card_index: Dictionary = {}
var domestic_pressures: Array = []
var is_finished := false
var global_collapse := false
var phase_index := 0
var revealed_policies := false
var active_declaration := "cooperation"

func new_game(seed_override := -1) -> void:
	turn = 1
	is_finished = false
	global_collapse = false
	active_declaration = "cooperation"
	phase_index = 0
	revealed_policies = false
	var scenario: Dictionary = _load_json(SCENARIO_PATH)
	var presets: Array = _load_json(COUNTRIES_PATH)
	var module_defs: Dictionary = ModuleLoaderScript.load_modules(MODULES_PATH)
	var policies: Array = CardLoaderScript.load_cards(POLICIES_PATH)
	var vulnerabilities: Array = CardLoaderScript.load_cards(VULNERABILITIES_PATH)
	policy_index = CardLoaderScript.index_by_id(policies)
	card_index = CardLoaderScript.index_by_id(vulnerabilities)
	for key in policy_index.keys():
		card_index[key] = policy_index[key]
	domestic_pressures = CardLoaderScript.load_cards(PRESSURES_PATH)
	turn_limit = int(scenario.get("turn_limit", 10))
	var seed_value := int(seed_override) if int(seed_override) >= 0 else int(scenario.get("seed", 1))
	rng = MacronomicaRngScript.new(seed_value)
	world = WorldStateScript.new(scenario.get("starting_world", {}))
	world.event_deck = rng.shuffle(EventLoaderScript.load_events(EVENTS_PATH))
	countries = []
	for country_id in scenario.get("countries", []):
		var preset := _find_by_id(presets, country_id)
		var deck: Array = DeckBuilderScript.build_deck(preset, module_defs, policy_index, card_index, rng)
		var policy_menu: Array = DeckBuilderScript.build_policy_menu(preset, module_defs, policy_index)
		var country = CountryStateScript.new()
		country.setup(preset, module_defs, deck, policy_menu)
		country.policy_catalog_deck = rng.shuffle(country.policy_catalog_deck)
		countries.append(country)
	log = ["新しいゲームを開始しました。"]
	_start_turn()
	_assert_invariants("new_game")

func select_policy(country_index: int, policy_menu_index: int) -> void:
	if not can_select_policy():
		return
	if not _require(_valid_country_index(country_index), "select_policy country index is valid"):
		return
	var country = countries[country_index]
	var options := policy_options(country_index)
	if policy_menu_index < 0 or policy_menu_index >= options.size():
		_require(false, "select_policy agenda index is valid")
		return
	var policy: Dictionary = options[policy_menu_index]
	if not country.is_policy_available(policy):
		_require(false, "select_policy policy is not on cooldown")
		return
	country.selected_policy = policy
	country.selected_target_index = _default_target_index(country_index, country.selected_policy)
	country.selected_response_index = _default_response_index(country)
	_assert_invariants("select_policy")

func policy_options(country_index: int) -> Array:
	if not _valid_country_index(country_index):
		return []
	var country = countries[country_index]
	if country.active_agenda.is_empty() and current_phase() == "policy_planning":
		_build_active_agendas()
	return country.active_agenda

func select_policy_target(country_index: int, target_index: int) -> void:
	if current_phase() != "policy_planning" or is_finished:
		return
	if not _require(_valid_country_index(country_index), "select_policy_target country index is valid"):
		return
	if not _require(_valid_country_index(target_index), "select_policy_target target index is valid"):
		return
	if not _require(country_index != target_index, "select_policy_target does not target self"):
		return
	var country = countries[country_index]
	if not _requires_country_target(country.selected_policy):
		_require(false, "select_policy_target policy requires country target")
		return
	country.selected_target_index = target_index
	_assert_invariants("select_policy_target")

func select_response_card(country_index: int, hand_index: int) -> void:
	if not (current_phase() == "policy_planning" or current_phase() == "worker_assignment") or is_finished:
		return
	if not _require(_valid_country_index(country_index), "select_response_card country index is valid"):
		return
	var country = countries[country_index]
	if hand_index < 0:
		country.selected_response_index = -1
		_assert_invariants("select_response_card clear")
		return
	if not _require(hand_index < country.hand.size(), "select_response_card hand index is valid"):
		return
	if not _response_candidate_matches(country, hand_index):
		_require(false, "select_response_card matches selected policy")
		return
	country.selected_response_index = hand_index
	_assert_invariants("select_response_card")

func assign_worker(country_index: int, worker_id: String) -> void:
	if not can_assign_worker():
		return
	if not _require(_valid_country_index(country_index), "assign_worker country index is valid"):
		return
	var country = countries[country_index]
	if CountryStateScript.WORKERS.has(worker_id):
		country.assign_worker(worker_id)
		_assert_invariants("assign_worker")
	else:
		_require(false, "assign_worker worker id is known")

func toggle_worker(country_index: int, worker_id: String) -> void:
	if not can_assign_worker():
		return
	if not _require(_valid_country_index(country_index), "toggle_worker country index is valid"):
		return
	var country = countries[country_index]
	if CountryStateScript.WORKERS.has(worker_id):
		country.toggle_worker(worker_id)
		_assert_invariants("toggle_worker")
	else:
		_require(false, "toggle_worker worker id is known")

func assign_workers(country_index: int, worker_ids: Array) -> void:
	if not can_assign_worker():
		return
	if not _require(_valid_country_index(country_index), "assign_workers country index is valid"):
		return
	countries[country_index].assign_workers(worker_ids)
	_assert_invariants("assign_workers")

func declare_agenda(country_index: int, agenda_tag: String) -> void:
	if current_phase() != "negotiation" or is_finished:
		return
	if not _require(_valid_country_index(country_index), "declare agenda country index is valid"):
		return
	countries[country_index].declared_agenda = agenda_tag
	_assert_invariants("declare_agenda")

func request_support(country_index: int, agenda_tag: String) -> void:
	if current_phase() != "negotiation" or is_finished:
		return
	if not _require(_valid_country_index(country_index), "request_support country index is valid"):
		return
	countries[country_index].support_request_tag = agenda_tag
	_assert_invariants("request_support")

func pledge_support(country_index: int, target_index: int, agenda_tag: String) -> void:
	if current_phase() != "negotiation" or is_finished:
		return
	if not _require(_valid_country_index(country_index), "pledge_support country index is valid"):
		return
	if not _require(_valid_country_index(target_index), "pledge_support target index is valid"):
		return
	if not _require(country_index != target_index, "pledge_support target is not self"):
		return
	var country = countries[country_index]
	country.support_pledge_target_index = target_index
	country.support_pledge_tag = agenda_tag
	_assert_invariants("pledge_support")

func current_phase() -> String:
	return PHASES[phase_index]

func current_phase_name() -> String:
	var names := {
		"world_event": "世界イベント公開",
		"domestic_update": "国内情勢更新",
		"negotiation": "国際交渉",
		"policy_planning": "政策計画",
		"worker_assignment": "ワーカー配置",
		"simultaneous_reveal": "同時公開",
		"resolution": "解決処理"
	}
	return names.get(current_phase(), current_phase())

func can_select_policy() -> bool:
	return current_phase() == "policy_planning" and not revealed_policies and not is_finished

func can_assign_worker() -> bool:
	return current_phase() == "worker_assignment" and not revealed_policies and not is_finished

func move_to_phase(phase_key: String) -> void:
	var index := PHASES.find(phase_key)
	if not _require(index >= 0, "phase exists: %s" % phase_key):
		return
	phase_index = index
	if phase_key == "resolution":
		revealed_policies = true
	_assert_invariants("move_to_phase %s" % phase_key)

func reveal_policies() -> void:
	set_policies_revealed(true)

func set_policies_revealed(revealed: bool) -> void:
	revealed_policies = revealed
	_assert_invariants("set_policies_revealed")

func advance_phase() -> void:
	if is_finished:
		return
	if current_phase() == "simultaneous_reveal":
		revealed_policies = true
		phase_index = PHASES.find("resolution")
		log.append("全政策が同時公開されました。")
		resolve_turn()
		_assert_invariants("advance_phase simultaneous_reveal")
		return
	phase_index = mini(phase_index + 1, PHASES.size() - 1)
	if current_phase() == "policy_planning":
		_refresh_active_agendas_after_negotiation()
	log.append("フェーズ: %s" % current_phase_name())
	_assert_invariants("advance_phase")

func resolve_turn() -> void:
	if is_finished:
		return
	if not _require(countries.size() > 0, "resolve_turn has countries"):
		return
	revealed_policies = true
	for country in countries:
		_ensure_selected_policy(country)
		_ensure_selected_target(countries.find(country))
		_ensure_selected_response(country)
	log.append_array(_resolve_support_pledges(countries))
	log.append_array(_resolve_joint_declarations(countries, world))
	var payments := {}
	for i in range(countries.size()):
		var country = countries[i]
		if country.selected_policy.is_empty():
			continue
		country.election_eve_active = country.is_election_eve(turn)
		payments[i] = country.pay_costs(country.selected_policy.get("costs", {}))
		country.election_eve_active = false
	for i in range(countries.size()):
		var country = countries[i]
		if country.selected_policy.is_empty():
			continue
		var paid: Dictionary = payments.get(i, {})
		var ignored_multiplier := 2 if country.is_election_eve(turn) else 1
		var resolution_state := PolicyResolverScript.policy_resolution_state(country, country.selected_policy, paid)
		log.append_array(PublicChoiceResolverScript.resolve_pressure(country, country.selected_policy, resolution_state, ignored_multiplier).split("\n", false))
	for country_index in _resolution_order(countries.size()):
		var country = countries[country_index]
		if country.selected_policy.is_empty():
			continue
		log.append_array(PolicyResolverScript.resolve_paid_policy(country, countries, world, country.selected_policy, card_index, payments.get(country_index, {})))
		_move_selected_to_discard(country)
	var macro_start_world: Dictionary = world.tracks.duplicate(true)
	log.append_array(WorldResolverScript.apply_macro_feedback(countries, world, macro_start_world))
	log.append_array(_resolve_elections())
	log.append_array(_score_turn_welfare())
	_cleanup_after_resolution()
	if _check_global_collapse():
		pass
	elif turn >= turn_limit:
		is_finished = true
		log.append("ゲーム終了。最終スコアを確認してください。")
	else:
		turn += 1
		_start_turn()
	_assert_invariants("resolve_turn")

func get_scores() -> Array:
	return ScoringScript.final_scores(countries, world)

func preview_resolution_outcome() -> Dictionary:
	var preview_countries := []
	for country in countries:
		preview_countries.append(_clone_country(country))
	var preview_world = _clone_world(world)
	var outcome := {"items": [], "macro": {}, "log": []}
	for i in range(preview_countries.size()):
		var country = preview_countries[i]
		_ensure_selected_policy(country)
		_ensure_selected_target(i, preview_countries)
		_ensure_selected_response(country)
	outcome["log"].append_array(_resolve_support_pledges(preview_countries))
	outcome["log"].append_array(_resolve_joint_declarations(preview_countries, preview_world))
	var before_payments := _country_track_snapshots(preview_countries)
	var payments := {}
	for i in _resolution_order(preview_countries.size()):
		var country = preview_countries[i]
		if country.selected_policy.is_empty():
			continue
		country.election_eve_active = country.is_election_eve(turn)
		payments[i] = country.pay_costs(country.selected_policy.get("costs", {}))
		country.election_eve_active = false
	var payment_diffs := _country_track_diffs(before_payments, preview_countries)
	var pressure_diffs := {}
	var pressure_logs := {}
	for i in range(preview_countries.size()):
		var country = preview_countries[i]
		if country.selected_policy.is_empty():
			continue
		var policy: Dictionary = country.selected_policy
		var pressure_before: Dictionary = country.tracks.duplicate(true)
		var paid: Dictionary = payments.get(i, {})
		var ignored_multiplier := 2 if country.is_election_eve(turn) else 1
		var resolution_state := PolicyResolverScript.policy_resolution_state(country, policy, paid)
		var pressure_log := PublicChoiceResolverScript.resolve_pressure(country, policy, resolution_state, ignored_multiplier)
		pressure_diffs[i] = _track_diff(pressure_before, country.tracks)
		pressure_logs[i] = pressure_log
		outcome["log"].append(pressure_log)
	for i in range(preview_countries.size()):
		var country = preview_countries[i]
		if country.selected_policy.is_empty():
			continue
		var policy: Dictionary = country.selected_policy
		var before_countries := _country_track_snapshots(preview_countries)
		var before_world: Dictionary = preview_world.tracks.duplicate(true)
		var before_cards := _card_zone_snapshot(country, preview_world)
		var cost_result: Dictionary = payments.get(i, {})
		var policy_log: Array = PolicyResolverScript.resolve_paid_policy(country, preview_countries, preview_world, policy, card_index, cost_result)
		var after_cards := _card_zone_snapshot(country, preview_world)
		var country_diffs := _country_track_diffs(before_countries, preview_countries)
		if payment_diffs.has(i):
			var own_diff: Dictionary = country_diffs.get(i, {})
			_add_track_diff(own_diff, payment_diffs.get(i, {}))
			country_diffs[i] = own_diff
		var world_diff := _track_diff(before_world, preview_world.tracks)
		outcome["items"].append({
			"country_index": i,
			"policy": policy,
			"worker": ", ".join(country.assigned_worker_list()),
			"pressure_satisfied": _policy_satisfies_pressure(country, policy, PolicyResolverScript.policy_resolution_state(country, policy, cost_result)),
			"pressure_diff": pressure_diffs.get(i, {}),
			"pressure_log": pressure_logs.get(i, ""),
			"costs": cost_result.get("costs", {}),
			"shortages": cost_result.get("shortages", {}),
			"policy_success": bool(cost_result.get("success", false)),
			"country_diffs": country_diffs,
			"world_diff": world_diff,
			"world_effect_keys": world_diff.keys(),
			"mutation_count": _card_zone_change_count(before_cards, after_cards),
			"policy_log": policy_log
		})
		outcome["log"].append_array(policy_log)
	var macro_before_countries := _country_track_snapshots(preview_countries)
	var macro_before_world: Dictionary = preview_world.tracks.duplicate(true)
	var macro_log: Array = WorldResolverScript.apply_macro_feedback(preview_countries, preview_world, macro_before_world)
	outcome["macro"] = {
		"country_diffs": _country_track_diffs(macro_before_countries, preview_countries),
		"world_diff": _track_diff(macro_before_world, preview_world.tracks),
		"log": macro_log
	}
	outcome["log"].append_array(macro_log)
	return outcome

func _start_turn() -> void:
	phase_index = PHASES.find("negotiation")
	revealed_policies = false
	log.append("---- ターン %d ----" % turn)
	log.append_array(WorldResolverScript.reveal_event(world, countries, rng, card_index, policy_index))
	log.append_array(WorldResolverScript.apply_persistent_crises(countries, world))
	for country in countries:
		country.selected_policy = {}
		country.selected_target_index = -1
		country.selected_response_index = -1
		country.assign_workers([])
		country.declared_agenda = ""
		country.support_request_tag = ""
		country.support_pledge_target_index = -1
		country.support_pledge_tag = ""
		country.tick_policy_cooldowns()
		country.draw_cards(2, rng)
	log.append_array(WorldResolverScript.apply_start_of_turn_cards(countries, world))
	for country in countries:
		country.draw_pressure(domestic_pressures, rng)
	_build_active_agendas()
	log.append_array(_resolve_pending_effects())
	for country in countries:
		country.clamp_tracks()
	world.clamp_tracks()
	if _check_global_collapse():
		_assert_invariants("_start_turn global collapse")
		return
	log.append("フェーズ: %s" % current_phase_name())
	_assert_invariants("_start_turn")

func _build_active_agendas() -> void:
	for country in countries:
		country.active_agenda = []
		var basics := _ranked_basic_policies(country)
		for policy in basics:
			_append_agenda_unique(country.active_agenda, policy)
			if _basic_count(country.active_agenda) >= ACTIVE_AGENDA_BASIC_COUNT:
				break
		for policy in country.draw_catalog_cards(ACTIVE_AGENDA_CATALOG_COUNT, rng):
			_append_agenda_unique(country.active_agenda, policy)
		_surface_response_policy(country)
		_surface_declared_policy(country)
		_trim_active_agenda(country)

func _refresh_active_agendas_after_negotiation() -> void:
	for country in countries:
		if country.active_agenda.is_empty():
			_build_active_agendas()
			return
		_surface_declared_policy(country)
		_trim_active_agenda(country)

func _trim_active_agenda(country) -> void:
	while country.active_agenda.size() > ACTIVE_AGENDA_MAX:
		var policy: Dictionary = country.active_agenda.pop_back()
		if not _is_basic_policy(policy):
			country.policy_catalog_discard.push_front(policy)

func _ranked_basic_policies(country) -> Array:
	var basics := []
	for policy in country.policy_menu:
		if _is_basic_policy(policy):
			basics.append(policy)
	basics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _agenda_priority(country, a) > _agenda_priority(country, b)
	)
	return basics

func _agenda_priority(country, policy: Dictionary) -> int:
	var score := 0
	var tags: Array = policy.get("tags", [])
	for tag in country.domestic_pressure.get("demand", {}).get("preferred_policy_tags", []):
		if tags.has(tag):
			score += 100
	for card in country.hand:
		var response: Dictionary = card.get("response", {})
		for tag in response.get("removed_by_tags", []):
			if tags.has(tag):
				score += 80
	var gdp_gap := int(country.tracks.get("gdp_gap", 0))
	var unemployment := int(country.tracks.get("unemployment", 0))
	var inflation := int(country.tracks.get("inflation", 0))
	var financial_stress := int(country.tracks.get("financial_stress", 0))
	if gdp_gap < 0 and (tags.has("fiscal") or tags.has("monetary") or tags.has("employment")):
		score += 35
	if unemployment >= 5 and (tags.has("employment") or tags.has("fiscal")):
		score += 30
	if inflation >= 4 and tags.has("monetary"):
		score += 28
	if financial_stress >= 5 and (tags.has("financial") or tags.has("liquidity")):
		score += 30
	if int(world.tracks.get("depression", 0)) >= 4 and tags.has("cooperation"):
		score += 28
	return score

func _surface_response_policy(country) -> void:
	for card in country.hand:
		var response: Dictionary = card.get("response", {})
		var wanted_tags: Array = response.get("removed_by_tags", [])
		if wanted_tags.is_empty():
			continue
		var policy := _take_policy_matching_tags(country, wanted_tags)
		if not policy.is_empty():
			_append_agenda_unique(country.active_agenda, policy, true)
			return

func _surface_declared_policy(country) -> void:
	var tag := String(country.declared_agenda)
	if tag.is_empty():
		tag = String(country.support_request_tag)
	if tag.is_empty():
		return
	var policy := _take_policy_matching_tags(country, [tag])
	if not policy.is_empty():
		_append_agenda_unique(country.active_agenda, policy, true)

func _take_policy_matching_tags(country, wanted_tags: Array) -> Dictionary:
	for i in range(country.policy_catalog_deck.size()):
		var policy: Dictionary = country.policy_catalog_deck[i]
		if _policy_has_any_tag(policy, wanted_tags):
			country.policy_catalog_deck.remove_at(i)
			return policy
	for i in range(country.policy_catalog_discard.size()):
		var policy: Dictionary = country.policy_catalog_discard[i]
		if _policy_has_any_tag(policy, wanted_tags):
			country.policy_catalog_discard.remove_at(i)
			return policy
	for policy in country.policy_menu:
		if _policy_has_any_tag(policy, wanted_tags):
			return policy
	return {}

func _policy_has_any_tag(policy: Dictionary, wanted_tags: Array) -> bool:
	var tags: Array = policy.get("tags", [])
	for tag in wanted_tags:
		if tags.has(tag):
			return true
	return false

func _append_agenda_unique(target: Array, policy: Dictionary, to_front := false) -> void:
	var policy_id := String(policy.get("id", ""))
	for i in range(target.size()):
		var existing: Dictionary = target[i]
		if String(existing.get("id", "")) == policy_id:
			if to_front and i > 0:
				target.remove_at(i)
				target.push_front(existing)
			return
	if to_front:
		target.push_front(policy.duplicate(true))
	else:
		target.append(policy.duplicate(true))

func _basic_count(agenda: Array) -> int:
	var count := 0
	for policy in agenda:
		if _is_basic_policy(policy):
			count += 1
	return count

func _is_basic_policy(policy: Dictionary) -> bool:
	return BASIC_POLICY_IDS.has(String(policy.get("id", ""))) or String(policy.get("catalog_type", "")) == "basic"

func _cleanup_after_resolution() -> void:
	for country in countries:
		country.selected_policy = {}
		country.discard_active_agenda()
		_discard_hand(country)
		country.selected_target_index = -1
		country.selected_response_index = -1
		country.assign_workers([])
		country.support_request_tag = ""
		country.support_pledge_target_index = -1
		country.support_pledge_tag = ""
		country.clamp_tracks()
		country.record_track_history()
	world.clamp_tracks()

func _move_selected_to_discard(country) -> void:
	if _is_basic_policy(country.selected_policy):
		return
	country.put_policy_on_cooldown(country.selected_policy, 3)
	return

func _discard_hand(country) -> void:
	while not country.hand.is_empty():
		country.discard.append(country.hand.pop_front())

func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open JSON: %s" % path)
		return {}
	return JSON.parse_string(file.get_as_text())

func _find_by_id(items: Array, id_value: String) -> Dictionary:
	for item in items:
		if String(item.get("country_id", item.get("id", ""))) == id_value:
			return item
	return {}

func _clone_country(source) -> CountryStateScript:
	var clone = CountryStateScript.new()
	clone.country_id = source.country_id
	clone.display_name = source.display_name
	clone.summary = source.summary
	clone.legacy_goal = source.legacy_goal
	clone.modules = source.modules.duplicate(true)
	clone.tags = source.tags.duplicate(true)
	clone.cost_modifiers = source.cost_modifiers.duplicate(true)
	clone.policy_menu = source.policy_menu.duplicate(true)
	clone.policy_catalog_deck = source.policy_catalog_deck.duplicate(true)
	clone.policy_catalog_discard = source.policy_catalog_discard.duplicate(true)
	clone.active_agenda = source.active_agenda.duplicate(true)
	clone.policy_cooldowns = source.policy_cooldowns.duplicate(true)
	clone.tracks = source.tracks.duplicate(true)
	clone.deck = source.deck.duplicate(true)
	clone.discard = source.discard.duplicate(true)
	clone.hand = source.hand.duplicate(true)
	clone.domestic_pressure = source.domestic_pressure.duplicate(true)
	clone.selected_policy = source.selected_policy.duplicate(true)
	clone.selected_target_index = source.selected_target_index
	clone.selected_response_index = source.selected_response_index
	clone.assigned_worker = source.assigned_worker
	clone.assigned_workers = source.assigned_worker_list()
	clone.election_turn = source.election_turn
	clone.election_period = source.election_period
	clone.welfare_score = source.welfare_score
	clone.welfare_history = source.welfare_history.duplicate(true)
	clone.track_history = source.track_history.duplicate(true)
	clone.pending_effects = source.pending_effects.duplicate(true)
	clone.declared_agenda = source.declared_agenda
	clone.support_request_tag = source.support_request_tag
	clone.support_pledge_target_index = source.support_pledge_target_index
	clone.support_pledge_tag = source.support_pledge_tag
	clone.election_eve_active = source.election_eve_active
	return clone

func _clone_world(source) -> WorldStateScript:
	var clone = WorldStateScript.new(source.tracks.duplicate(true))
	clone.event_deck = source.event_deck.duplicate(true)
	clone.event_discard = source.event_discard.duplicate(true)
	clone.current_event = source.current_event.duplicate(true)
	clone.active_crises = source.active_crises.duplicate(true)
	return clone

func _preview_policy_cost(country, policy: Dictionary) -> Dictionary:
	var clone = _clone_country(country)
	return clone.pay_costs(policy.get("costs", {}))

func _ensure_selected_policy(country) -> void:
	if not country.selected_policy.is_empty():
		return
	var options: Array = country.active_agenda
	if not options.is_empty():
		country.selected_policy = options[0]
		country.selected_response_index = _default_response_index(country)

func _ensure_selected_target(country_index: int, country_list := []) -> void:
	var list: Array = countries if country_list.is_empty() else country_list
	if country_index < 0 or country_index >= list.size():
		return
	var country = list[country_index]
	if not _requires_country_target(country.selected_policy):
		country.selected_target_index = -1
		return
	if country.selected_target_index < 0 or country.selected_target_index >= list.size() or country.selected_target_index == country_index:
		country.selected_target_index = _default_target_index(country_index, country.selected_policy, list)

func _ensure_selected_response(country) -> void:
	if country.selected_response_index >= 0 and _response_candidate_matches(country, country.selected_response_index):
		return
	country.selected_response_index = _default_response_index(country)

func _default_target_index(country_index: int, policy: Dictionary, country_list := []) -> int:
	var list: Array = countries if country_list.is_empty() else country_list
	if not _requires_country_target(policy):
		return -1
	for offset in range(1, list.size()):
		var index: int = (country_index + offset) % list.size()
		if index != country_index:
			return index
	return -1

func _resolution_order(size: int) -> Array:
	var order := []
	if size <= 0:
		return order
	var start := (turn - 1) % size
	for offset in range(size):
		order.append((start + offset) % size)
	return order

func _requires_country_target(policy: Dictionary) -> bool:
	return String(policy.get("target", "")) == "country"

func _default_response_index(country) -> int:
	for i in range(country.hand.size()):
		if _response_candidate_matches(country, i):
			return i
	return -1

func _response_candidate_matches(country, hand_index: int) -> bool:
	if country.selected_policy.is_empty():
		return false
	if hand_index < 0 or hand_index >= country.hand.size():
		return false
	var card: Dictionary = country.hand[hand_index]
	if String(card.get("type", "")) != "vulnerability":
		return false
	var response: Dictionary = card.get("response", {})
	if response.is_empty():
		return false
	var policy_tags: Array = country.selected_policy.get("tags", [])
	for tag in response.get("removed_by_tags", []):
		if policy_tags.has(tag):
			return true
	return false

func _policy_satisfies_pressure(country, policy: Dictionary, resolution_state = "full") -> bool:
	if String(resolution_state) != "full":
		return false
	var preferred: Array = country.domestic_pressure.get("demand", {}).get("preferred_policy_tags", [])
	var tags: Array = policy.get("tags", [])
	for tag in preferred:
		if tags.has(tag):
			return true
	return false

func _check_global_collapse() -> bool:
	if global_collapse:
		return true
	if ScoringScript.is_global_collapse(world):
		global_collapse = true
		is_finished = true
		log.append("世界恐慌が臨界点に達しました。全員敗北です。")
		return true
	return false

func _resolve_joint_declarations(country_list: Array, target_world) -> Array:
	var lines: Array = []
	var kept := []
	for i in range(country_list.size()):
		var country = country_list[i]
		var declaration := String(country.declared_agenda)
		if declaration.is_empty():
			continue
		var policy: Dictionary = country.selected_policy
		if policy.get("tags", []).has(declaration):
			kept.append(i)
			country.apply_effects({"influence": 1})
			lines.append("%s は共同宣言を遵守しました。" % country.display_name)
		else:
			country.apply_effects({"political_capital": -2, "influence": -1})
			lines.append("%s は共同宣言を裏切り、信頼を失いました。" % country.display_name)
	if kept.size() >= 2:
		var world_effects := {"world_demand": kept.size() - 1}
		if kept.size() >= 3:
			world_effects["international_financial_instability"] = -1
		if kept.size() >= 4:
			world_effects["international_financial_instability"] = -2
			for country in country_list:
				country.apply_effects({"expected_inflation": 1})
		target_world.apply_effects(world_effects)
		lines.append("%d国の共同宣言が世界需要を支えました。" % kept.size())
	return lines

func _resolve_support_pledges(country_list: Array) -> Array:
	var lines: Array = []
	for i in range(country_list.size()):
		var supporter = country_list[i]
		var target_index := int(supporter.support_pledge_target_index)
		var pledge_tag := String(supporter.support_pledge_tag)
		var explicit_pledge := not pledge_tag.is_empty()
		if pledge_tag.is_empty():
			pledge_tag = String(supporter.declared_agenda)
			target_index = _first_support_request_for_tag(country_list, pledge_tag, i)
		if target_index < 0 or target_index >= country_list.size() or target_index == i:
			continue
		var requester = country_list[target_index]
		if String(requester.support_request_tag) != pledge_tag:
			continue
		var policy: Dictionary = supporter.selected_policy
		if policy.get("tags", []).has(pledge_tag):
			supporter.apply_effects({"influence": 1})
			requester.apply_effects(_support_request_effects(pledge_tag))
			lines.append("%s は %s への支援要請（%s）を履行し、影響力を得ました。" % [supporter.display_name, requester.display_name, _support_tag_name(pledge_tag)])
		elif explicit_pledge:
			supporter.apply_effects({"political_capital": -1, "influence": -1})
			lines.append("%s は %s への支援誓約（%s）を履行せず、信頼を失いました。" % [supporter.display_name, requester.display_name, _support_tag_name(pledge_tag)])
	return lines

func _first_support_request_for_tag(country_list: Array, tag: String, except_index: int) -> int:
	if tag.is_empty():
		return -1
	for i in range(country_list.size()):
		if i == except_index:
			continue
		if String(country_list[i].support_request_tag) == tag:
			return i
	return -1

func _support_request_effects(tag: String) -> Dictionary:
	if tag == "liquidity" or tag == "qe":
		return {"financial_stress": -1}
	if tag == "debt":
		return {"debt": -1, "financial_stress": -1}
	if tag == "trade":
		return {"current_account": 1}
	if tag == "cooperation":
		return {"political_capital": 1}
	if tag == "currency":
		return {"exchange_rate": 1}
	return {"political_capital": 1}

func _support_tag_name(tag: String) -> String:
	var names := {
		"liquidity": "流動性",
		"qe": "流動性",
		"debt": "債務",
		"trade": "通商",
		"cooperation": "協調",
		"currency": "通貨"
	}
	return names.get(tag, tag)

func _resolve_pending_effects() -> Array:
	var lines: Array = []
	for country in countries:
		var remaining := []
		for entry in country.pending_effects:
			var pending: Dictionary = entry
			pending["turns"] = int(pending.get("turns", 0)) - 1
			if int(pending["turns"]) <= 0:
				country.apply_effects(pending.get("country", {}))
				world.apply_effects(pending.get("world", {}))
				lines.append("%s の「%s」が実施ラグを経て発現しました。" % [country.display_name, pending.get("display_name", "政策")])
			else:
				remaining.append(pending)
		country.pending_effects = remaining
	return lines

func _resolve_elections() -> Array:
	var lines: Array = []
	for country in countries:
		if not country.is_election_turn(turn):
			continue
		if int(country.tracks.get("political_capital", 0)) >= 5:
			country.apply_effects({"political_capital": 2})
			lines.append("%s は選挙で政権を維持しました。" % country.display_name)
		else:
			country.tracks["political_capital"] = 4
			if card_index.has("reform_fatigue"):
				country.deck.push_front(card_index["reform_fatigue"])
			if not country.pending_effects.is_empty():
				country.pending_effects.pop_front()
			lines.append("%s は選挙で政権交代し、改革疲れが残りました。" % country.display_name)
	return lines

func _score_turn_welfare() -> Array:
	var lines: Array = []
	for country in countries:
		var points := ScoringScript.welfare_points(country)
		country.welfare_score += points
		country.welfare_history.append({"turn": turn, "points": points, "total": country.welfare_score})
		lines.append("%s は厚生点 +%d（累計 %d）を得ました。" % [country.display_name, points, country.welfare_score])
	return lines

func _country_track_snapshots(country_list: Array) -> Array:
	var result := []
	for country in country_list:
		result.append(country.tracks.duplicate(true))
	return result

func _country_track_diffs(before: Array, after: Array) -> Dictionary:
	var result := {}
	for i in range(mini(before.size(), after.size())):
		var diff := _track_diff(before[i], after[i].tracks)
		if not diff.is_empty():
			result[i] = diff
	return result

func _track_diff(before: Dictionary, after: Dictionary) -> Dictionary:
	var diff := {}
	var keys := []
	for key in before.keys():
		if not keys.has(key):
			keys.append(key)
	for key in after.keys():
		if not keys.has(key):
			keys.append(key)
	for key in keys:
		var delta := int(after.get(key, 0)) - int(before.get(key, 0))
		if delta != 0:
			diff[key] = delta
	return diff

func _add_track_diff(target: Dictionary, diff: Dictionary) -> void:
	for key in diff.keys():
		target[key] = int(target.get(key, 0)) + int(diff[key])
		if int(target[key]) == 0:
			target.erase(key)

func _card_zone_snapshot(country, preview_world) -> Dictionary:
	return {
		"deck": _card_ids(country.deck),
		"discard": _card_ids(country.discard),
		"hand": _card_ids(country.hand),
		"world_deck": _card_ids(preview_world.event_deck),
		"world_discard": _card_ids(preview_world.event_discard)
	}

func _card_ids(cards: Array) -> Array:
	var ids := []
	for card in cards:
		ids.append(String(card.get("id", "")))
	ids.sort()
	return ids

func _card_zone_change_count(before: Dictionary, after: Dictionary) -> int:
	var count := 0
	for key in before.keys():
		if before.get(key, []) != after.get(key, []):
			count += 1
	return count

func _valid_country_index(country_index: int) -> bool:
	return country_index >= 0 and country_index < countries.size()

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("Contract failed: %s" % message)
	return false

func _assert_invariants(context: String) -> void:
	_require(turn >= 1, "%s keeps turn positive" % context)
	_require(turn <= turn_limit, "%s keeps turn inside turn limit" % context)
	_require(turn_limit > 0, "%s has positive turn limit" % context)
	_require(phase_index >= 0 and phase_index < PHASES.size(), "%s keeps phase index valid" % context)
	_require(countries.size() > 0, "%s has countries" % context)
	_require(world != null, "%s has world state" % context)
	for country in countries:
		for worker in country.assigned_worker_list():
			_require(CountryStateScript.WORKERS.has(worker), "%s keeps worker assignment valid" % context)
		if not is_finished and (current_phase() == "negotiation" or current_phase() == "policy_planning"):
			_require(country.active_agenda.size() >= 4, "%s country %s has enough active agenda options" % [context, country.country_id])
			_require(country.active_agenda.size() <= ACTIVE_AGENDA_MAX, "%s country %s keeps active agenda bounded" % [context, country.country_id])
		for card in country.deck + country.hand + country.discard:
			_require(String(card.get("type", "")) != "policy", "%s country %s keeps policy cards out of the state deck" % [context, country.country_id])
		for track_key in REQUIRED_COUNTRY_TRACKS:
			_require(country.tracks.has(track_key), "%s country %s has track %s" % [context, country.country_id, track_key])
