# カードスキーマ

カードは `data/cards/*.json` に配列で定義します。

```json
{
  "id": "fiscal_stimulus",
  "type": "policy",
  "display_name": "財政刺激",
  "tags": ["fiscal", "demand"],
  "costs": {"fiscal": 2, "political": 1, "administrative": 1},
  "effects": {
    "country": {"gdp_gap": 2, "unemployment": -1, "debt": 1},
    "world": {"world_demand": 1}
  },
  "mutations": {
    "add_to_deck": ["fiscal_rigidity"]
  }
}
```

数値はトラックに加算されます。負の値は低下を意味します。

