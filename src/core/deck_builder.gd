extends RefCounted
class_name DeckBuilder

const COMMON_POLICY_IDS := [
	"fiscal_stimulus",
	"austerity",
	"policy_rate_hike",
	"rate_cut_and_qe",
	"tariff_barrier",
	"industrial_policy",
	"financial_regulation",
	"social_safety_net"
]
const TARGET_STATE_DECK_SIZE := 12
const MODULE_POLICY_COUNT := 6
const COOPERATION_POLICY_IDS := [
	"swap_line",
	"joint_fiscal_pact",
	"debt_restructuring",
	"tariff_freeze_pact"
]
const MODULE_POLICY_FILLER_IDS := [
	"structural_reform",
	"progressive_tax_reform",
	"anti_corruption_drive",
	"export_subsidy",
	"infrastructure_investment",
	"capital_controls",
	"resource_diversification",
	"stabilization_fund_drawdown"
]

static func build_deck(preset: Dictionary, module_defs: Dictionary, policy_index: Dictionary, card_index: Dictionary, rng) -> Array:
	var cards: Array = []
	var state_cards: Array = []
	for module_id in preset.get("modules", []):
		var module: Dictionary = module_defs.get(module_id, {})
		for card_id in module.get("deck_cards", []):
			if card_index.has(card_id) and not policy_index.has(card_id):
				_append_unique(state_cards, card_index[card_id])
	for card_id in preset.get("deck_fillers", []):
		if state_cards.size() >= TARGET_STATE_DECK_SIZE:
			break
		if card_index.has(card_id) and not policy_index.has(card_id):
			_append_unique(state_cards, card_index[card_id])
	_append_state_fillers(state_cards, preset.get("deck_fillers", []), card_index)
	for state_card in state_cards.slice(0, TARGET_STATE_DECK_SIZE):
		cards.append(state_card.duplicate(true))
	if cards.size() != TARGET_STATE_DECK_SIZE:
		push_error("%s state deck has %d cards, expected %d." % [preset.get("country_id", ""), cards.size(), TARGET_STATE_DECK_SIZE])
	if _policy_count(cards) != 0:
		push_error("%s state deck contains %d policy cards, expected 0." % [preset.get("country_id", ""), _policy_count(cards)])
	return rng.shuffle(cards)

static func build_policy_menu(preset: Dictionary, module_defs: Dictionary, policy_index: Dictionary) -> Array:
	var cards: Array = []
	for policy_id in COMMON_POLICY_IDS:
		if policy_index.has(policy_id):
			_append_unique(cards, policy_index[policy_id])
	for module_id in preset.get("modules", []):
		var module: Dictionary = module_defs.get(module_id, {})
		for card_id in module.get("policy_cards", []):
			if policy_index.has(card_id):
				_append_unique_by_id(cards, policy_index[card_id], COMMON_POLICY_IDS + COOPERATION_POLICY_IDS)
	for policy_id in preset.get("unique_policies", []):
		if policy_index.has(policy_id):
			_append_unique_by_id(cards, policy_index[policy_id], COMMON_POLICY_IDS + COOPERATION_POLICY_IDS)
	_append_module_policy_fillers(cards, policy_index)
	for policy_id in COOPERATION_POLICY_IDS:
		if policy_index.has(policy_id):
			_append_unique(cards, policy_index[policy_id])
	return cards

static func _append_module_policy_fillers(cards: Array, policy_index: Dictionary) -> void:
	var filler_index := 0
	while cards.size() < COMMON_POLICY_IDS.size() + MODULE_POLICY_COUNT:
		var policy_id: String = MODULE_POLICY_FILLER_IDS[filler_index % MODULE_POLICY_FILLER_IDS.size()]
		filler_index += 1
		if policy_index.has(policy_id):
			_append_copy(cards, policy_id, policy_index, {})

static func _append_state_fillers(cards: Array, filler_ids: Array, card_index: Dictionary) -> void:
	if filler_ids.is_empty():
		return
	var filler_index := 0
	var attempts := 0
	while cards.size() < TARGET_STATE_DECK_SIZE and attempts < filler_ids.size() * TARGET_STATE_DECK_SIZE:
		var card_id := String(filler_ids[filler_index % filler_ids.size()])
		filler_index += 1
		attempts += 1
		if card_index.has(card_id):
			cards.append(card_index[card_id].duplicate(true))

static func _append_unique(cards: Array, card: Dictionary) -> void:
	var card_id := String(card.get("id", ""))
	for existing in cards:
		if String(existing.get("id", "")) == card_id:
			return
	cards.append(card)

static func _append_unique_by_id(cards: Array, card: Dictionary, excluded_ids: Array) -> void:
	var card_id := String(card.get("id", ""))
	if excluded_ids.has(card_id):
		return
	_append_unique(cards, card)

static func _append_copy(cards: Array, card_id: String, policy_index: Dictionary, card_index: Dictionary) -> void:
	if policy_index.has(card_id):
		cards.append(policy_index[card_id].duplicate(true))
	elif card_index.has(card_id):
		cards.append(card_index[card_id].duplicate(true))

static func _policy_count(cards: Array) -> int:
	var count := 0
	for card in cards:
		if String(card.get("type", "")) == "policy":
			count += 1
	return count
