extends RefCounted
const OXYGEN_SECONDS := 480.0
const FILTER_SECONDS := 300.0
const WALK_SPEED := 1.15
const JUMPER_KWH := 0.30
static func validate(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key in ["active","departed","dead"]:
		if not data.get(key) is bool:
			return false
	if not data.get("escort") is String or not data.get("reason") is String:
		return false
	if data.has("flash"):
		var flash: Variant = data.flash
		if not (flash is float or flash is int) or not is_finite(flash) or flash < 0.0 or flash > 10.0: return false
	var limits := {"oxygen":OXYGEN_SECONDS,"filter":FILTER_SECONDS,"jumper":JUMPER_KWH}
	for key in limits:
		var value: Variant = data.get(key)
		if not (value is float or value is int) or not is_finite(value) or value < 0.0 or value > limits[key]:
			return false
	return not data.dead or data.active
