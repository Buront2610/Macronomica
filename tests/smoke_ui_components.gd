extends SceneTree

const GameStateScript := preload("res://src/core/game_state.gd")
const TokenAssetsScript := preload("res://src/ui/support/token_assets.gd")
const PhaseHeaderScript := preload("res://src/ui/components/phase_header.gd")
const NegotiationTableScript := preload("res://src/ui/components/negotiation_table.gd")
const WorldBoardScript := preload("res://src/ui/components/world_board.gd")
const CountryMatScript := preload("res://src/ui/components/country_mat.gd")
const LegacyScorePanelScript := preload("res://src/ui/components/legacy_score_panel.gd")
const ResolutionLogScript := preload("res://src/ui/components/resolution_log.gd")

const COLORS := {
	"panel": Color(0.08, 0.09, 0.10, 0.88),
	"mat": Color(0.12, 0.13, 0.13, 0.92),
	"card": Color(0.86, 0.82, 0.72, 0.96),
	"card_dark": Color(0.16, 0.18, 0.19, 0.98),
	"line": Color(0.26, 0.25, 0.22),
	"text": Color(0.92, 0.90, 0.84),
	"ink": Color(0.12, 0.12, 0.10),
	"muted": Color(0.63, 0.65, 0.62),
	"good": Color(0.28, 0.68, 0.45),
	"warn": Color(0.86, 0.61, 0.20),
	"bad": Color(0.78, 0.25, 0.22),
	"blue": Color(0.30, 0.55, 0.78),
	"token_empty": Color(0.19, 0.18, 0.15, 0.90),
	"token_edge": Color(0.44, 0.35, 0.23, 0.95),
	"accents": [
		Color(0.42, 0.66, 0.88),
		Color(0.32, 0.70, 0.58),
		Color(0.86, 0.62, 0.28),
		Color(0.76, 0.42, 0.38)
	]
}

func _init() -> void:
	var game = GameStateScript.new()
	game.new_game()
	var token_assets = TokenAssetsScript.new()

	var header = PhaseHeaderScript.new()
	get_root().add_child(header)
	header.setup("compact", COLORS)
	header.refresh(game, GameStateScript.PHASES, 72)
	_assert(header.get_child_count() > 0, "phase header builds controls")

	var negotiation = NegotiationTableScript.new()
	get_root().add_child(negotiation)
	negotiation.setup("compact", COLORS)
	negotiation.refresh(game.countries)
	_assert(negotiation.get_child_count() > 0, "negotiation table builds agenda")

	var world_board = WorldBoardScript.new()
	get_root().add_child(world_board)
	world_board.setup(token_assets, COLORS)
	world_board.refresh(game.world)
	_assert(world_board.get_child_count() > 0, "world board builds event and tracks")

	var country_mat = CountryMatScript.new()
	get_root().add_child(country_mat)
	country_mat.setup(0, "compact", Vector2(340, 330), token_assets, COLORS, COLORS["accents"][0])
	country_mat.refresh(game.countries[0], 0, game.current_phase(), game.revealed_policies, game.is_finished)
	_assert(country_mat.get_child_count() > 0, "country mat builds controls")

	var score_panel = LegacyScorePanelScript.new()
	get_root().add_child(score_panel)
	score_panel.setup()
	score_panel.refresh(game.get_scores())
	_assert(not score_panel.text.is_empty(), "legacy score panel renders scores")

	var resolution_log = ResolutionLogScript.new()
	get_root().add_child(resolution_log)
	resolution_log.setup()
	resolution_log.refresh(game.log)
	_assert(not resolution_log.text.is_empty(), "resolution log renders log entries")

	print("Smoke UI components passed.")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
