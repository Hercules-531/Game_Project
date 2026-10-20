extends Node

signal changed
const CATALOG = preload("res://resources/drones/opening_fleet.tres")
const DRONE_MODEL = preload("res://scripts/drones/drone.gd")
@onready var inventory: Node = get_parent().get_node("Inventory")
@onready var fleet: Node3D = get_parent().get_node("Fleet")
@onready var life: Node = get_parent().get_node("LifeSupport")


func fit(machine_id: String, socket: String, serial: int) -> bool:
	var machine: Node = fleet.drone(machine_id)
	var stock: Node = service_stock(machine)
	var part: Dictionary = stock.part(serial) if stock!=null else {}
	if not _at_bay(machine) or part.is_empty() or not machine.can_install(socket,part.id):
		return false
	if not machine.install(socket,part.id,part.condition):
		return false
	stock.take_part(serial)
	changed.emit()
	return true


func remove(machine_id: String, socket: String) -> bool:
	var machine: Node = fleet.drone(machine_id)
	if not _at_bay(machine):
		return false
	var stock: Node = service_stock(machine)
	if stock.parts.size()>=2000 or inventory.next_serial>=10000000: return false
	var territory: Node = get_parent().get_node_or_null("Territory")
	if territory != null and territory.cargo.has(machine_id) and machine.modules.get(socket,"") == "prefab_winch": return false
	var part: Dictionary = machine.remove_module(socket)
	if part.is_empty():
		return false
	stock.add_part(part.id,part.condition)
	changed.emit()
	return true


func repair_cost(machine_id: String, socket: String) -> int:
	var machine: Node = fleet.drone(machine_id)
	if not _at_bay(machine) or (not machine.modules.has(socket) and not machine.components.has(socket)):
		return 0
	var condition: float = machine.components[socket] if machine.components.has(socket) else machine.condition[socket]
	return maxi(1 if machine.faults.has(socket) else 0,ceili((100.0 - condition) * 0.2))


func _at_bay(machine: Node) -> bool:
	return service_stock(machine)!=null

func service_stock(machine: Node) -> Node:
	var excavation: Node = get_parent().get_node_or_null("Excavation")
	if machine==null or machine.destroyed() or (excavation!=null and excavation.busy(machine.identity)): return null
	var control := get_parent().get_node_or_null("FleetControl")
	if control!=null and control.transfer.get("id","")==machine.identity: return null
	var territory: Node = get_parent().get_node_or_null("Territory")
	if territory!=null and territory.job.get("id","")==machine.identity: return null
	if not machine.deployed or (machine.hull().external_power and machine.position.distance_to(Vector3(0,0.02,-14))<=8.0): return inventory
	return get_parent().get_node("Rail").field_stock(machine)


func repair(machine_id: String, socket: String) -> bool:
	var machine: Node = fleet.drone(machine_id)
	var cost := repair_cost(machine_id,socket)
	var stock: Node = service_stock(machine)
	if cost <= 0 or stock==null or not stock.spend_scrap(cost):
		return false
	if machine.components.has(socket):
		machine.components[socket] = 100.0
	else:
		machine.condition[socket] = 100.0
	machine.faults.erase(socket)
	machine.configuration_changed.emit()
	changed.emit()
	return true


func assemble(hull_id: String) -> bool:
	if CATALOG.hull(hull_id) == null or int(inventory.hulls.get(hull_id,0)) < 1 or fleet.get_child_count() >= 32:
		return false
	var bays := [Vector3(-5.95,0.02,3.0),Vector3(-4.1,0.02,2.8),Vector3(-5.65,0.02,0.8),Vector3(-3.85,0.02,0.8)]
	if CATALOG.hull(hull_id).external_power: bays = [Vector3(4,0.02,-20)]
	var free_bay := -1
	for index in bays.size():
		var shape := BoxShape3D.new()
		shape.size = DRONE_MODEL.collision_size(hull_id)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = bays[index] + Vector3(0,shape.size.y*0.5,0)
		query.collision_mask = 1
		if fleet.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			free_bay = index
			break
	if free_bay < 0:
		return false
	var serial := 1
	while fleet.drone("%s_%02d" % [hull_id,serial]) != null:
		serial += 1
	var machine = fleet.DRONE.instantiate()
	machine.hull_id = hull_id
	machine.identity = "%s_%02d" % [hull_id,serial]
	machine.name = machine.identity
	machine.battery = 0.0 # New cells must be charged from the paid bunker grid.
	machine.position = bays[free_bay]
	machine.deployed = machine.hull().external_power
	inventory.hulls[hull_id] = int(inventory.hulls[hull_id]) - 1
	fleet.add_child(machine)
	inventory.changed.emit()
	changed.emit()
	return true


func resupply(kind: String) -> bool:
	if life.dead:
		return false
	if kind == "fuel":
		var amount := minf(10.0,minf(inventory.fuel,120.0 - life.fuel))
		if amount <= 0.0:
			return false
		inventory.fuel -= amount
		life.fuel += amount
	elif kind == "rations":
		var amount := minf(1.0,minf(inventory.rations,8.0 - life.rations))
		if amount <= 0.0:
			return false
		inventory.rations -= amount
		life.rations += amount
	else:
		return false
	inventory.changed.emit()
	life.changed.emit()
	changed.emit()
	return true
