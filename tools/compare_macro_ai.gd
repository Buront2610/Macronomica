extends SceneTree

const GameStateScript := preload("res://src/core/game_state.gd")
const PolicyRecommenderScript := preload("res://src/app/policy_recommender.gd")

const RUNS := 40
const BASE_SEED := 2026061801
const OUTPUT_PATH := "res://docs/macro_ai_comparison_2026-06-17.md"

var summaries := {
	"macro": _blank_summary(),
	"naive": _blank_summary()
}

func _init() -> void:
	for run_index in range(RUNS):
		_run_game("macro", BASE_SEED + run_index)
		_run_game("naive", BASE_SEED + run_index)
	_write_report()
	print("Macro AI comparison written: %s" % OUTPUT_PATH)
	quit(0)

func _blank_summary() -> Dictionary:
	return {
		"collapse": 0,
		"score_total": 0,
		"welfare_total": 0,
		"policy_success": 0,
		"policy_total": 0,
		"pressure_satisfied": 0,
		"pressure_total": 0,
		"wins": {}
	}

func _run_game(mode: String, seed: int) -> void:
	var game = GameStateScript.new()
	game.new_game(seed)
	var guard := 0
	while not game.is_finished and guard < 240:
		guard += 1
		var phase := game.current_phase()
		if phase == "negotiation":
			_declare_agendas(game, mode)
			game.advance_phase()
		elif phase == "policy_planning":
			_select_policies(game, mode)
			game.advance_phase()
		elif phase == "worker_assignment":
			_assign_workers(game, mode)
			game.advance_phase()
		elif phase == "simultaneous_reveal":
			_sample_preview(game, mode)
			game.advance_phase()
		else:
			game.advance_phase()
	_collect_scores(game, mode)

func _declare_agendas(game, mode: String) -> void:
	for i in range(game.countries.size()):
		var recommendation := _recommend(game, i, mode)
		if recommendation.is_empty():
			continue
		var policy_index := int(recommendation.get("policy_index", -1))
		var options: Array = game.policy_options(i)
		if policy_index < 0 or policy_index >= options.size():
			continue
		var card: Dictionary = options[policy_index]
		if card.get("tags", []).has("cooperation"):
			game.declare_agenda(i, "cooperation")
			game.request_support(i, "cooperation")

func _select_policies(game, mode: String) -> void:
	for i in range(game.countries.size()):
		var recommendation := _recommend(game, i, mode)
		if recommendation.is_empty():
			continue
		var policy_index := int(recommendation.get("policy_index", -1))
		game.select_policy(i, policy_index)
		var card: Dictionary = game.policy_options(i)[policy_index]
		if String(card.get("target", "")) == "country":
			var target_index := _target_for_naive(game, i)
			game.select_policy_target(i, target_index)

func _assign_workers(game, mode: String) -> void:
	for i in range(game.countries.size()):
		var recommendation := _recommend(game, i, mode)
		if recommendation.is_empty():
			continue
		if mode == "macro":
			game.assign_workers(i, recommendation.get("workers", [String(recommendation["worker"])]))
		else:
			game.assign_worker(i, String(recommendation.get("worker", "bureaucrats")))

func _recommend(game, country_index: int, mode: String) -> Dictionary:
	if mode == "macro":
		return PolicyRecommenderScript.recommend_for_country(game, country_index)
	return _naive_recommend_for_country(game, country_index)

func _naive_recommend_for_country(game, country_index: int) -> Dictionary:
	var country = game.countries[country_index]
	var options: Array = game.policy_options(country_index)
	var best_index := -1
	var best_score := -999999
	for i in range(options.size()):
		var card: Dictionary = options[i]
		if not country.is_policy_available(card):
			continue
		var score := _naive_policy_score(card)
		if score > best_score:
			best_score = score
			best_index = i
	if best_index < 0:
		return {}
	var worker := _naive_worker_for(options[best_index])
	return {"policy_index": best_index, "worker": worker, "workers": [worker], "score": best_score}

func _naive_policy_score(card: Dictionary) -> int:
	var effects: Dictionary = card.get("effects", {})
	var country_effects: Dictionary = effects.get("country", effects.get("donor", {}))
	var world_effects: Dictionary = effects.get("world", {})
	var score := 0
	score += int(country_effects.get("gdp_gap", 0)) * 8
	score -= int(country_effects.get("unemployment", 0)) * 6
	score -= int(country_effects.get("financial_stress", 0)) * 5
	score -= int(country_effects.get("debt", 0)) * 2
	score += int(world_effects.get("world_demand", 0)) * 3
	score += int(world_effects.get("global_coordination", 0)) * 2
	score -= int(world_effects.get("depression", 0)) * 3
	score -= int(world_effects.get("protectionism", 0)) * 2
	score -= _cost_total(card.get("costs", {}))
	return score

func _naive_worker_for(card: Dictionary) -> String:
	var costs: Dictionary = card.get("costs", {})
	var best_key := ""
	var best_cost := -1
	for key in costs.keys():
		if int(costs[key]) > best_cost:
			best_cost = int(costs[key])
			best_key = String(key)
	if best_key == "credibility":
		return "central_bank_staff"
	if best_key == "international":
		return "diplomat"
	if best_key == "political":
		return "lobbyist"
	return "bureaucrats"

func _cost_total(costs: Dictionary) -> int:
	var total := 0
	for key in costs.keys():
		total += int(costs[key])
	return total

func _target_for_naive(game, source_index: int) -> int:
	for offset in range(1, game.countries.size()):
		var index: int = (source_index + offset) % game.countries.size()
		if index != source_index:
			return index
	return -1

func _sample_preview(game, mode: String) -> void:
	var summary: Dictionary = summaries[mode]
	var outcome: Dictionary = game.preview_resolution_outcome()
	for item in outcome.get("items", []):
		summary["policy_total"] = int(summary["policy_total"]) + 1
		if bool(item.get("policy_success", false)):
			summary["policy_success"] = int(summary["policy_success"]) + 1
		summary["pressure_total"] = int(summary["pressure_total"]) + 1
		if bool(item.get("pressure_satisfied", false)):
			summary["pressure_satisfied"] = int(summary["pressure_satisfied"]) + 1

func _collect_scores(game, mode: String) -> void:
	var summary: Dictionary = summaries[mode]
	var scores: Array = game.get_scores()
	if not scores.is_empty() and bool(scores[0].get("global_collapse", false)):
		summary["collapse"] = int(summary["collapse"]) + 1
	elif not scores.is_empty():
		var winner := String(scores[0].get("country_id", ""))
		var wins: Dictionary = summary["wins"]
		wins[winner] = int(wins.get(winner, 0)) + 1
	for score in scores:
		summary["score_total"] = int(summary["score_total"]) + int(score.get("score", 0))
		summary["welfare_total"] = int(summary["welfare_total"]) + int(score.get("welfare_score", 0))

func _write_report() -> void:
	var lines := []
	lines.append("# Macro AI Comparison 2026-06-17")
	lines.append("")
	lines.append("`tools/compare_macro_ai.gd` による同一seed比較。")
	lines.append("`macro` は状態・能力・世界危機・対応任務を読む `PolicyRecommender`、`naive` はカードの直接効果と表面コストだけを見る単純加算AI。")
	lines.append("")
	lines.append("| Mode | Runs | Collapse | Avg score/country | Avg welfare/country | Policy success | Pressure satisfied |")
	lines.append("|---|---:|---:|---:|---:|---:|---:|")
	for mode in ["macro", "naive"]:
		var summary: Dictionary = summaries[mode]
		lines.append("| %s | %d | %.1f%% | %.1f | %.1f | %.1f%% | %.1f%% |" % [
			mode,
			RUNS,
			_percent(int(summary["collapse"]), RUNS),
			float(summary["score_total"]) / float(RUNS * 4),
			float(summary["welfare_total"]) / float(RUNS * 4),
			_percent(int(summary["policy_success"]), int(summary["policy_total"])),
			_percent(int(summary["pressure_satisfied"]), int(summary["pressure_total"]))
		])
	lines.append("")
	lines.append("## Interpretation")
	lines.append("")
	var macro_score := float(summaries["macro"]["score_total"]) / float(RUNS * 4)
	var naive_score := float(summaries["naive"]["score_total"]) / float(RUNS * 4)
	if macro_score > naive_score:
		lines.append("- Macro-aware selection outperforms direct card arithmetic by %.1f points per country on average." % (macro_score - naive_score))
	else:
		lines.append("- Direct card arithmetic currently matches or beats macro-aware selection by %.1f points per country. This would mean the learning-game success condition is not yet proven." % (naive_score - macro_score))
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s" % OUTPUT_PATH)
		quit(1)
		return
	file.store_string("\n".join(lines) + "\n")

func _percent(numerator: int, denominator: int) -> float:
	if denominator <= 0:
		return 0.0
	return float(numerator) * 100.0 / float(denominator)
