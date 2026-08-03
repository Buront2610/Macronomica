# Playtest Report 2026-06-17

`tools/playtest_game_design.gd` による PolicyRecommender 自動プレイ 120 回の結果。
目的は、前セッションで未完了だった仕様破綻・ゲームデザイン品質確認を、再実行可能な形で固定すること。

## Summary

| Metric | Value |
|---|---:|
| Runs | 120 |
| Stuck games | 0 |
| Global collapse rate | 5.8% |
| Pressure satisfaction rate | 29.1% |
| Full policy success rate | 86.4% |
| Target policy target-selected rate | 100.0% |
| Missing policy menu observations | 0 |
| Avg mutation zone changes / policy | 1.83 |
| Max depression observed | 9 |
| Max financial instability observed | 10 |
| Max protectionism observed | 10 |

## Results By Country

| Country | Win rate | Avg score | Avg welfare |
|---|---:|---:|---:|
| emerging_foreign_debt_state | 20.0% | 159.0 | 15.1 |
| export_industrial_deflationary_state | 28.3% | 169.6 | 15.3 |
| reserve_currency_financial_power | 29.2% | 172.8 | 15.4 |
| resource_exporter_state | 16.7% | 163.6 | 15.7 |

## Policy / Worker Use

| Policy | Uses |
|---|---:|
| social_safety_net | 684 |
| anti_corruption_drive | 474 |
| swap_line | 398 |
| progressive_tax_reform | 343 |
| tariff_freeze_pact | 329 |
| rate_cut_and_qe | 325 |
| debt_restructuring | 289 |
| fiscal_stimulus | 273 |
| austerity | 259 |
| financial_regulation | 233 |
| stabilization_fund_drawdown | 212 |
| joint_fiscal_pact | 186 |

| Worker | Uses |
|---|---:|
| auditor | 3356 |
| bureaucrats | 3583 |
| central_bank_staff | 1476 |
| diplomat | 1586 |
| lobbyist | 3837 |

## Findings

- 自動プレイ上の停止・政策不在・対象未選択は検出されなかった。

## Sample Failure Logs

### Seed 2026061708: global collapse
- C国：資源国 でデフレスパイラルが進行しました。
- 金融危機が国境を越えて伝染しました。
- 世界恐慌トラックが 2 変化しました。
- 世界恐慌が各国の需要・雇用・金融安定を圧迫しました。
- C国：資源国 は選挙で政権交代し、改革疲れが残りました。
- A国：基軸通貨・金融大国 は厚生点 +0（累計 11）を得ました。
- B国：輸出工業・デフレ国 は厚生点 +0（累計 11）を得ました。
- C国：資源国 は厚生点 +0（累計 7）を得ました。
- D国：新興・外貨債務国 は厚生点 +1（累計 11）を得ました。
- 世界恐慌が臨界点に達しました。全員敗北です。

### Seed 2026061723: global collapse
- D国：新興・外貨債務国 でデフレスパイラルが進行しました。
- 金融危機が国境を越えて伝染しました。
- 世界恐慌トラックが 1 変化しました。
- 世界恐慌が各国の需要・雇用・金融安定を圧迫しました。
- D国：新興・外貨債務国 は選挙で政権交代し、改革疲れが残りました。
- A国：基軸通貨・金融大国 は厚生点 +0（累計 4）を得ました。
- B国：輸出工業・デフレ国 は厚生点 +1（累計 5）を得ました。
- C国：資源国 は厚生点 +0（累計 5）を得ました。
- D国：新興・外貨債務国 は厚生点 +0（累計 4）を得ました。
- 世界恐慌が臨界点に達しました。全員敗北です。

### Seed 2026061740: global collapse
- B国：輸出工業・デフレ国 でデフレスパイラルが進行しました。
- 金融危機が国境を越えて伝染しました。
- 世界恐慌トラックが 2 変化しました。
- 世界恐慌が各国の需要・雇用・金融安定を圧迫しました。
- A国：基軸通貨・金融大国 は選挙で政権交代し、改革疲れが残りました。
- A国：基軸通貨・金融大国 は厚生点 +0（累計 11）を得ました。
- B国：輸出工業・デフレ国 は厚生点 +0（累計 11）を得ました。
- C国：資源国 は厚生点 +1（累計 12）を得ました。
- D国：新興・外貨債務国 は厚生点 +1（累計 13）を得ました。
- 世界恐慌が臨界点に達しました。全員敗北です。

### Seed 2026061753: global collapse
- C国：資源国 でデフレスパイラルが進行しました。
- 金融危機が国境を越えて伝染しました。
- 世界恐慌トラックが 2 変化しました。
- 世界恐慌が各国の需要・雇用・金融安定を圧迫しました。
- D国：新興・外貨債務国 は選挙で政権交代し、改革疲れが残りました。
- A国：基軸通貨・金融大国 は厚生点 +0（累計 10）を得ました。
- B国：輸出工業・デフレ国 は厚生点 +0（累計 5）を得ました。
- C国：資源国 は厚生点 +0（累計 11）を得ました。
- D国：新興・外貨債務国 は厚生点 +1（累計 16）を得ました。
- 世界恐慌が臨界点に達しました。全員敗北です。

