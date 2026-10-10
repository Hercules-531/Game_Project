extends Node

const BALANCE = preload("res://resources/balance/drone_power.tres")
var charge_on: bool = true
var requests: Dictionary = {}
@onready var fleet: Node3D = get_parent().get_node("Fleet")
@onready var life: Node = get_parent().get_node("LifeSupport")


func _ready() -> void:
	life.energy_step.connect(_charge_step)
	_update_charge_request()


func _physics_process(delta: float) -> void:
	advance(delta)
	_update_charge_request()


func draw_kw(drone: Node) -> float:
	if not drone.deployed or drone.battery <= 0.0 or drone.component_efficiency("cell") <= 0.0:
		return 0.0
	var throttle: float = drone.get_node("Controller").command.length()
	var travel: float = BALANCE.hover_travel_kw if drone.hull_id == "hover" else BALANCE.mule_travel_kw
	return (drone.draw_kw() + BALANCE.cold_kw + travel * throttle * (1.0 + drone.cargo_kg / drone.hull().payload_kg)) / drone.component_efficiency("cell")


func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0:
		return
	for drone in fleet.get_children():
		drone.battery = maxf(0.0,drone.battery - draw_kw(drone) * seconds / 3600.0)
		if drone.battery <= 0.0:
			drone.get_node("Controller").stop()


func _update_charge_request() -> void:
	requests.clear()
	var total := 0.0
	var transfer_id: String = get_parent().get_node("FleetControl").transfer.get("id","")
	if charge_on:
		for drone in fleet.get_children():
			if not drone.deployed and drone.identity != transfer_id:
				var request: float = minf(BALANCE.charge_kw,maxf(0.0,drone.hull().battery_kwh - drone.battery) * 3600.0)
				requests[drone.identity] = request
				total += request
	life.charge_load_kw = total


func _charge_step(fraction: float) -> void:
	# This callback runs after the grid has paid for precisely these requests.
	for id in requests:
		var drone: Node = fleet.drone(id)
		if drone != null and not drone.deployed:
			drone.battery = minf(drone.hull().battery_kwh,drone.battery + requests[id] * fraction / 3600.0)
	_update_charge_request()


func snapshot() -> Dictionary:
	return {"charge_on":charge_on}


static func validate(data: Variant) -> bool:
	return data is Dictionary and data.get("charge_on") is bool


func restore(data: Dictionary) -> void:
	assert(validate(data))
	charge_on = data.charge_on
	_update_charge_request()
