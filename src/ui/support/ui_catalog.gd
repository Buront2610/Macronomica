extends RefCounted
class_name UiCatalog

static func rank_icon(rank: int) -> String:
	if rank == 1:
		return "王冠"
	if rank == 2:
		return "勲章"
	if rank == 3:
		return "星"
	return "旗"

static func country_emblem(index: int) -> String:
	var emblems := ["A", "B", "C", "D"]
	return emblems[index] if index >= 0 and index < emblems.size() else "N"

static func worker_token(worker: String) -> String:
	var names := {
		"bureaucrats": "bureaucrat_seal",
		"central_bank_staff": "central_bank_staff_seal",
		"diplomat": "diplomat_seal",
		"auditor": "auditor_seal",
		"lobbyist": "lobbyist_seal"
	}
	return names.get(worker, "bureaucrat_seal")

static func track_token(key: String) -> String:
	var names := {
		"gdp_gap": "world_demand_globe",
		"inflation": "inflation_flame",
		"unemployment": "unemployment_people",
		"debt": "debt_chain",
		"financial_stress": "financial_storm",
		"political_capital": "bureaucrat_seal",
		"exchange_rate": "currency_arrows",
		"current_account": "trade_port",
		"world_demand": "world_demand_globe",
		"world_interest_rate": "interest_rate_coin",
		"trade_openness": "trade_gate",
		"international_financial_instability": "financial_storm",
		"depression": "depression_shadow",
		"protectionism": "protection_wall",
		"global_coordination": "coordination_ring"
	}
	return names.get(key, "coordination_ring")

static func card_token(card: Dictionary) -> String:
	var tags: Array = card.get("tags", [])
	if card.get("type", "") != "policy":
		return "debt_chain"
	if tags.has("fiscal"):
		return "fiscal_treasury"
	if tags.has("monetary") or tags.has("qe") or tags.has("rate_hike"):
		return "central_bank"
	if tags.has("trade") or tags.has("tariff"):
		return "trade_port"
	if tags.has("industrial") or tags.has("infrastructure"):
		return "industry_factory"
	if tags.has("financial_regulation") or tags.has("stability"):
		return "financial_shield"
	if tags.has("international") or tags.has("cooperation"):
		return "diplomacy_handshake"
	if tags.has("reform"):
		return "reform_wrench"
	if tags.has("social_policy") or tags.has("employment"):
		return "social_safety_net"
	return "coordination_ring"

static func short_phase_name(phase: String) -> String:
	var names := {
		"world_event": "世界",
		"domestic_update": "国内",
		"negotiation": "交渉",
		"policy_planning": "計画",
		"worker_assignment": "配置",
		"simultaneous_reveal": "公開",
		"resolution": "解決"
	}
	return names.get(phase, phase)

static func track_name(key: String) -> String:
	var names := {
		"gdp_gap": "GDPギャップ",
		"inflation": "インフレ",
		"unemployment": "失業",
		"debt": "政府債務",
		"financial_stress": "金融ストレス",
		"political_capital": "政治資本",
		"exchange_rate": "為替",
		"current_account": "経常収支",
		"world_demand": "世界需要",
		"world_interest_rate": "世界金利",
		"trade_openness": "貿易開放度",
		"international_financial_instability": "金融不安",
		"depression": "世界恐慌",
		"protectionism": "保護主義",
		"global_coordination": "国際協調"
	}
	return names.get(key, key)

static func short_track_name(key: String) -> String:
	var names := {
		"gdp_gap": "GDP",
		"inflation": "物価",
		"unemployment": "失業",
		"debt": "債務",
		"financial_stress": "金融",
		"political_capital": "政治",
		"exchange_rate": "為替",
		"current_account": "経常"
	}
	return names.get(key, key)

static func cost_name(key: String) -> String:
	var names := {"fiscal": "財政", "political": "政治", "administrative": "行政", "credibility": "信認", "international": "国際", "industrial": "産業"}
	return names.get(key, key)

static func worker_name(worker: String) -> String:
	var names := {"bureaucrats": "官僚団", "central_bank_staff": "中銀スタッフ", "diplomat": "外交官", "auditor": "監査官", "lobbyist": "ロビイスト"}
	return names.get(worker, worker)

static func worker_tip(worker: String) -> String:
	var tips := {
		"bureaucrats": "行政コストを1下げます。",
		"central_bank_staff": "信認コストを1下げます。",
		"diplomat": "国際コストを1下げます。",
		"auditor": "汚職・レント系カードを抑えます。",
		"lobbyist": "政治コストを1下げますが、利権カードを追加します。"
	}
	return tips.get(worker, "")

static func short_card_name(card: Dictionary) -> String:
	var display_name := String(card.get("display_name", ""))
	var aliases := {
		"利下げ・量的緩和": "利下げ",
		"関税引き上げ": "関税",
		"金融規制強化": "金融規制",
		"国際スワップライン": "スワップ",
		"安定化基金取り崩し": "基金取崩",
		"累進税制改革": "税制改革",
		"雇用・生活安定策": "雇用安定",
		"同時財政刺激協定": "協調刺激",
		"反汚職キャンペーン": "反汚職",
		"資源依存の多角化": "多角化",
		"外貨建て債務": "外貨債務",
		"民間債務の重荷": "民間債務",
		"資産価格への敏感性": "資産敏感",
		"輸出企業ロビー圧力": "輸出ロビー",
		"商品価格依存": "商品依存"
	}
	return aliases.get(display_name, display_name.substr(0, 5))
