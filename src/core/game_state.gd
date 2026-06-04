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
	"world_event",
	"domestic_update",
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
	"current_account"
]

var turn := 1
var turn_limit := 8
var rng
var world
var countries: Array = []
var log: Array = []
var policy_index: Dictionary = {}
var card_index: Dictionary = {}
var domestic_pressures: Array = []
var is_finished := false
var phase_index := 0
var revealed_policies := false

func new_game() -> void:
	turn = 1
	is_finished = false
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
	turn_limit = int(scenario.get("turn_limit", 8))
	rng = MacronomicaRngScript.new(int(scenario.get("seed", 1)))
	world = WorldStateScript.new(scenario.get("starting_world", {}))
	world.event_deck = rng.shuffle(EventLoaderScript.load_events(EVENTS_PATH))
	countries = []
	for country_id in scenario.get("countries", []):
		var preset := _find_by_id(presets, country_id)
		var deck: Array = DeckBuilderScript.build_deck(preset, module_defs, policy_index, card_index, rng)
		var country = CountryStateScript.new()
		country.setup(preset, module_defs, deck)
		country.draw_cards(5, rng)
		countries.append(country)
	log = ["新しいゲームを開始しました。"]
	_start_turn()
	_assert_invariants("new_game")

func select_policy(country_index: int, hand_index: int) -> void:
	if not _require(_valid_country_index(country_index), "select_policy country index is valid"):
		return
	var country = countries[country_index]
	if hand_index < 0 or hand_index >= country.hand.size():
		_require(false, "select_policy hand index is valid")
		return
	if country.hand[hand_index].get("type", "") != "policy":
		_require(false, "select_policy target is a policy card")
		return
	country.selected_policy = country.hand[hand_index]
	_assert_invariants("select_policy")

func assign_worker(country_index: int, worker_id: String) -> void:
	if not _require(_valid_country_index(country_index), "assign_worker country index is valid"):
		return
	var country = countries[country_index]
	if CountryStateScript.WORKERS.has(worker_id):
		country.assigned_worker = worker_id
		_assert_invariants("assign_worker")
	else:
		_require(false, "assign_worker worker id is known")

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
	log.append("フェーズ: %s" % current_phase_name())
	_assert_invariants("advance_phase")

func resolve_turn() -> void:
	if is_finished:
		return
	if not _require(countries.size() > 0, "resolve_turn has countries"):
		return
	revealed_policies = true
	for country in countries:
		if country.selected_policy.is_empty():
			for card in country.hand:
				if card.get("type", "") == "policy":
					country.selected_policy = card
					break
	for country in countries:
		if country.selected_policy.is_empty():
			continue
		log.append_array(PublicChoiceResolverScript.resolve_pressure(country, country.selected_policy).split("\n", false))
	for country in countries:
		if country.selected_policy.is_empty():
			continue
		log.append_array(PolicyResolverScript.resolve_policy(country, countries, world, country.selected_policy, card_index))
		_move_selected_to_discard(country)
	log.append_array(WorldResolverScript.apply_macro_feedback(countries, world))
	_cleanup_after_resolution()
	if turn >= turn_limit:
		is_finished = true
		log.append("ゲーム終了。最終スコアを確認してください。")
	else:
		turn += 1
		_start_turn()
	_assert_invariants("resolve_turn")

func get_scores() -> Array:
	return ScoringScript.final_scores(countries, world)

func _start_turn() -> void:
	phase_index = 0
	revealed_policies = false
	log.append("---- ターン %d ----" % turn)
	log.append_array(WorldResolverScript.reveal_event(world, countries, rng))
	log.append_array(WorldResolverScript.apply_start_of_turn_cards(countries, world))
	for country in countries:
		country.draw_pressure(domestic_pressures, rng)
		country.draw_cards(max(0, 5 - country.hand.size()), rng)
		country.selected_policy = {}
		country.assigned_worker = "bureaucrats"
		country.clamp_tracks()
	world.clamp_tracks()
	phase_index = PHASES.find("negotiation")
	log.append("フェーズ: %s" % current_phase_name())
	_assert_invariants("_start_turn")

func _cleanup_after_resolution() -> void:
	for country in countries:
		country.selected_policy = {}
		country.clamp_tracks()
	world.clamp_tracks()

func _move_selected_to_discard(country) -> void:
	var selected_id := String(country.selected_policy.get("id", ""))
	for i in range(country.hand.size()):
		if String(country.hand[i].get("id", "")) == selected_id:
			country.discard.append(country.hand[i])
			country.hand.remove_at(i)
			return

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
		_require(CountryStateScript.WORKERS.has(country.assigned_worker), "%s keeps worker assignment valid" % context)
		for track_key in REQUIRED_COUNTRY_TRACKS:
			_require(country.tracks.has(track_key), "%s country %s has track %s" % [context, country.country_id, track_key])
