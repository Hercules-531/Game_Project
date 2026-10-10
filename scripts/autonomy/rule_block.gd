extends Resource
const KINDS = ["waypoint","battery_abort","hostile_silent","scrap_collect"]
static func valid(rules: Variant) -> bool:
	if not rules is Array or rules.is_empty() or rules.size() > 32:
		return false
	for rule in rules:
		if not rule is Dictionary or rule.get("kind") not in KINDS:
			return false
		if rule.kind == "waypoint":
			for key in ["x","north"]:
				var value: Variant = rule.get(key)
				if not (value is float or value is int) or not is_finite(value):
					return false
			if absf(rule.x) > 58.0 or rule.north < 0.0 or rule.north > 598.0:
				return false
	return true
static func describe(rule: Dictionary) -> String:
	match rule.kind:
		"waypoint": return "GO TO  E %.1fm / N %.1fm" % [rule.x,rule.north]
		"battery_abort": return "IF CELL <20%  /  ABORT AND RETURN"
		"hostile_silent": return "IF HOSTILE PING  /  GO SILENT"
		"scrap_collect": return "IF SALVAGE IN REACH  /  LOAD OR WINCH"
	return ""
