extends Node
signal changed
const CATALOG = preload("res://resources/weather/conditions.tres")
const GLOBAL = ["sunlight","smog","ash","rain","aurora"]
var current := "overcast"
var remaining := 300.0
var clock := 0.0
var forecast: Array = []
var rng := RandomNumberGenerator.new()
var optical_static: float = 0.0
var mutant_sense_multiplier: float = 1.0
var visibility_multiplier: float = 1.0
func _ready() -> void:
	rng.seed = 140527
	_fill()
	changed.connect(_apply)
	_apply()
func _apply() -> void:
	var smog: bool = current == "smog"
	var radio: Node = get_parent().get_node("Radio")
	radio.range_multiplier = 0.0 if current == "aurora" else (0.6 if smog else 1.0)
	radio.weather_latency = 1.5 if smog else 0.0
	radio.dropout_chance = 0.08 if smog else 0.015
	optical_static = 0.65 if smog else 0.0
	mutant_sense_multiplier = 0.5 if smog else 1.0
	visibility_multiplier = 1.5 if current == "sunlight" else 1.0
	get_parent().get_node("Orders").local_field_power = current == "aurora"
	if current == "aurora":
		get_parent().get_node("FleetControl").link.clear_all()
func _fill() -> void:
	while forecast.size() < 2:
		var previous: String = current if forecast.is_empty() else forecast.back().id
		var options: Array = GLOBAL.duplicate()
		options.erase(previous)
		forecast.append({"id":options[rng.randi_range(0,options.size() - 1)],"duration":float(rng.randi_range(1200,1800))})
func _physics_process(delta: float) -> void:
	advance(delta)
func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0: return
	clock += seconds
	remaining -= seconds
	while remaining <= 0.0:
		var next: Dictionary = forecast.pop_front()
		current = next.id
		remaining += next.duration
		_fill()
		changed.emit()
func force(id: String, seconds: float = 180.0) -> bool:
	if not CATALOG.conditions.has(id) or not is_finite(seconds) or seconds <= 0.0 or seconds > 1800.0: return false
	current = id
	remaining = seconds
	changed.emit()
	return true
func snapshot() -> Dictionary:
	return {"current":current,"remaining":remaining,"clock":clock,"forecast":forecast.duplicate(true),"rng":str(rng.state)}
static func validate(data: Variant) -> bool:
	if not data is Dictionary or not CATALOG.conditions.has(data.get("current")) or not data.get("forecast") is Array or data.forecast.size() != 2 or not data.get("rng") is String or not data.rng.is_valid_int(): return false
	for key in ["remaining","clock"]:
		var value: Variant = data.get(key)
		if not (value is float or value is int) or not is_finite(value) or value < 0: return false
	if data.remaining <= 0.0 or data.remaining > 1800.0 or data.clock > 1000000000.0: return false
	for event in data.forecast:
		if not event is Dictionary or event.get("id") not in GLOBAL: return false
		var duration: Variant = event.get("duration")
		if not (duration is float or duration is int) or not is_finite(duration) or duration < 1200 or duration > 1800: return false
	return true
func restore(data: Dictionary) -> void:
	assert(validate(data))
	current = data.current
	remaining = data.remaining
	clock = data.clock
	forecast = data.forecast.duplicate(true)
	rng.state = data.rng.to_int()
	changed.emit()
