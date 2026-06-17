extends SceneTree

const GameStateScript := preload("res://src/core/game_state.gd")
const PolicyRecommenderScript := preload("res://src/app/policy_recommender.gd")

const RUNS := 120
const BASE_SEED := 2026061701
const OUTPUT_PATH := "res://docs/playtest_report_2026-06-17.md"

var wins := {}
var score_totals := {}
var welfare_totals := {}
var final_world_totals := {}
var policy_counts := {}
var worker_counts := {}
var pressure_satisfied := 0
var pressure_total := 0
var full_policy_success := 0
var policy_total := 0
var mutation_total := 0
var collapse_count := 0
var stuck_count := 0
var no_policy_turns := 0
var selected_target_policies := 0
var target_policy_total := 0
var max_depression := 0
var max_instability := 0
var max_protectionism := 0
var sample_logs := []
var findings := []

func _init() -> void:
	for run_index in range(RUNS):
		_run_playtest(BASE_SEED + run_index)
	_write_report()
	print("Playtest report written: %s" % OUTPUT_PATH)
	quit(0)

func _run_playtest(seed: int) -> void:
	var game = GameStateScript.new()
	game.new_game(seed)
	var guard := 0
	while not game.is_finished and guard < 240:
		guard += 1
		_sample_world_extremes(game)
		var phase := game.current_phase()
		if phase == "negotiation":
			_declare_recommended_cooperation(game)
			game.advance_phase()
		elif phase == "policy_planning":
			_select_recommended_policies(game)
			game.advance_phase()
		elif phase == "worker_assignment":
			_assign_recommended_workers(game)
			game.advance_phase()
		elif phase == "simultaneous_reveal":
			_sample_resolution_preview(game)
			game.advance_phase()
		else:
			game.advance_phase()
	if guard >= 240:
		stuck_count += 1
		_add_sample_log(seed, "stuck", game.log)
	var scores: Array = game.get_scores()
	if not scores.is_empty() and bool(scores[0].get("global_collapse", false)):
		collapse_count += 1
		_add_sample_log(seed, "global collapse", game.log)
	elif not scores.is_empty():
		var winner := String(scores[0].get("country_id", ""))
		wins[winner] = int(wins.get(winner, 0)) + 1
	for score in scores:
		var country_id := String(score.get("country_id", ""))
		score_totals[country_id] = int(score_totals.get(country_id, 0)) + int(score.get("score", 0))
		welfare_totals[country_id] = int(welfare_totals.get(country_id, 0)) + int(score.get("welfare_score", 0))
	for key in game.world.tracks.keys():
		final_world_totals[key] = int(final_world_totals.get(key, 0)) + int(game.world.tracks[key])

func _select_recommended_policies(game) -> void:
	for i in range(game.countries.size()):
		var recommendation := PolicyRecommenderScript.recommend_for_country(game, i)
		if recommendation.is_empty() or game.countries[i].policy_menu.is_empty():
			no_policy_turns += 1
			continue
		var policy_index := int(recommendation.get("policy_index", -1))
		if policy_index < 0 or policy_index >= game.countries[i].policy_menu.size():
			continue
		var card: Dictionary = game.countries[i].policy_menu[policy_index]
		var card_id := String(card.get("id", ""))
		policy_counts[card_id] = int(policy_counts.get(card_id, 0)) + 1
		game.select_policy(i, policy_index)
		if String(card.get("target", "")) == "country":
			target_policy_total += 1
			var target_index := _best_target_for(game, i, card)
			if target_index >= 0:
				game.select_policy_target(i, target_index)
				selected_target_policies += 1

func _best_target_for(game, source_index: int, policy: Dictionary) -> int:
	var best_index := -1
	var best_score := -9999
	for i in range(game.countries.size()):
		if i == source_index:
			continue
		var country = game.countries[i]
		var score := 0
		if String(policy.get("id", "")) == "swap_line":
			score += int(country.tracks.get("financial_stress", 0)) * 3
			score -= int(country.tracks.get("exchange_rate", 0))
		elif String(policy.get("id", "")) == "debt_restructuring":
			score += int(country.tracks.get("debt", 0)) * 2
			score += int(country.tracks.get("financial_stress", 0))
		else:
			score += int(country.tracks.get("financial_stress", 0))
		if score > best_score:
			best_score = score
			best_index = i
	return best_index

func _assign_recommended_workers(game) -> void:
	for i in range(game.countries.size()):
		var recommendation := PolicyRecommenderScript.recommend_for_country(game, i)
		if recommendation.is_empty():
			continue
		var workers: Array = recommendation.get("workers", [String(recommendation["worker"])])
		game.assign_workers(i, workers)
		for worker in workers:
			var worker_id := String(worker)
			worker_counts[worker_id] = int(worker_counts.get(worker_id, 0)) + 1

func _declare_recommended_cooperation(game) -> void:
	for i in range(game.countries.size()):
		var recommendation := PolicyRecommenderScript.recommend_for_country(game, i)
		if recommendation.is_empty():
			continue
		var policy_index := int(recommendation.get("policy_index", -1))
		if policy_index < 0 or policy_index >= game.countries[i].policy_menu.size():
			continue
		var card: Dictionary = game.countries[i].policy_menu[policy_index]
		if card.get("tags", []).has("cooperation"):
			game.declare_agenda(i, "cooperation")
			game.request_support(i, "cooperation")

func _sample_resolution_preview(game) -> void:
	var outcome: Dictionary = game.preview_resolution_outcome()
	for item in outcome.get("items", []):
		pressure_total += 1
		if bool(item.get("pressure_satisfied", false)):
			pressure_satisfied += 1
		policy_total += 1
		if bool(item.get("policy_success", false)):
			full_policy_success += 1
		mutation_total += int(item.get("mutation_count", 0))

func _sample_world_extremes(game) -> void:
	max_depression = maxi(max_depression, int(game.world.tracks.get("depression", 0)))
	max_instability = maxi(max_instability, int(game.world.tracks.get("international_financial_instability", 0)))
	max_protectionism = maxi(max_protectionism, int(game.world.tracks.get("protectionism", 0)))

func _add_sample_log(seed: int, label: String, log: Array) -> void:
	if sample_logs.size() >= 4:
		return
	var tail := []
	for i in range(maxi(0, log.size() - 10), log.size()):
		tail.append(String(log[i]))
	sample_logs.append({"seed": seed, "label": label, "tail": tail})

func _write_report() -> void:
	_build_findings()
	var lines := []
	lines.append("# Playtest Report 2026-06-17")
	lines.append("")
	lines.append("`tools/playtest_game_design.gd` による PolicyRecommender 自動プレイ %d 回の結果。" % RUNS)
	lines.append("目的は、前セッションで未完了だった仕様破綻・ゲームデザイン品質確認を、再実行可能な形で固定すること。")
	lines.append("")
	lines.append("## Summary")
	lines.append("")
	lines.append("| Metric | Value |")
	lines.append("|---|---:|")
	lines.append("| Runs | %d |" % RUNS)
	lines.append("| Stuck games | %d |" % stuck_count)
	lines.append("| Global collapse rate | %.1f%% |" % _percent(collapse_count, RUNS))
	lines.append("| Pressure satisfaction rate | %.1f%% |" % _percent(pressure_satisfied, pressure_total))
	lines.append("| Full policy success rate | %.1f%% |" % _percent(full_policy_success, policy_total))
	lines.append("| Target policy target-selected rate | %.1f%% |" % _percent(selected_target_policies, target_policy_total))
	lines.append("| Missing policy menu observations | %d |" % no_policy_turns)
	lines.append("| Avg mutation zone changes / policy | %.2f |" % (float(mutation_total) / float(maxi(1, policy_total))))
	lines.append("| Max depression observed | %d |" % max_depression)
	lines.append("| Max financial instability observed | %d |" % max_instability)
	lines.append("| Max protectionism observed | %d |" % max_protectionism)
	lines.append("")
	lines.append("## Results By Country")
	lines.append("")
	lines.append("| Country | Win rate | Avg score | Avg welfare |")
	lines.append("|---|---:|---:|---:|")
	for country_id in _sorted_keys(score_totals):
		lines.append("| %s | %.1f%% | %.1f | %.1f |" % [
			country_id,
			_percent(int(wins.get(country_id, 0)), RUNS),
			float(score_totals[country_id]) / float(RUNS),
			float(welfare_totals.get(country_id, 0)) / float(RUNS)
		])
	lines.append("")
	lines.append("## Policy / Worker Use")
	lines.append("")
	lines.append("| Policy | Uses |")
	lines.append("|---|---:|")
	for policy_id in _top_keys(policy_counts, 12):
		lines.append("| %s | %d |" % [policy_id, int(policy_counts[policy_id])])
	lines.append("")
	lines.append("| Worker | Uses |")
	lines.append("|---|---:|")
	for worker_id in _sorted_keys(worker_counts):
		lines.append("| %s | %d |" % [worker_id, int(worker_counts[worker_id])])
	lines.append("")
	lines.append("## Findings")
	lines.append("")
	for finding in findings:
		lines.append("- %s" % finding)
	if findings.is_empty():
		lines.append("- 自動プレイ上の停止・政策不在・対象未選択は検出されなかった。")
	lines.append("")
	lines.append("## Sample Failure Logs")
	lines.append("")
	if sample_logs.is_empty():
		lines.append("Global collapse / stuck のサンプルログなし。")
	else:
		for entry in sample_logs:
			lines.append("### Seed %d: %s" % [int(entry["seed"]), String(entry["label"])])
			for line in entry["tail"]:
				lines.append("- %s" % String(line))
			lines.append("")
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s" % OUTPUT_PATH)
		quit(1)
		return
	file.store_string("\n".join(lines) + "\n")

func _build_findings() -> void:
	if stuck_count > 0:
		findings.append("High: 自動プレイが停止したゲームがある。フェーズ遷移か政策選択に詰み条件が残っている。")
	if no_policy_turns > 0:
		findings.append("High: 政策メニューが空の観測が %d 回ある。政策デッキ廃止後の前提が壊れている。" % no_policy_turns)
	if target_policy_total > 0 and selected_target_policies < target_policy_total:
		findings.append("High: 対象国指定政策の target 選択が漏れるケースがある。交渉フェーズの核が失われる。")
	var collapse_rate := _percent(collapse_count, RUNS)
	if collapse_rate >= 25.0:
		findings.append("Medium: 全員敗北率 %.1f%% は高め。危機制御より事故死が強く感じられる可能性がある。" % collapse_rate)
	elif collapse_rate <= 3.0:
		findings.append("Medium: 全員敗北率 %.1f%% は低め。世界恐慌トラックが脅威として弱い可能性がある。" % collapse_rate)
	var pressure_rate := _percent(pressure_satisfied, pressure_total)
	if pressure_rate <= 25.0:
		findings.append("Medium: 国内圧力満足率 %.1f%% は低い。プレイヤーが要求に応える感覚より反発処理が支配的になりやすい。" % pressure_rate)
	if pressure_rate >= 75.0:
		findings.append("Medium: 国内圧力満足率 %.1f%% は高い。公共選択の苦しさが薄い可能性がある。" % pressure_rate)
	var success_rate := _percent(full_policy_success, policy_total)
	if success_rate <= 55.0:
		findings.append("Medium: 政策完全成立率 %.1f%% は低い。ワーカー配置の意味より不足ペナルティが強くなりやすい。" % success_rate)
	if int(worker_counts.get("auditor", 0)) == 0:
		findings.append("Medium: 監査官が自動プレイで一度も選ばれていない。汚職/利権除去のワーカー意思決定が死にやすい。")
	if _score_spread() < 8.0:
		findings.append("Low: 平均スコア差が小さい。国家ごとの得意不得意が順位に出にくい可能性がある。")

func _score_spread() -> float:
	if score_totals.is_empty():
		return 0.0
	var min_score := 999999.0
	var max_score := -999999.0
	for country_id in score_totals.keys():
		var average := float(score_totals[country_id]) / float(RUNS)
		min_score = minf(min_score, average)
		max_score = maxf(max_score, average)
	return max_score - min_score

func _percent(numerator: int, denominator: int) -> float:
	if denominator <= 0:
		return 0.0
	return float(numerator) * 100.0 / float(denominator)

func _sorted_keys(dict: Dictionary) -> Array:
	var keys := dict.keys()
	keys.sort()
	return keys

func _top_keys(dict: Dictionary, limit: int) -> Array:
	var keys := dict.keys()
	keys.sort_custom(func(a, b) -> bool: return int(dict[a]) > int(dict[b]))
	return keys.slice(0, mini(limit, keys.size()))
