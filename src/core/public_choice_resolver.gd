extends RefCounted
class_name PublicChoiceResolver

static func resolve_pressure(country, policy: Dictionary, resolution_state = "full", ignored_multiplier := 1) -> String:
	if country.domestic_pressure.is_empty():
		return ""
	var state := _normalize_resolution_state(resolution_state)
	var demand: Dictionary = country.domestic_pressure.get("demand", {})
	var preferred: Array = demand.get("preferred_policy_tags", [])
	var tags: Array = policy.get("tags", [])
	var tag_matches := false
	for tag in preferred:
		if tags.has(tag):
			tag_matches = true
			break
	var satisfied := tag_matches and state == "full"
	var partial := tag_matches and ["subsidized", "softened"].has(state)
	var effects: Dictionary = demand.get("if_satisfied" if satisfied or partial else "if_ignored", {})
	if partial:
		effects = _soften_effects(effects)
	if not satisfied and not partial and ignored_multiplier > 1:
		effects = _scale_effects(effects, ignored_multiplier)
	country.apply_effects(effects)
	if satisfied:
		return "%s は国内圧力「%s」を満たしました。" % [country.display_name, country.domestic_pressure.get("display_name", "")]
	if partial:
		return "%s は国内圧力「%s」を部分的に満たしました。" % [country.display_name, country.domestic_pressure.get("display_name", "")]
	return "%s は国内圧力「%s」を無視し、政治的反発を受けました。" % [country.display_name, country.domestic_pressure.get("display_name", "")]

static func _normalize_resolution_state(value) -> String:
	if value is bool:
		return "full" if bool(value) else "delayed"
	var state := String(value)
	if ["full", "subsidized", "softened", "delayed"].has(state):
		return state
	return "full"

static func _soften_effects(effects: Dictionary) -> Dictionary:
	var result := {}
	for key in effects.keys():
		var value := int(effects[key])
		result[key] = int(sign(value) * ceili(abs(value) / 2.0))
	return result

static func _scale_effects(effects: Dictionary, multiplier: int) -> Dictionary:
	var result := {}
	for key in effects.keys():
		result[key] = int(effects[key]) * multiplier
	return result
