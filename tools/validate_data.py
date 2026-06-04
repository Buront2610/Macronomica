from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def ids(items, key="id"):
    return {item[key] for item in items}


def main() -> int:
    errors: list[str] = []
    countries = load_json(DATA / "countries" / "presets.json")
    modules = load_json(DATA / "modules" / "modules.json")
    policies = load_json(DATA / "cards" / "policies.json")
    pressures = load_json(DATA / "cards" / "domestic_pressures.json")
    vulnerabilities = load_json(DATA / "cards" / "vulnerabilities.json")
    events = load_json(DATA / "events" / "world_events.json")
    scenario = load_json(DATA / "scenarios" / "v0_1.json")

    country_ids = {country["country_id"] for country in countries}
    module_ids = ids(modules)
    policy_ids = ids(policies)
    card_ids = policy_ids | ids(vulnerabilities)

    for country in countries:
        for module_id in country.get("modules", []):
            if module_id not in module_ids:
                errors.append(f"{country['country_id']} references missing module {module_id}")

    for module in modules:
        for card_id in module.get("deck_cards", []):
            if card_id not in card_ids:
                errors.append(f"{module['id']} references missing deck card {card_id}")

    for policy in policies:
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

    for event in events:
        if not event.get("effects"):
            errors.append(f"{event['id']} has no effects")

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

