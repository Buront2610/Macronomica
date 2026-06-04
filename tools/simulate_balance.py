from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"


def load(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def clamp(value: int, low: int = -5, high: int = 10) -> int:
    return max(low, min(high, value))


def bounds_for(key: str) -> tuple[int, int]:
    non_negative = {
        "trade_openness",
        "international_financial_instability",
        "depression",
        "protectionism",
        "global_coordination",
        "unemployment",
        "debt",
        "financial_stress",
        "political_capital",
    }
    if key in non_negative:
        return 0, 10
    if key in {"world_demand", "world_interest_rate"}:
        return -5, 5
    return -5, 10


def apply(tracks: dict[str, int], effects: dict[str, int]) -> None:
    for key, value in effects.items():
        low, high = bounds_for(key)
        tracks[key] = clamp(int(tracks.get(key, 0)) + int(value), low, high)


def main() -> int:
    countries = load(DATA / "countries" / "presets.json")
    policies = load(DATA / "cards" / "policies.json")
    scenario = load(DATA / "scenarios" / "v0_1.json")
    world = dict(scenario["starting_world"])

    # Deterministic smoke simulation: every country repeatedly plays the next common policy.
    states = {country["country_id"]: dict(country["starting_tracks"]) for country in countries}
    for turn in range(1, scenario["turn_limit"] + 1):
        for index, country in enumerate(countries):
            policy = policies[(turn + index) % len(policies)]
            apply(states[country["country_id"]], policy.get("effects", {}).get("country", {}))
            apply(world, policy.get("effects", {}).get("world", {}))

    print("Smoke balance simulation complete.")
    print("World:", world)
    for country in countries:
        print(country["display_name"], states[country["country_id"]])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
