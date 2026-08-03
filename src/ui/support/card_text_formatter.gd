extends RefCounted
class_name CardTextFormatter

const PolicyRecommenderScript := preload("res://src/app/policy_recommender.gd")
const UiCatalogScript := preload("res://src/ui/support/ui_catalog.gd")

static func hand_card_text(card: Dictionary) -> String:
	var kind := "政策" if card.get("type", "") == "policy" else "状態"
	return "%s\n%s" % [kind, UiCatalogScript.short_card_name(card)]

static func planned_text(country, revealed: bool, phase: String, is_finished: bool) -> String:
	if country.selected_policy.is_empty():
		return "[center][b]政策案なし[/b]\n政策メニューから1枚を伏せます[/center]"
	if revealed or phase == "simultaneous_reveal" or phase == "resolution" or is_finished:
		return "[center][b]%s[/b]\n%s[/center]" % [country.selected_policy.get("display_name", ""), tag_line(country.selected_policy)]
	return "[center][b]伏せ札[/b]\n政策案は同時公開まで非公開\nワーカー: %s[/center]" % worker_names(country)

static func card_detail(country, card: Dictionary) -> String:
	if card.is_empty():
		return "[color=#999999]政策メニューから選択してください。[/color]"
	if card.get("type", "") != "policy":
		return "[b]%s[/b]\n状態カード。国家デッキに残る能力や呪いです。" % card.get("display_name", "")
	var pressure := "国内圧力に合致" if PolicyRecommenderScript.pressure_matches(country, card) else "国内圧力と不一致"
	return "[b]%s[/b]  [color=#9aa0a4]%s[/color]\n%s\n\nコスト: %s\n効果: %s\nデッキ変質: %s" % [
		card.get("display_name", ""),
		pressure,
		card.get("description", ""),
		format_costs(card.get("costs", {})),
		format_effects(card.get("effects", {})),
		format_mutations(card.get("mutations", {}))
	]

static func tag_line(card: Dictionary) -> String:
	var tags: Array = card.get("tags", [])
	if tags.is_empty():
		return ""
	return " / ".join(tags.slice(0, mini(3, tags.size())))

static func format_costs(costs: Dictionary) -> String:
	if costs.is_empty():
		return "なし"
	var parts := []
	for key in costs.keys():
		parts.append("%s %+d" % [UiCatalogScript.cost_name(key), int(costs[key])])
	return " / ".join(parts)

static func format_effects(effects: Dictionary) -> String:
	var parts := []
	var scope_labels := {
		"country": "",
		"donor": "供与 ",
		"recipient": "受入 ",
		"world": "世界 "
	}
	for scope in ["country", "donor", "recipient", "world"]:
		for key in effects.get(scope, {}).keys():
			parts.append("%s%s %+d" % [scope_labels[scope], UiCatalogScript.track_name(key), int(effects[scope][key])])
	return " / ".join(parts) if not parts.is_empty() else "なし"

static func format_mutations(mutations: Dictionary) -> String:
	var parts := []
	if mutations.has("add_to_deck"):
		parts.append("追加 " + ", ".join(mutations["add_to_deck"]))
	if mutations.has("remove_from_deck"):
		parts.append("除去 " + ", ".join(mutations["remove_from_deck"]))
	if mutations.has("add_to_policy_catalog"):
		parts.append("政策追加 " + ", ".join(_mutation_entry_names(mutations["add_to_policy_catalog"])))
	if mutations.has("remove_from_policy_catalog"):
		parts.append("政策除去 " + ", ".join(_mutation_entry_names(mutations["remove_from_policy_catalog"])))
	if mutations.has("replace_in_policy_catalog"):
		parts.append("政策置換 " + str(mutations["replace_in_policy_catalog"].size()))
	if mutations.has("add_world_card"):
		parts.append("世界 " + String(mutations["add_world_card"]))
	return " / ".join(parts) if not parts.is_empty() else "なし"

static func _mutation_entry_names(entries: Array) -> Array:
	var names := []
	for entry in entries:
		if entry is Dictionary:
			names.append(String(entry.get("display_name", entry.get("id", ""))))
		else:
			names.append(String(entry))
	return names

static func first_policy(cards: Array) -> Dictionary:
	for card in cards:
		if card.get("type", "") == "policy":
			return card
	return {}

static func worker_names(country) -> String:
	var names := []
	for worker in country.assigned_worker_list():
		names.append(UiCatalogScript.worker_name(String(worker)))
	return " / ".join(names) if not names.is_empty() else "未配置"
