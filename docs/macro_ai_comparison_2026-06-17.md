# Macro AI Comparison 2026-06-17

`tools/compare_macro_ai.gd` による同一seed比較。
`macro` は状態・能力・世界危機・対応任務を読む `PolicyRecommender`、`naive` はカードの直接効果と表面コストだけを見る単純加算AI。

| Mode | Runs | Collapse | Avg score/country | Avg welfare/country | Policy success | Pressure satisfied |
|---|---:|---:|---:|---:|---:|---:|
| macro | 40 | 2.5% | 161.7 | 14.7 | 86.5% | 28.9% |
| naive | 40 | 80.0% | 32.5 | 13.4 | 37.6% | 5.4% |

## Interpretation

- Macro-aware selection outperforms direct card arithmetic by 129.2 points per country on average.
