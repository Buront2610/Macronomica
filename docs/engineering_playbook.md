# Engineering Playbook

## Purpose

This project should grow as a playable strategy board game, not as a single UI script with rules hidden in callbacks. The baseline architecture is:

- Domain rules live in `src/core/`.
- Player-facing use cases live in `src/app/`.
- Stateful UI widgets live in `src/ui/components/`.
- Stateless UI helpers live in `src/ui/support/`.
- Data-driven content lives in `data/`.

The current component baseline is `PhaseHeader`, `NegotiationTable`, `WorldBoard`, `CountryMat`, `LegacyScorePanel`, and `ResolutionLog` for legacy/component smoke coverage. The playable main board is intentionally different: `main.gd` owns the tabletop surface and uses board objects instead of dashboard containers. See `docs/board_surface_contract.md`.

## TDD Baseline

Before changing behavior, add or update the smallest smoke or unit-style script that proves the expected behavior.

- Phase flow and aggregate invariants: `tests/smoke_game_flow.gd`
- Domain rules, v0.2 macro/politics hooks, and scoring invariants: `tests/smoke_domain_rules.gd`
- Policy recommendation use case: `tests/smoke_policy_recommender.gd`
- Project UI settings and bundled font: `tests/smoke_project_settings.gd`
- UI component construction and refresh: `tests/smoke_ui_components.gd`

New rules should get domain tests first. New UI components should at least get a construction/refresh smoke test before they are wired into `main.gd`.

## DbC Baseline

`GameState` is the aggregate root and owns the most important contracts:

- valid country index before player commands
- valid policy card before selection
- known worker id before assignment
- valid phase index and turn range
- required country tracks present after setup and turn transitions
- v0.2 tracks `expected_inflation` and `influence` present on every country

UI components should not duplicate these domain contracts. They may guard display assumptions, but command validity belongs to the aggregate.

## DDD Boundaries

Treat `GameState` as the only mutable game aggregate exposed to the UI. UI components emit intent signals such as:

- `policy_selected(country_index, policy_index)`
- `worker_assigned(country_index, worker_id)`
- `advance_requested`

`main.gd` translates those signals into aggregate commands. Components render state; they do not resolve rules.

## Game Design Loop

Keep the MVP focused on this loop:

```text
pressure is revealed -> player chooses policy -> player assigns worker -> policies reveal -> macro/world feedback changes tracks
```

Every new screen or component should make one part of that loop clearer. If it adds information but weakens the player's ability to decide, it belongs behind a tab, tooltip, or log.

## Game Programming Rules

- Prefer deterministic state changes and seeded RNG.
- Keep frame/UI refresh separate from rule resolution.
- Let components own Control nodes and signals.
- Let domain services own rule calculations.
- Avoid direct mutation from UI widgets; emit intent and let `main.gd` call `GameState`.
- Keep generated assets separate from rules. Asset filenames may map to display tokens, but rules should depend on card tags and ids.
- Re-run `tools/monte_carlo_balance.gd` after changing macro feedback, scoring, deck composition, or recommendation heuristics, and commit the refreshed `docs/balancing_notes.md` when balance changes intentionally.

## Component Checklist

When adding a component:

1. Put it under `src/ui/components/`.
2. Give it `setup(...)` for dependencies and `refresh(...)` for state.
3. Emit signals for player intent.
4. Do not preload `GameState` unless the component is a top-level screen.
5. Add or update `tests/smoke_ui_components.gd`.
6. Verify `tools/check_godot.ps1` and an actual screenshot for layout-sensitive changes.
