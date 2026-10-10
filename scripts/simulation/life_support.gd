extends Node
## All rates use elapsed simulation seconds; one-second steps bound exhaustion.

signal changed
signal died
const BALANCE = preload("res://resources/balance/life_support.tres")
var balance: Resource = BALANCE
var battery: float = 2.0
var fuel: float = 120.0
var oxygen: float = 100.0
var temperature: float = 18.0
var rations: float = 8.0
var critical_seconds: float = 0.0
var remainder: float = 0.0
var generator_on: bool = true
var oxygen_on: bool = true
var heater_on: bool = true
var dead: bool = false
var supplied_fraction: float = 1.0


func _physics_process(delta: float) -> void:
	advance(delta)


func load_kw() -> float:
	return balance.base_load_kw + (balance.oxygen_load_kw if oxygen_on else 0.0) + (balance.heater_load_kw if heater_on else 0.0)


func advance(seconds: float) -> void:
	if dead or not is_finite(seconds) or seconds <= 0.0:
		return
	remainder += seconds
	while remainder >= 1.0 - 0.000000001 and not dead:
		remainder = maxf(0.0,remainder - 1.0)
		_step()
	changed.emit()


func _step() -> void:
	var burned: float = minf(fuel,balance.fuel_per_second) if generator_on else 0.0
	fuel -= burned
	var generated: float = balance.generator_kw / 3600.0 * burned / balance.fuel_per_second
	var demand: float = load_kw() / 3600.0
	var delivered: float = minf(demand,battery + generated)
	battery = clampf(battery + generated - delivered,0.0,balance.battery_capacity)
	supplied_fraction = delivered / demand if demand > 0.0 else 1.0
	oxygen = clampf(oxygen - balance.oxygen_use_per_second + (balance.oxygen_gain_per_second * supplied_fraction if oxygen_on else 0.0),0.0,100.0)
	temperature = clampf(temperature - balance.cooling_per_second + (balance.heating_per_second * supplied_fraction if heater_on else 0.0),-20.0,18.0)
	rations = maxf(0.0,rations - balance.rations_per_second)
	if not critical_reason().is_empty():
		critical_seconds = minf(balance.grace_seconds,critical_seconds + 1.0)
	else:
		critical_seconds = 0.0
	if critical_seconds >= balance.grace_seconds:
		dead = true
		died.emit()


func critical_reason() -> String:
	var reasons: PackedStringArray = []
	if oxygen <= 0.0:
		reasons.append("OXYGEN DEPLETED")
	if temperature <= 0.0:
		reasons.append("DANGEROUS COLD")
	if rations <= 0.0:
		reasons.append("RATIONS DEPLETED")
	return " / ".join(reasons)


func warning() -> String:
	var critical := critical_reason()
	if not critical.is_empty():
		return "%s | RESTORE WITHIN %ds" % [critical,ceili(balance.grace_seconds - critical_seconds)]
	var warnings: PackedStringArray = []
	if oxygen < 25.0:
		warnings.append("LOW OXYGEN")
	if temperature < 8.0:
		warnings.append("LOW TEMPERATURE")
	if rations < 1.0:
		warnings.append("LOW RATIONS")
	if battery < 0.4:
		warnings.append("LOW BATTERY")
	if fuel < 15.0:
		warnings.append("LOW GENERATOR FUEL")
	return " / ".join(warnings)


func set_circuit(circuit: String, enabled: bool) -> void:
	if circuit not in ["generator_on","oxygen_on","heater_on"] or dead:
		return
	set(circuit,enabled)
	changed.emit()


func snapshot() -> Dictionary:
	return {"battery":battery,"fuel":fuel,"oxygen":oxygen,"temperature":temperature,
		"rations":rations,"critical_seconds":critical_seconds,"remainder":remainder,
		"supplied_fraction":supplied_fraction,
		"generator_on":generator_on,"oxygen_on":oxygen_on,"heater_on":heater_on}


static func validate(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var ranges := {"battery":[0.0,2.0],"fuel":[0.0,120.0],"oxygen":[0.0,100.0],
		"temperature":[-20.0,18.0],"rations":[0.0,8.0],"critical_seconds":[0.0,120.0],"remainder":[0.0,1.0],"supplied_fraction":[0.0,1.0]}
	for key in ranges:
		var value: Variant = data.get(key)
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
		if value < ranges[key][0] or value > ranges[key][1]:
			return false
	if data.remainder >= 1.0 or data.critical_seconds >= 120.0:
		return false
	for key in ["generator_on","oxygen_on","heater_on"]:
		if not data.get(key) is bool:
			return false
	return true


func restore(data: Dictionary) -> void:
	assert(validate(data))
	for key in data:
		if snapshot().has(key):
			set(key,data[key])
	dead = false
	changed.emit()
