extends RefCounted
class_name TrackPresenter

static func track_bounds(key: String) -> Array:
	if ["world_demand", "world_interest_rate", "gdp_gap", "exchange_rate", "current_account", "expected_inflation"].has(key):
		return [-5, 5]
	return [0, 10]

static func track_color(key: String, value: int, colors: Dictionary) -> Color:
	if ["unemployment", "debt", "financial_stress", "international_financial_instability", "depression", "protectionism"].has(key):
		return colors["good"] if value <= 3 else (colors["warn"] if value <= 6 else colors["bad"])
	if ["trade_openness", "global_coordination", "political_capital", "current_account", "influence"].has(key):
		return colors["bad"] if value <= 1 else (colors["warn"] if value <= 3 else colors["good"])
	if key == "inflation" or key == "expected_inflation":
		return colors["good"] if value >= 1 and value <= 3 else (colors["warn"] if value >= 0 and value <= 5 else colors["bad"])
	return colors["blue"]

static func marker_count(key: String, value: int) -> int:
	if ["world_demand", "world_interest_rate", "gdp_gap", "exchange_rate", "current_account", "expected_inflation"].has(key):
		return clampi(value + 3, 0, 7)
	if ["trade_openness", "global_coordination", "political_capital", "influence"].has(key):
		return clampi(value, 0, 7)
	if key == "inflation":
		return clampi(abs(value - 2) + 1, 0, 7)
	return clampi(value, 0, 7)
