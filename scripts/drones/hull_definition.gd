extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var motion: String = "quadruped"
@export var sockets: Dictionary = {}
@export var payload_kg: float = 100.0
@export var idle_kw: float = 0.1
@export var battery_kwh: float = 1.0
@export var speed: float = 3.0
@export var slope_degrees: float = 25.0
@export var step_height: float = 0.35
@export var external_power: bool = false
@export var script_only: bool = false
@export var travel_kw: float = -1.0
