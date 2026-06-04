# Board Surface Contract

The main game screen must behave like a tabletop board game, not a business dashboard.

This direction follows the UI review work done with Claude and GPT-5.5 Pro during the redesign: both reviews pointed to the same failure mode, namely large Control/Container panels sitting on top of a board image. The accepted direction is to treat the background as the board surface and represent player actions as physical board objects moving across it.

## Required Direction

- The background image is the play surface.
- Main-screen player actions are cards, tokens, seats, markers, and trails on that surface.
- Four countries appear as compact seats on one board, with no scroll-based country mats.
- Policies are chosen from a hand fan and move to a physical policy slot.
- Workers are table tokens and move to country seats.
- Phase changes move a marker along board pips.
- Temporary visual aids such as `BoardTrail` are allowed because they appear only during board actions.

## Forbidden On The Main Screen

- `PanelContainer`
- `HBoxContainer`
- `VBoxContainer`
- `ScrollContainer`
- `TabContainer`
- `Button`
- `StyleBoxFlat`
- `draw_rect`

Those nodes may still exist in legacy component tests or internal tools, but they must not be part of the main game board surface.

## Current Enforcement

- `tests/smoke_board_surface_contract.gd` prevents banned source tokens from returning to `src/ui/main.gd`.
- `tests/smoke_board_runtime_contract.gd` instantiates the main board and checks that banned runtime node classes are absent.
- `tests/smoke_board_interaction.gd` verifies that policy placement, worker assignment, country selection, and phase advancement create moving ghosts and board trails.
- `tools/render_board_action_preview.ps1` renders a PNG of a policy card moving over the board surface.

The goal of these checks is not to freeze the visual style forever. It is to prevent the project from drifting back into a data app layout while the board art and token art continue improving.

## GPT-5.5 Pro Review Mapping

The browser review emphasized these points:

- World indicators should be tracks, dials, markers, or tokens rather than data lists.
- Four countries should be compact seats, not scrollable country mats.
- Buttons should become cards, action slots, seals, or table tokens.
- Policy cards should fan out from the active country and move to a physical slot.
- Workers should move as pieces on the board.
- Phase changes should move a visible marker.
- Motion should be short and meaningful; constant animation, long zooms, full-screen flashes, and moving click targets are uncomfortable.
- Tiny token art should preserve aspect ratio and have enough inner padding.
- A future accessibility pass should add reduced-motion or instant-resolution options.

Current implementation status:

- Implemented: compact four-country seats, board-card hand, physical policy slot, worker tokens, phase pips, action tokens, board trails, hover/press feedback, and generated action-preview PNGs.
- Enforced: banned dashboard-style nodes are checked at source and runtime.
- Deferred: a full Node2D scene split, richer board art with printed slots, keyboard/controller focus traversal, and a user-facing reduced-motion setting.
