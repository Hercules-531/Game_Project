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
	if not drone.deployed or not drone.has_power():
		return 0.0
	return required_kw(drone)

func required_kw(drone: Node) -> float:
	if drone.component_efficiency("cell") <= 0.0: return 0.0
	var throttle: float = drone.get_node("Controller").command.length()
	var travel: float = BALANCE.hover_travel_kw if drone.hull_id == "hover" else BALANCE.mule_travel_kw
	if drone.hull().travel_kw >= 0.0: travel = drone.hull().travel_kw
	var radiation: float = get_parent().get_node("EnvironmentHazards").radiation(drone.position)
	var cold: float = BALANCE.cold_kw * get_parent().get_node("EnvironmentHazards").cold_multiplier(drone.position)
	return (drone.draw_kw() + cold + radiation * 0.5 + drone.work_noise * 0.5 + travel * throttle * (1.0 + drone.cargo_kg / drone.hull().payload_kg)) / drone.component_efficiency("cell")


func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0:
		return
	for drone in fleet.get_children():
		if not drone.hull().external_power and not get_parent().get_node("Orders").field_powered(drone.identity):
			drone.battery = maxf(0.0,drone.battery - draw_kw(drone) * seconds / 3600.0)
			drone.battery = minf(drone.hull().battery_kwh,drone.battery + solar_kw(drone) * seconds / 3600.0)
		if not drone.has_power():
			drone.get_node("Controller").stop()

func solar_kw(drone: Node) -> float:
	if not drone.deployed or drone.module_efficiency("solar_panel") <= 0.0: return 0.0
	var at: Vector3 = drone.global_position + Vector3(0,2,0)
	var sun: Node3D = get_parent().get_node("Surface/SurfaceSun")
	var ray := PhysicsRayQueryParameters3D.create(at,at + sun.global_basis.z * 80.0,1,[drone.get_rid()])
	if not drone.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return 0.0
	return (1.75 if get_parent().get_node("Weather").current == "sunlight" else 1.0) * minf(1.0,drone.module_efficiency("solar_panel"))

func reserve_fraction(drone: Node) -> float:
	if drone.hull().external_power:
		var territory: Node = get_parent().get_node_or_null("Territory")
		if territory != null and territory.power_links.has(drone.identity): return territory.sites[int(territory.power_links[drone.identity])].battery / 12.0
		var tether: Node = get_parent().get_node("PowerTether")
		var donor: Node = fleet.drone(tether.links.get(drone.identity,""))
		return donor.battery / donor.hull().battery_kwh if donor != null else 0.0
	return drone.battery / drone.hull().battery_kwh


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
