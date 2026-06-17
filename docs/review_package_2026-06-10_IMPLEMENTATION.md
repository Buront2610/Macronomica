# レビュー・設計パッケージ取り込み後の実装状況

`macronomica_review_2026-06-10.zip` は `docs/` に取り込み済み。

| zip内ファイル | 取り込み先 |
|---|---|
| `design_v0_1_full.md` | `docs/design_v0_1_full.md` |
| `design_v0_2.md` | `docs/design_v0_2.md` |
| `review_2026-06_full_review.md` | `docs/review_2026-06_full_review.md` |
| `README.md` | `docs/review_package_2026-06-10_README.md` |

v0.2 正本の PR1〜PR7 について、現在の作業ツリーでは以下を実装済み。

- PR1: Godot CI、データ検証強化、RNG修正、重複ID修正、ガード追加、日本語フォント同梱、情報リーク抑制
- PR2: 30枚国家デッキ、毎ターン5枚ドロー・全手札捨て、10ターンループ、デッキ変質の山札トップ追加、状態カード `response` フィールド
- PR3: 期待インフレ、流動性の罠、貿易チャネル、資本移動、金融伝染、持続危機のマクロフィードバック
- PR4: 全員敗北、毎ターン厚生点、国際影響力、持続危機カウンター/解除条件、非対称デッキ汚染、レガシー再調整
- PR5: 共同宣言、選挙タイマー、対象国つき双方向政策、複数ワーカー配置、監査任務/対応任務、成立/骨抜き/補助金混入/実施ラグの成立判定
- PR6: 因果ログ、デフレスパイラル予兆、崩壊警戒バナー、次札予告、実施ラグ表示、厚生チェック、政策コストソケット、ターン新聞、終了画面の厚生・影響力・GDP推移表示
- PR7: `tools/monte_carlo_balance.gd` による80回実測と `docs/balancing_notes.md` 更新

追加UI検収:

- 国家席に `NextDeckLabel` / `PipelineLabel` / `ElectionLabel` / `WelfareLabel` を追加。
- 中央政策卓に6種の政策コストソケットを追加し、不足コストを赤系で警告。
- スワップラインと債務再編を対象国指定カードへ変更し、供与側/受入側/世界効果を分離。政策提出後は国家席クリックで対象国を指名し、対象席ハイライトと政策スロットの供与/受入プレビューで確認できる。
- ワーカー配置を1国1体から複数選択へ拡張。官僚団/中銀スタッフ/外交官/ロビイストは該当コストを同時に補助し、監査官は汚染カード除去任務を実行する。配置フェーズでは複数トークンを選んでから進行トークンで国を確定する。
- 政策タグが状態カードの `response.removed_by_tags` に合致し、`response.extra_costs` を支払える場合、対応任務として手札の状態カードを1枚除去する。
- 世界イベントに `persistent_crisis` を追加し、国際信用収縮・保護主義ムードは解除条件を満たすまで継続効果を出す。世界危機ボード下部に残ターンと解除条件を常時表示する。
- 世界恐慌トラックが8以上のとき、卓上上部に崩壊警戒バナーを表示。
- ターン新聞に厚生チェックの要約を表示し、スクリーンショットQAで本文が枠外へはみ出さないことを確認。
- 世界経済新聞をクリックすると、最新ニュースに関係する世界トラックを推定してカード枠をハイライトする。
- `GameState.move_to_phase()` / `reveal_policies()` / `set_policies_revealed()` を追加し、UI側から `phase_index` / `revealed_policies` を直接変更しない形へ移行。
- `tests/smoke_ui_visual_states.gd` で 1920x1080 / 1280x720 の default、worker assignment、resolution、final 状態を検査。
- `tools/render_board_action_preview.gd` でプレビュー時の恐慌値指定を可能化。
- `export_presets.cfg` と `tools/check_web_export.ps1` を追加し、Web書き出しを実行可能化。
- Godotの自動インポート対象から `tmp/` と `docs/assets/` を外し、QA画像やブラウザ確認画像が配布パックへ混入しないようにした。

検証済みコマンド:

```powershell
python tools/validate_data.py
python tools/simulate_balance.py
.\tools\check_godot.ps1
.\tools\check_web_export.ps1
.\tools\validate_token_assets.ps1
godot_console --headless --path . --script res://tools/monte_carlo_balance.gd
git diff --check
```

スクリーンショットQA:

- `tmp/screenshots/ui_resolution_warn_desktop.png`
- `tmp/screenshots/ui_turn_news_desktop_fixed.png`
- `tmp/screenshots/ui_final_small_updated.png`
- `tmp/screenshots/web_export_browser.png`
- `tmp/screenshots/web_export_after_start.png`
- `tmp/screenshots/web_export_after_multiworker.png`
- `tmp/screenshots/web_export_after_multiworker_started.png`

Web書き出し確認:

- `exports/web/index.html` / `index.js` / `index.pck` / `index.wasm` の生成を確認。
- ローカルHTTPサーバー `http://127.0.0.1:8765/index.html` でWeb版をロード。
- ブラウザ上でタイトル画面の日本語表示、キャンバス非空、開始クリック後の国選択画面遷移、コンソールエラーなしを確認。

残課題:

- 危機管理班・選挙対策チーム・広報チームなど、§10で v0.3 候補と明記された追加ワーカーは未導入。
