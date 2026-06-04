# UI方向性案

## A案: 政策会議の卓上

採用案。

各国プレイヤーが政策会議のテーブルに座り、世界イベントカード、国内圧力カード、政策案の伏せ札、ワーカートークンを扱う画面にする。

向いている理由:

- 設計書のターン構造と相性がよい
- 政策を「選んで伏せる」感覚が出る
- ワーカーが資源獲得ではなく政策遂行能力であることが伝わる
- 国際交渉テーブルを中央に置ける

画面要素:

- 世界ボード
- 国際交渉テーブル
- 国家マット
- 国内圧力カード
- 政策案スロット
- ワーカートークン
- 手札カード
- 山札/捨て札
- 解決ログ

## B案: 世界危機ボード中心

世界恐慌、保護主義、金融不安を大きな共有ボードとして中央に置く案。

強み:

- 世界が壊れていく緊張感が強い
- 近隣窮乏化政策の副作用が見えやすい

弱み:

- 各国の政策計画と手札が脇役になりやすい
- ボードゲームというより危機管理シミュレータに見えやすい

## C案: カードゲーム卓上

手札と政策カードを主役にし、国家トラックを最小限のトークンで表す案。

強み:

- カードゲームとして直感的
- 伏せ札、同時公開、デッキ変質が強く見える

弱み:

- マクロ経済の世界波及がやや見えにくい
- 国家ボードの個性が弱くなりやすい

## 採用方針

v0.1はA案をベースにする。

ただし、B案の「世界危機が共有ボード上で進む」感覚と、C案の「政策カードを伏せて公開する」感覚を部分的に取り入れる。

## アセット方針

生成済み:

- `assets/ui/policy_room_background.png`: 卓上背景
- `assets/ui/tokens/macronomica_token_atlas.png`: 24個のトークンアトラス
- `assets/ui/tokens/*.png`: 個別トークン

トークン用途:

- 財政政策: `fiscal_treasury.png`
- 金融政策: `central_bank.png`
- 通商政策: `trade_port.png`
- 産業政策: `industry_factory.png`
- 金融規制: `financial_shield.png`
- 国際協調: `diplomacy_handshake.png`
- 改革: `reform_wrench.png`
- 社会政策: `social_safety_net.png`
- 債務: `debt_chain.png`
- 為替: `currency_arrows.png`
- 失業: `unemployment_people.png`
- インフレ: `inflation_flame.png`
- 世界需要: `world_demand_globe.png`
- 世界金利: `interest_rate_coin.png`
- 貿易開放度: `trade_gate.png`
- 国際金融不安: `financial_storm.png`
- 世界恐慌: `depression_shadow.png`
- 保護主義: `protection_wall.png`
- 国際協調: `coordination_ring.png`
- 官僚団: `bureaucrat_seal.png`
- 中銀スタッフ: `central_bank_staff_seal.png`
- 外交官: `diplomat_seal.png`
- 監査官: `auditor_seal.png`
- ロビイスト: `lobbyist_seal.png`

