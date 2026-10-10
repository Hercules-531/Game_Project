extends Resource

@export var battery_capacity: float = 2.0
@export var generator_kw: float = 4.0
@export var base_load_kw: float = 0.3
@export var oxygen_load_kw: float = 0.8
@export var heater_load_kw: float = 1.8
@export var fuel_per_second: float = 1.0 / 60.0
@export var oxygen_use_per_second: float = 0.03
@export var oxygen_gain_per_second: float = 0.08
@export var cooling_per_second: float = 0.004
@export var heating_per_second: float = 0.012
@export var rations_per_second: float = 1.0 / 1800.0
@export var grace_seconds: float = 120.0
