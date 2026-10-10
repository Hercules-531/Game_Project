extends Node

var ash_seconds: float = 0.0
@onready var weather: Node = get_parent().get_node("Weather")
@onready var conditions: Node = get_parent().get_node("Conditions")
@onready var salvage: Node = get_parent().get_node("Salvage")

func _ready() -> void:
	weather.changed.connect(_update)
	_update()

func _update() -> void:
	conditions.wear_multiplier = 2.0 if weather.current == "ash" else 1.0
	conditions.fault_multiplier = 2.0 if weather.current == "ash" else 1.0

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0:
		return
	if weather.current == "ash":
		ash_seconds = minf(30.0,ash_seconds + seconds)
		if ash_seconds >= 30.0 and salvage.items.ash_cache.state == "buried":
			salvage.items.ash_cache.state = "available"
			salvage.items.ash_cache.apply_state()

func snapshot() -> Dictionary:
	return {"ash_seconds":ash_seconds}

static func validate(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var seconds: Variant = data.get("ash_seconds")
	return (seconds is float or seconds is int) and is_finite(seconds) and seconds >= 0.0 and seconds <= 30.0

func restore(data: Dictionary) -> void:
	assert(validate(data))
	ash_seconds = data.ash_seconds
	_update()
