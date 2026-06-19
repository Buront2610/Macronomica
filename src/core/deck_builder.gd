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
const COOPERATION_POLICY_IDS := [
	"swap_line",
	"joint_fiscal_pact",
	"debt_restructuring",
	"tariff_freeze_pact"
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
			_append_policy_menu_card(cards, policy_index[policy_id], "common")
	for module_id in preset.get("modules", []):
		var module: Dictionary = module_defs.get(module_id, {})
		for card_id in module.get("policy_cards", []):
			if policy_index.has(card_id):
				_append_policy_menu_card(cards, policy_index[card_id], "module:%s" % String(module.get("display_name", module_id)), COMMON_POLICY_IDS + COOPERATION_POLICY_IDS)
	for policy_id in preset.get("unique_policies", []):
		if policy_index.has(policy_id):
			_append_policy_menu_card(cards, policy_index[policy_id], "unique", COMMON_POLICY_IDS + COOPERATION_POLICY_IDS)
	for policy_id in preset.get("catalog_fillers", []):
		if policy_index.has(policy_id):
			_append_policy_menu_card(cards, policy_index[policy_id], "catalog", COMMON_POLICY_IDS + COOPERATION_POLICY_IDS)
	for policy_id in COOPERATION_POLICY_IDS:
		if policy_index.has(policy_id):
			_append_policy_menu_card(cards, policy_index[policy_id], "cooperation")
	return cards

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

static func _append_policy_menu_card(cards: Array, card: Dictionary, menu_source: String, excluded_ids := []) -> void:
	var card_id := String(card.get("id", ""))
	if excluded_ids.has(card_id):
		return
	for existing in cards:
		if String(existing.get("id", "")) == card_id:
			return
	var copy := card.duplicate(true)
	copy["_menu_source"] = menu_source
	cards.append(copy)

static func _policy_count(cards: Array) -> int:
	var count := 0
	for card in cards:
		if String(card.get("type", "")) == "policy":
			count += 1
	return count
