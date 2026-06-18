# カードスキーマ

カードは `data/cards/*.json` に配列で定義します。

```json
{
  "id": "fiscal_stimulus",
  "type": "policy",
  "display_name": "財政刺激",
  "tags": ["fiscal", "demand"],
  "lag": 0,
  "costs": {"fiscal": 2, "political": 1, "administrative": 1},
  "effects": {
    "country": {"gdp_gap": 2, "unemployment": -1, "debt": 1},
    "world": {"world_demand": 1}
  },
  "spillovers": [
    {"target_tag": "exporter", "effects": {"gdp_gap": -1}}
  ],
  "mutations": {
    "add_to_deck": ["fiscal_rigidity"],
    "remove_from_deck": ["corruption_risk"],
    "add_world_card": "retaliatory_tariffs"
  }
}
```

数値はトラックに加算されます。負の値は低下を意味します。

## policy

- `costs`: `fiscal` / `political` / `administrative` / `credibility` / `international` / `industrial`
- `effects.country`: 自国トラックへの効果
- `effects.world`: 世界トラックへの効果
- `lag`: 成立後に効果が発現するまでのターン数。現行MVPでは `0` または `1` を使います
- `spillovers`: `target_tag` を持つ他国に効果を与える
- `mutations.add_to_deck`: 自国の状態デッキの山札トップへ、列挙順に追加（政策カードは追加しない）
- `mutations.remove_from_deck`: 自国の状態デッキ山札・捨て札・公開状態カードから該当カードを1枚除去
- `mutations.add_world_card`: 世界イベント捨て札へ追加

成立判定はコスト種別ごとに行います。行政不足または `lag` つき政策は `pending_effects` に積まれ、後続ターン開始時に発現します。政治コストだけが不足した場合は補助金混入として扱い、政策効果は出ますが債務と利権カードが増えます。

## country preset

国家プリセットは `data/countries/presets.json` に定義します。

- `election_turn`: 最初の選挙ターン。以後 `election_period` ごとに選挙が来ます
- `election_period`: 選挙周期。省略時は4ターン
- `starting_tracks.expected_inflation`: 期待インフレ。流動性の罠とデフレスパイラルに使います
- `starting_tracks.influence`: 国際影響力。共同宣言遵守や国際政策で増え、最終スコアと国際容量に効きます

## vulnerability

状態カードはターン開始時に2枚公開され、その公開中に発火します。

```json
{
  "id": "commodity_price_dependence",
  "type": "vulnerability",
  "display_name": "資源価格依存",
  "effects": {
    "on_turn_start": {"political_capital": -1},
    "when_commodity_shock": {"gdp_gap": -2, "current_account": -1}
  },
  "response": {
    "removed_by_tags": ["resource", "industrial"],
    "extra_costs": {"administrative": 1}
  }
}
```

条件付き効果キーは `when_world_demand_negative` / `when_currency_down` / `when_commodity_shock` を使えます。
`response` は対応任務用のメタデータです。選択政策のタグが `removed_by_tags` に合い、`extra_costs` を支払える場合、解決時に公開状態カードを1枚除去します。

## world event

世界イベントは単発効果に加えて、タグ別の状態デッキ汚染、危機政策の一時追加、
任意の `persistent_crisis` を持てます。

```json
{
  "id": "global_credit_crunch",
  "display_name": "国際信用収縮",
  "effects": {
    "world": {"international_financial_instability": 2},
    "tagged_countries": [
      {
        "tag": "foreign_debt",
        "effects": {"financial_stress": 2},
        "add_state_cards": ["sudden_stop"]
      },
      {
        "tag": "reserve_currency",
        "effects": {"political_capital": -1},
        "add_policy_menu": ["last_resort_lender"]
      }
    ]
  },
  "persistent_crisis": {
    "duration": 3,
    "clear_text": "世界協調4以上",
    "clear_when": {"world_min": {"global_coordination": 4}},
    "effects": {"world": {"international_financial_instability": 1}}
  }
}
```

- `duration`: 解除されない場合の継続ターン数
- `effects`: 継続中の各ターンに適用する世界イベント型の効果
- `effects.tagged_countries[].add_state_cards`: 該当タグ国の状態デッキ山札トップへ状態カードを追加
- `effects.tagged_countries[].add_policy_menu`: 該当タグ国の政策カタログへ危機政策を追加（既にある場合は重複しない）。
  追加された政策は以後の `active_agenda` に議題化されうる。キー名は既存データ互換のため維持する。
- `clear_when.world_min`: 指定トラックが値以上なら解除
- `clear_when.world_max`: 指定トラックが値以下なら解除
- `clear_text`: UIに表示する解除条件
