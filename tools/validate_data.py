from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
COUNTRY_EFFECT_KEYS = {
    "gdp_gap",
    "inflation",
    "expected_inflation",
    "unemployment",
    "debt",
    "financial_stress",
    "political_capital",
    "exchange_rate",
    "current_account",
    "influence",
}
WORLD_EFFECT_KEYS = {
    "world_demand",
    "world_interest_rate",
    "trade_openness",
    "international_financial_instability",
    "depression",
    "protectionism",
    "global_coordination",
}
CONDITION_KEYS = {
    "on_turn_start",
    "when_currency_down",
    "when_commodity_shock",
}
POLICY_EFFECT_SCOPES = {"country", "donor", "recipient", "world"}
EVENT_EFFECT_SCOPES = {"world", "all_countries", "tagged_countries"}
COST_KEYS = {"fiscal", "political", "administrative", "credibility", "international", "industrial"}
COMMON_POLICY_IDS = [
    "fiscal_stimulus",
    "austerity",
    "policy_rate_hike",
    "rate_cut_and_qe",
    "tariff_barrier",
    "industrial_policy",
    "financial_regulation",
    "social_safety_net",
]
COOPERATION_POLICY_IDS = [
    "swap_line",
    "joint_fiscal_pact",
    "debt_restructuring",
    "tariff_freeze_pact",
]
MODULE_POLICY_FILLER_IDS = [
    "structural_reform",
    "progressive_tax_reform",
    "anti_corruption_drive",
    "export_subsidy",
    "infrastructure_investment",
    "capital_controls",
    "resource_diversification",
    "stabilization_fund_drawdown",
]
TARGET_STATE_DECK_SIZE = 12
MIN_POLICY_MENU_SIZE = 12
MODULE_POLICY_COUNT = 6


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def ids(items, key="id"):
    return {item[key] for item in items}


def add_duplicate_errors(
    errors: list[str],
    label: str,
    items,
    key: str = "id",
    seen: dict[str, str] | None = None,
) -> dict[str, str]:
    if seen is None:
        seen = {}
    local_seen: set[str] = set()
    for item in items:
        item_id = item.get(key)
        if not item_id:
            errors.append(f"{label} entry is missing {key}")
            continue
        if item_id in local_seen:
            errors.append(f"{label} has duplicate {key} {item_id}")
        if item_id in seen:
            errors.append(f"{label} {item_id} duplicates {seen[item_id]}")
        local_seen.add(item_id)
        seen[item_id] = label
    return seen


def validate_effect_keys(errors: list[str], owner: str, effects: dict, allowed_scopes: set[str]) -> None:
    for scope, value in effects.items():
        if scope not in allowed_scopes:
            errors.append(f"{owner} has unknown effect scope {scope}")
            continue
        if scope in {"country", "donor", "recipient"}:
            validate_track_effects(errors, owner, value, COUNTRY_EFFECT_KEYS)
        elif scope == "world":
            validate_track_effects(errors, owner, value, WORLD_EFFECT_KEYS)


def validate_state_effect_keys(errors: list[str], owner: str, effects: dict) -> None:
    for condition, value in effects.items():
        if condition not in CONDITION_KEYS:
            errors.append(f"{owner} has unknown condition {condition}")
            continue
        validate_track_effects(errors, owner, value, COUNTRY_EFFECT_KEYS)


def validate_event_effect_keys(
    errors: list[str],
    owner: str,
    effects: dict,
    card_ids: set[str] | None = None,
    policy_ids: set[str] | None = None,
) -> None:
    for scope, value in effects.items():
        if scope not in EVENT_EFFECT_SCOPES:
            errors.append(f"{owner} has unknown event effect scope {scope}")
            continue
        if scope == "world":
            validate_track_effects(errors, owner, value, WORLD_EFFECT_KEYS)
        elif scope == "all_countries":
            validate_track_effects(errors, owner, value, COUNTRY_EFFECT_KEYS)
        elif scope == "tagged_countries":
            if not isinstance(value, list):
                errors.append(f"{owner} tagged_countries must be a list")
                continue
            for index, tagged in enumerate(value):
                if not isinstance(tagged, dict):
                    errors.append(f"{owner} tagged_countries[{index}] must be an object")
                    continue
                if not tagged.get("tag"):
                    errors.append(f"{owner} tagged_countries[{index}] has no tag")
                validate_track_effects(
                    errors,
                    f"{owner} tagged_countries[{index}]",
                    tagged.get("effects", {}),
                    COUNTRY_EFFECT_KEYS,
                )
                for card_id in tagged.get("add_state_cards", []):
                    if card_ids is not None and card_id not in card_ids:
                        errors.append(f"{owner} tagged_countries[{index}] adds missing state card {card_id}")
                    if policy_ids is not None and card_id in policy_ids:
                        errors.append(f"{owner} tagged_countries[{index}] add_state_cards references policy {card_id}")
                for policy_id in tagged.get("add_policy_menu", []):
                    if policy_ids is not None and policy_id not in policy_ids:
                        errors.append(f"{owner} tagged_countries[{index}] adds missing policy {policy_id}")


def validate_persistent_crisis(errors: list[str], owner: str, crisis: dict) -> None:
    if not isinstance(crisis, dict):
        errors.append(f"{owner} persistent_crisis must be an object")
        return
    duration = crisis.get("duration", crisis.get("turns"))
    if not isinstance(duration, int) or duration < 1:
        errors.append(f"{owner} persistent_crisis duration must be a positive integer")
    validate_event_effect_keys(errors, f"{owner} persistent_crisis", crisis.get("effects", {}))
    clear_when = crisis.get("clear_when", {})
    if not isinstance(clear_when, dict) or not clear_when:
        errors.append(f"{owner} persistent_crisis clear_when must be a non-empty object")
        return
    for scope in ("world_min", "world_max"):
        values = clear_when.get(scope, {})
        if values and not isinstance(values, dict):
            errors.append(f"{owner} persistent_crisis {scope} must be an object")
            continue
        for key, value in values.items():
            if key not in WORLD_EFFECT_KEYS:
                errors.append(f"{owner} persistent_crisis {scope} has unknown world track {key}")
            if not isinstance(value, int):
                errors.append(f"{owner} persistent_crisis {scope}.{key} must be an integer")


def validate_response(errors: list[str], owner: str, response: dict) -> None:
    if not isinstance(response, dict):
        errors.append(f"{owner} response must be an object")
        return
    removed_by_tags = response.get("removed_by_tags", [])
    if not isinstance(removed_by_tags, list) or not removed_by_tags:
        errors.append(f"{owner} response.removed_by_tags must be a non-empty list")
    else:
        for tag in removed_by_tags:
            if not isinstance(tag, str) or not tag:
                errors.append(f"{owner} response.removed_by_tags entries must be non-empty strings")
    extra_costs = response.get("extra_costs", {})
    if not isinstance(extra_costs, dict) or not extra_costs:
        errors.append(f"{owner} response.extra_costs must be a non-empty object")
    else:
        for cost_key, value in extra_costs.items():
            if cost_key not in COST_KEYS:
                errors.append(f"{owner} response has unknown cost {cost_key}")
            if not isinstance(value, int) or value < 0:
                errors.append(f"{owner} response cost {cost_key} must be a non-negative integer")


def validate_track_effects(errors: list[str], owner: str, effects: dict, allowed_keys: set[str]) -> None:
    if not isinstance(effects, dict):
        errors.append(f"{owner} effects must be an object")
        return
    for key, value in effects.items():
        if key not in allowed_keys:
            errors.append(f"{owner} writes unknown track {key}")
        if not isinstance(value, int):
            errors.append(f"{owner} effect {key} must be an integer")


def build_deck_ids(country: dict, modules: list[dict], policy_ids: set[str], card_ids: set[str]) -> list[str]:
    module_by_id = {module["id"]: module for module in modules}
    deck_ids: list[str] = []
    state_card_ids: list[str] = []

    def append_unique(target: list[str], card_id: str) -> None:
        if card_id not in target:
            target.append(card_id)

    for module_id in country.get("modules", []):
        module = module_by_id.get(module_id, {})
        for card_id in module.get("deck_cards", []):
            if card_id in card_ids and card_id not in policy_ids:
                append_unique(state_card_ids, card_id)
    for card_id in country.get("deck_fillers", []):
        if len(state_card_ids) >= TARGET_STATE_DECK_SIZE:
            break
        if card_id in card_ids and card_id not in policy_ids:
            append_unique(state_card_ids, card_id)
    filler_ids = list(country.get("deck_fillers", []))
    filler_index = 0
    attempts = 0
    while len(state_card_ids) < TARGET_STATE_DECK_SIZE and filler_ids and attempts < len(filler_ids) * TARGET_STATE_DECK_SIZE:
        card_id = filler_ids[filler_index % len(filler_ids)]
        filler_index += 1
        attempts += 1
        if card_id in card_ids and card_id not in policy_ids:
            state_card_ids.append(card_id)
    deck_ids.extend(state_card_ids[:TARGET_STATE_DECK_SIZE])
    return deck_ids


def build_policy_menu_ids(country: dict, modules: list[dict], policy_ids: set[str]) -> list[str]:
    module_by_id = {module["id"]: module for module in modules}
    menu_ids: list[str] = []

    def append_unique(card_id: str) -> None:
        if card_id in policy_ids and card_id not in menu_ids:
            menu_ids.append(card_id)

    for policy_id in COMMON_POLICY_IDS:
        append_unique(policy_id)
    for module_id in country.get("modules", []):
        module = module_by_id.get(module_id, {})
        for card_id in module.get("policy_cards", []):
            if card_id not in COMMON_POLICY_IDS and card_id not in COOPERATION_POLICY_IDS:
                append_unique(card_id)
    for policy_id in country.get("unique_policies", []):
        if policy_id not in COMMON_POLICY_IDS and policy_id not in COOPERATION_POLICY_IDS:
            append_unique(policy_id)
    filler_index = 0
    while len(menu_ids) < len(COMMON_POLICY_IDS) + MODULE_POLICY_COUNT:
        policy_id = MODULE_POLICY_FILLER_IDS[filler_index % len(MODULE_POLICY_FILLER_IDS)]
        filler_index += 1
        append_unique(policy_id)
    for policy_id in COOPERATION_POLICY_IDS:
        append_unique(policy_id)
    return menu_ids


def policy_count(deck_ids: list[str], policy_ids: set[str]) -> int:
    return sum(1 for card_id in deck_ids if card_id in policy_ids)


def main() -> int:
    errors: list[str] = []
    countries = load_json(DATA / "countries" / "presets.json")
    modules = load_json(DATA / "modules" / "modules.json")
    policies = load_json(DATA / "cards" / "policies.json")
    pressures = load_json(DATA / "cards" / "domestic_pressures.json")
    vulnerabilities = load_json(DATA / "cards" / "vulnerabilities.json")
    events = load_json(DATA / "events" / "world_events.json")
    scenario = load_json(DATA / "scenarios" / "v0_1.json")

    add_duplicate_errors(errors, "country", countries, "country_id")
    add_duplicate_errors(errors, "module", modules)
    content_ids: dict[str, str] = {}
    add_duplicate_errors(errors, "policy", policies, seen=content_ids)
    add_duplicate_errors(errors, "domestic pressure", pressures, seen=content_ids)
    add_duplicate_errors(errors, "state card", vulnerabilities, seen=content_ids)
    add_duplicate_errors(errors, "world event", events, seen=content_ids)

    country_ids = {country["country_id"] for country in countries}
    module_ids = ids(modules)
    policy_ids = ids(policies)
    card_ids = policy_ids | ids(vulnerabilities)

    for country in countries:
        election_turn = country.get("election_turn")
        if not isinstance(election_turn, int) or election_turn < 1:
            errors.append(f"{country['country_id']} election_turn must be a positive integer")
        validate_track_effects(errors, f"{country['country_id']} starting_tracks", country.get("starting_tracks", {}), COUNTRY_EFFECT_KEYS)
        for module_id in country.get("modules", []):
            if module_id not in module_ids:
                errors.append(f"{country['country_id']} references missing module {module_id}")
        for policy_id in country.get("unique_policies", []):
            if policy_id not in policy_ids:
                errors.append(f"{country['country_id']} references missing unique policy {policy_id}")
        for card_id in country.get("deck_fillers", []):
            if card_id not in card_ids:
                errors.append(f"{country['country_id']} references missing deck filler {card_id}")
        deck_ids = build_deck_ids(country, modules, policy_ids, card_ids)
        if len(deck_ids) != TARGET_STATE_DECK_SIZE:
            errors.append(f"{country['country_id']} builds {len(deck_ids)} state deck cards, expected {TARGET_STATE_DECK_SIZE}")
        deck_policy_count = policy_count(deck_ids, policy_ids)
        if deck_policy_count != 0:
            errors.append(f"{country['country_id']} state deck contains {deck_policy_count} policies, expected 0")
        menu_ids = build_policy_menu_ids(country, modules, policy_ids)
        if len(menu_ids) < MIN_POLICY_MENU_SIZE:
            errors.append(f"{country['country_id']} policy menu has {len(menu_ids)} policies, expected at least {MIN_POLICY_MENU_SIZE}")

    for module in modules:
        if not isinstance(module.get("deck_cards", []), list):
            errors.append(f"{module['id']} deck_cards must be a list")
            continue
        for card_id in module.get("deck_cards", []):
            if not isinstance(card_id, str):
                errors.append(f"{module['id']} deck card id must be a string")
                continue
            if card_id not in card_ids:
                errors.append(f"{module['id']} references missing deck card {card_id}")
            if card_id in policy_ids:
                errors.append(f"{module['id']} deck_cards references policy {card_id}; use policy_cards")
        if not isinstance(module.get("policy_cards", []), list):
            errors.append(f"{module['id']} policy_cards must be a list")
            continue
        for policy_id in module.get("policy_cards", []):
            if not isinstance(policy_id, str):
                errors.append(f"{module['id']} policy card id must be a string")
                continue
            if policy_id not in policy_ids:
                errors.append(f"{module['id']} references missing policy card {policy_id}")
        for cost_key in module.get("cost_modifiers", {}).keys():
            if cost_key not in COST_KEYS:
                errors.append(f"{module['id']} has unknown cost modifier {cost_key}")

    for policy in policies:
        if "lag" in policy and (not isinstance(policy["lag"], int) or policy["lag"] < 0):
            errors.append(f"{policy['id']} lag must be a non-negative integer")
        for cost_key in policy.get("costs", {}).keys():
            if cost_key not in COST_KEYS:
                errors.append(f"{policy['id']} has unknown cost {cost_key}")
        validate_effect_keys(errors, policy["id"], policy.get("effects", {}), POLICY_EFFECT_SCOPES)
        for index, spillover in enumerate(policy.get("spillovers", [])):
            if not spillover.get("target_tag"):
                errors.append(f"{policy['id']} spillover[{index}] has no target_tag")
            validate_track_effects(
                errors,
                f"{policy['id']} spillover[{index}]",
                spillover.get("effects", {}),
                COUNTRY_EFFECT_KEYS,
            )
        mutations = policy.get("mutations", {})
        for card_id in mutations.get("add_to_deck", []):
            if card_id not in card_ids:
                errors.append(f"{policy['id']} adds missing card {card_id}")
        for card_id in mutations.get("remove_from_deck", []):
            if card_id not in card_ids:
                errors.append(f"{policy['id']} removes missing card {card_id}")
        world_card = mutations.get("add_world_card")
        if world_card and world_card not in card_ids:
            errors.append(f"{policy['id']} adds missing world card {world_card}")

    for country_id in scenario.get("countries", []):
        if country_id not in country_ids:
            errors.append(f"scenario references missing country {country_id}")

    for pressure in pressures:
        demand = pressure.get("demand", {})
        if not demand.get("preferred_policy_tags"):
            errors.append(f"{pressure['id']} has no preferred policy tags")
        validate_track_effects(errors, f"{pressure['id']} if_satisfied", demand.get("if_satisfied", {}), COUNTRY_EFFECT_KEYS)
        validate_track_effects(errors, f"{pressure['id']} if_ignored", demand.get("if_ignored", {}), COUNTRY_EFFECT_KEYS)

    for card in vulnerabilities:
        card_type = card.get("type", "")
        effects = card.get("effects", {})
        if card_type == "world_event":
            validate_event_effect_keys(errors, card["id"], effects, card_ids, policy_ids)
        else:
            validate_state_effect_keys(errors, card["id"], effects)
            if card_type == "vulnerability":
                validate_response(errors, card["id"], card.get("response", {}))

    for event in events:
        if not event.get("effects"):
            errors.append(f"{event['id']} has no effects")
        validate_event_effect_keys(errors, event["id"], event.get("effects", {}), card_ids, policy_ids)
        if "persistent_crisis" in event:
            validate_persistent_crisis(errors, event["id"], event.get("persistent_crisis", {}))

    if errors:
        print("Data validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(
        "Data validation passed: "
        f"{len(countries)} countries, {len(modules)} modules, "
        f"{len(policies)} policies, {len(vulnerabilities)} state cards, "
        f"{len(pressures)} pressures, {len(events)} events."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
