extends RefCounted
class_name PublicChoiceResolver

static func resolve_pressure(country, policy: Dictionary) -> String:
	if country.domestic_pressure.is_empty():
		return ""
	var demand: Dictionary = country.domestic_pressure.get("demand", {})
	var preferred: Array = demand.get("preferred_policy_tags", [])
	var tags: Array = policy.get("tags", [])
	var satisfied := false
	for tag in preferred:
		if tags.has(tag):
			satisfied = true
			break
	var effects: Dictionary = demand.get("if_satisfied" if satisfied else "if_ignored", {})
	country.apply_effects(effects)
	if satisfied:
		return "%s は国内圧力「%s」を満たしました。" % [country.display_name, country.domestic_pressure.get("display_name", "")]
	return "%s は国内圧力「%s」を無視し、政治的反発を受けました。" % [country.display_name, country.domestic_pressure.get("display_name", "")]
