# Architecture Review

## Scope

This MVP keeps the game as a local tabletop-style Godot app. The architecture should protect the rules engine from UI churn, because the visual surface will keep changing while the macro model and card data mature.

## DDD Boundaries

- `src/core/` is the domain layer. `GameState` is the game aggregate root. `CountryState` and `WorldState` are entities inside that aggregate.
- `src/core/*resolver.gd` files are domain services. They resolve policy, public choice, world feedback, and scoring without knowing about controls or screen layout.
- `src/app/` is the application layer. It contains use-case helpers that coordinate domain state for a player action, such as policy recommendation.
- `src/data/` is the data access layer. JSON files are data sources; loaders translate them into dictionaries used by the domain.
- `src/ui/` is the presentation layer. It renders `GameState` and sends commands such as `select_policy`, `assign_worker`, and `advance_phase`.
- `src/ui/components/` contains stateful Godot UI components that own their own controls, signals, and refresh behavior.
- `src/ui/support/` contains UI-only support code: display labels, icon-token mapping, panel construction, and token texture caching.

## Folder Map

```text
src/
  app/                Use-case helpers between UI and domain
  core/               Domain aggregate, entities, resolvers, scoring, RNG
  data/               JSON loaders and indexing helpers
  ui/                 Godot Control scripts and screen composition
    components/       Stateful UI components such as mats, boards, header, log
    support/          UI catalogs, panel factory, visual asset helpers
tests/                Godot smoke tests for domain flow, app services, and UI layout
tools/                Local validation, Godot launch, screenshot, and balance scripts
data/                 Versioned game content JSON
assets/ui/            Generated visual assets used by the board UI
docs/                 Design, architecture, rules, UX, and balancing notes
```

## TDC / Command Flow

The UI should tell the domain what the player decided; it should not inspect and mutate internals directly. Preferred flow:

```text
Button press -> GameState command -> resolver/domain mutation -> UI refresh
```

Current high-value commands:

- `GameState.select_policy(country_index, policy_index)`
- `GameState.assign_worker(country_index, worker_id)`
- `GameState.advance_phase()`
- `GameState.resolve_turn()`
- `GameState.declare_agenda(country_index, agenda_tag)`
- `PolicyRecommender.recommend_for_country(game, country_index)`

Current UI component ownership:

- `PhaseHeader`: phase status and top-level action buttons
- `NegotiationTable`: diplomatic agenda and planned-policy tag pips
- `WorldBoard`: world event and global macro tracks
- `CountryMat`: one country's hand, pressure, selected policy, worker tokens, and national tracks
- `LegacyScorePanel`: score/ranking presentation
- `ResolutionLog`: rolling resolution log presentation

Current UI support ownership:

- `UiCatalog`: display names and token id mapping
- `TokenAssets`: token texture loading and cache
- `TrackPresenter`: track color and pip count presentation logic
- `CardTextFormatter`: hand labels, planned policy text, and card detail text
- `PanelFactory`: common panel/chrome construction

Future rule changes should add commands or resolver services before adding UI-side rule branches.

## DbC Contracts

`GameState` now checks core preconditions and invariants:

- country indexes must be valid before policy or worker commands run
- selected cards must be policy cards
- worker ids must be known worker tokens
- phase index must stay inside `PHASES`
- turn must stay inside the turn limit
- every country must keep required tracks for UI and scoring

These checks are intentionally light. They catch broken data and invalid UI calls early without replacing real tests.

## Maintenance Rules

- Add new cards through JSON first, then extend resolver behavior only when a tag or mutation needs new rules.
- Keep visual assets in `assets/ui/`; do not bake rules into asset names.
- When adding a screen, prefer a read-only view over direct state mutation.
- When a UI area owns controls and refresh behavior, move it into `src/ui/components/` instead of growing `main.gd`.
- When a helper is stateless or only maps names/assets/layout values, keep it in `src/ui/support/`.
- Add a smoke test when changing a phase transition, layout breakpoint, or aggregate invariant.

The day-to-day engineering rules live in `docs/engineering_playbook.md`.
