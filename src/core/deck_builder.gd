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
	"structural_reform",
	"progressive_tax_reform",
	"social_safety_net",
	"joint_fiscal_pact",
	"anti_corruption_drive"
]

static func build_deck(preset: Dictionary, module_defs: Dictionary, policy_index: Dictionary, card_index: Dictionary, rng) -> Array:
	var cards: Array = []
	for policy_id in COMMON_POLICY_IDS:
		if policy_index.has(policy_id):
			cards.append(policy_index[policy_id])
	for module_id in preset.get("modules", []):
		var module: Dictionary = module_defs.get(module_id, {})
		for card_id in module.get("deck_cards", []):
			if policy_index.has(card_id):
				cards.append(policy_index[card_id])
			elif card_index.has(card_id):
				cards.append(card_index[card_id])
	var country_id := String(preset.get("country_id", ""))
	if country_id == "reserve_currency_financial_power" and policy_index.has("swap_line"):
		cards.append(policy_index["swap_line"])
	if country_id == "export_industrial_deflationary_state" and policy_index.has("export_subsidy"):
		cards.append(policy_index["export_subsidy"])
	if country_id == "resource_exporter_state" and policy_index.has("stabilization_fund_drawdown"):
		cards.append(policy_index["stabilization_fund_drawdown"])
	if country_id == "resource_exporter_state" and policy_index.has("resource_diversification"):
		cards.append(policy_index["resource_diversification"])
	if country_id == "emerging_foreign_debt_state" and policy_index.has("infrastructure_investment"):
		cards.append(policy_index["infrastructure_investment"])
	if country_id == "emerging_foreign_debt_state" and policy_index.has("capital_controls"):
		cards.append(policy_index["capital_controls"])
	if country_id == "emerging_foreign_debt_state" and policy_index.has("debt_restructuring"):
		cards.append(policy_index["debt_restructuring"])
	return rng.shuffle(cards)
