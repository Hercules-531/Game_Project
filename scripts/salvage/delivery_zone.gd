extends Node3D

const CATALOG = preload("res://resources/world/approach_salvage.tres")
const ITEM = preload("res://scripts/salvage/salvage_item.gd")
const Cargo = preload("res://scripts/salvage/cargo_hold.gd")
var items: Dictionary = {}
@onready var fleet: Node3D = get_parent().get_node("Fleet")
@onready var inventory: Node = get_parent().get_node("Inventory")

func _ready() -> void:
	for definition in CATALOG.sites:
		var item := ITEM.new()
		item.definition = definition
		item.name = definition.id
		item.position = definition.at
		add_child(item)
		items[definition.id] = item

func recover_nearest(drone: Node) -> bool:
	if drone == null:
		return false
	var nearest: Node3D
	var distance := 3.0
	for item in items.values():
		var gap: float = item.global_position.distance_to(drone.global_position)
		if item.state == "available" and gap <= distance:
			nearest = item
			distance = gap
	if nearest == null or not Cargo.can_load(drone,nearest.definition.mass):
		return false
	nearest.state = "carried"
	nearest.carrier_id = drone.identity
	drone.cargo_kg += nearest.definition.mass
	nearest.apply_state()
	return true

func _physics_process(_delta: float) -> void:
	for item in items.values():
		if item.state != "carried":
			continue
		var drone: Node3D = fleet.drone(item.carrier_id)
		if drone != null:
			var offset := Vector3(0,0,1.65) if drone.module_efficiency("cargo_rack") <= 0.0 else Vector3(0,1.0,0)
			item.global_position = drone.global_position + drone.global_basis * offset

func deliver(drone: Node, exterior: bool = false) -> int:
	if drone == null: return 0
	var gantry: bool = exterior and drone.hull().external_power and drone.position.distance_to(Vector3(0,0.02,-14)) <= 8.0
	var destination: Node = inventory
	if not gantry and (drone.deployed or drone.position.z < -6.0):
		destination = get_parent().get_node("Rail").field_stock(drone)
		if destination==null: return 0
	var delivered := 0
	for item in items.values():
		if item.state != "carried" or item.carrier_id != drone.identity:
			continue
		var kind: String = item.definition.kind
		if float(destination.get(kind)) + float(item.definition.amount) > 1000000.0:
			continue
		item.state = "delivered"
		item.carrier_id = ""
		drone.cargo_kg -= item.definition.mass
		destination.set(kind,destination.get(kind) + item.definition.amount)
		item.apply_state()
		delivered += 1
	if delivered > 0:
		if destination==inventory: inventory.changed.emit()
		else: destination.notify()
	return delivered

func snapshot() -> Array:
	var data := []
	for item in items.values():
		data.append(item.snapshot())
	return data

static func validate(data: Variant, legacy: bool = false) -> bool:
	if not data is Array or data.size() != (3 if legacy else CATALOG.sites.size()):
		return false
	var known := {}
	for definition in CATALOG.sites:
		known[definition.id] = true
	var seen := {}
	for record in data:
		if not record is Dictionary or not known.has(record.get("id")) or seen.has(record.id) or record.get("state") not in ["buried","available","carried","delivered"] or not record.get("carrier") is String:
			return false
		if record.state == "buried" and record.id != "ash_cache":
			return false
		if legacy and record.id == "ash_cache":
			return false
		if (record.state == "carried") != (not record.carrier.is_empty()):
			return false
		seen[record.id] = true
	return true

func restore(data: Array) -> void:
	assert(validate(data,data.size() == 3))
	for item in items.values():
		item.state = "buried" if item.definition.get("buried",false) else "available"
		item.carrier_id = ""
		item.apply_state()
	for record in data:
		var item: Node3D = items[record.id]
		item.state = record.state
		item.carrier_id = record.carrier
		item.apply_state()
