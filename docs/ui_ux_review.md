# UI/UX Review

## MVP Goal

The first screen should feel like a board game table, not an economic spreadsheet. The player needs to see the current phase, the diplomatic mood, their immediate pressure, and the actions they can take.

## Applied Game Design Principles

- MDA: mechanics are policy cards, workers, and macro tracks; dynamics are negotiation, simultaneous reveal, and spillover; the target aesthetic is tense public-choice bargaining rather than spreadsheet optimization.
- Schell-style lenses: the first screen emphasizes action, goals, dynamic state, and expected value. The player should understand "what can I do now, what state is changing, and what tradeoff am I making?"
- Visibility of system status: the active phase is shown in the header and phase rail, so the player knows what kind of decision is expected.
- Meaningful choice above the fold: at 1280x720, the board shows the persistent policy menu, revealed domestic state cards, domestic pressure, policy slot, workers, and national tokens without horizontal clipping.
- Progressive disclosure: detailed world state and logs live in the right rail. The main policy table stays focused on the next player action.
- Feedback loop: selected policy and worker are represented as board pieces, then resolution produces log entries and track movement.
- Cognitive load budget: policy menu cards use short labels on the board. Longer card descriptions remain in tooltips, policy previews, and revealed slots.
- Touch target clarity: phase buttons, policy menu cards, and worker tokens have stable minimum sizes so resizing does not shift the layout unpredictably.

## Responsive Layout

- The project uses Godot `canvas_items` + `expand` at a 1920x1080 board coordinate space.
- UI therefore does not rely on unreachable compact/mid/wide branches. Readability is protected by larger board elements, label-fit audits, and generated 1280x720 preview frames.
- The current verification target is the clickable flow GIF rendered from the actual board state.

## Visual Direction

- Use generated board-game tokens for workers, national tracks, diplomacy, and world markers.
- Avoid spreadsheet-style economy panels as the primary screen.
- Keep numeric tracks as tokens and pips rather than dense tables.
- Keep the first action loop legible: pressure -> choose policy -> assign worker -> reveal -> resolve.

## Next UX Candidates

- Add a selected-card detail panel beside the policy menu for richer policy previews.
- Animate token movement during resolution.
- Add stronger color semantics for crisis, stability, and international spillover.
- Add local multiplayer prompts that name whose policy choice is expected.

## References

- Robin Hunicke, Marc LeBlanc, Robert Zubek, "MDA: A Formal Approach to Game Design and Game Research": https://www.cs.northwestern.edu/~hunicke/MDA.pdf
- Jesse Schell, "The Art of Game Design: A Book of Lenses": https://www.sciencedirect.com/book/9780123694966/the-art-of-game-design
- Nielsen Norman Group, "10 Usability Heuristics for User Interface Design": https://www.nngroup.com/articles/ten-usability-heuristics/
