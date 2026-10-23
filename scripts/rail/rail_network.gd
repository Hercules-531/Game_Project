extends Node3D
## Wired service is independent of radio. Only the current grid payment funds work.
signal changed
const Stock = preload("res://scripts/rail/depot_stock.gd")
const Inventory = preload("res://scripts/simulation/inventory.gd")
const Visual = preload("res://scripts/rail/rail_visual.gd")
const Plan = preload("res://scripts/excavation/excavation_plan.gd")
const Model = preload("res://scripts/drones/drone.gd")
var stocks: Dictionary = {}
var conditions: Dictionary = {}
var stations: Dictionary = {}
var car_built := false
var car_remaining := 0.0
var charge_on := false
var car_view: Node3D
var geometry: Node3D
var known_segments := -1
var geometry_dirty := false
var lighting_fraction := 0.0
var build_request := 0.0
var charge_requests: Dictionary = {}
var light_hubs: Array = []
var auto_feed: Dictionary = {}
var auto_unload: Dictionary = {}
var freight: Node
var infrastructure: Node
var status := "Completed tunnels commission their rail and wired depot stations."
@onready var dig: Node = get_parent().get_node("Excavation")
@onready var territory: Node = get_parent().get_node("Territory")
@onready var inventory: Node = get_parent().get_node("Inventory")
@onready var life: Node = get_parent().get_node("LifeSupport")
func _ready() -> void:
	process_physics_priority = -5
	freight = preload("res://scripts/rail/freight_controller.gd").new()
	freight.name = "Freight"
	add_child(freight)
	infrastructure = preload("res://scripts/infrastructure/infrastructure_condition.gd").new()
	infrastructure.name = "Infrastructure"
	add_child(infrastructure)
	life.energy_step.connect(_grid_step)
	dig.completed.connect(func(_kind: String,_source: int,_target: int): geometry_dirty = true)
	dig.changed.connect(func():
		if geometry_dirty or known_segments!=dig.segments.size(): sync())
	sync()
func _physics_process(_delta: float) -> void:
	if known_segments!=dig.segments.size(): sync()
	freight.advance(_delta)
	for key in auto_feed:
		if not auto_feed[key]: continue
		for pack in stocks[key].cells: feed_pylon(int(key),int(pack.serial))
	for drone in get_parent().get_node("Fleet").get_children():
		var hub := field_hub(drone)
		if hub>0 and auto_unload.get(str(hub),false): unload_drone(drone.identity)
	prepare()
func hub_count() -> int: return dig.segments.size()+1 if not dig.segments.is_empty() else 0
func at(hub: int) -> Vector3:
	var point: Vector3 = territory.pad(hub)
	point.y = Plan.BALANCE.floor_y
	return point
func connected(hub: int) -> bool:
	if not wired(hub): return false
	for i in hub:
		if not infrastructure.rail_ready(i): return false
	return true
func wired(hub: int) -> bool: return infrastructure.wired(hub)
func stock(hub: int) -> Node:
	return inventory if hub==0 and hub_count()>0 else stocks.get(str(hub))
func sync() -> void:
	for i in dig.segments.size(): conditions.get_or_add(str(i),100.0)
	infrastructure.sync()
	for i in range(1,hub_count()):
		if stocks.has(str(i)): continue
		var depot := Stock.new()
		depot.name = "Stock%d" % i
		depot.allocator = inventory
		add_child(depot)
		stocks[str(i)] = depot
		auto_feed.get_or_add(str(i),false)
		auto_unload.get_or_add(str(i),false)
	if geometry!=null:
		remove_child(geometry)
		geometry.queue_free()
	geometry = Node3D.new()
	geometry.name = "RailGeometry"
	add_child(geometry)
	stations.clear()
	for i in dig.segments.size(): Visual.track(geometry,at(i),at(i+1))
	for i in hub_count():
		var point := at(i)
		var height: float = dig.grid.get(Vector2i(floori(point.x),floori(point.z)),2.4)
		stations[i] = Visual.station(geometry,i,point,height)
	car_view = Visual.car(geometry,at(0)) if car_built else null
	freight.update_view()
	known_segments = dig.segments.size()
	geometry_dirty = false
	lighting_fraction = 0
	prepare()
	changed.emit()
func construct_car() -> bool:
	if car_built or car_remaining>0 or hub_count()<2 or not get_parent().get_node("Research").has_technology("excavation"): return false
	if not inventory.spend_scrap(40): return false
	car_remaining = 120.0
	status = "Freight car paid. Assembly needs 120 powered seconds."
	prepare()
	changed.emit()
	return true
func set_charging(enabled: bool) -> void:
	charge_on = enabled
	prepare()
	changed.emit()
func prepare() -> void:
	infrastructure.begin_demand()
	build_request = minf(1.0,car_remaining)
	charge_requests.clear()
	light_hubs.clear()
	for i in hub_count():
		if wired(i): light_hubs.append(i)
		elif stations.has(i): stations[i].get_node("Light").light_energy = 0
	var budget := 1.0/3600.0
	if charge_on and connected(0):
		for pack in inventory.cells:
			var amount: float = minf(budget,1.0-pack.charge)
			if amount<=0: continue
			charge_requests[int(pack.serial)] = amount
			budget -= amount
			if budget<=0: break
	var charging := 0.0
	for amount in charge_requests.values(): charging += amount*3600.0
	var gross: float = build_request*0.6+charging
	for hub in light_hubs: gross += infrastructure.demand(hub,0.02)
	gross += infrastructure.demand(infrastructure.coordinate_hub(freight.coordinate),freight.prepare())
	var passenger: Node = get_parent().get_node_or_null("Passenger")
	if passenger!=null:
		passenger.grid_lamp_requested = passenger.car_load_kw>0 and wired(infrastructure.coordinate_hub(freight.coordinate))
		life.passenger_load_kw = passenger.home_load_kw+infrastructure.demand(infrastructure.coordinate_hub(freight.coordinate),passenger.car_load_kw)
		if not passenger.grid_lamp_requested and car_view!=null and car_view.has_node("PassengerSeat/Headlamp"): car_view.get_node("PassengerSeat/Headlamp").light_energy = 0
	var breaches: Node = get_parent().get_node_or_null("Breaches")
	if breaches!=null:
		breaches.lamp_requests.clear()
		for id in breaches.portals:
			var hub: int = breaches.source_hub(id)
			if wired(hub):
				gross += infrastructure.demand(hub,0.02)
				breaches.lamp_requests.append(id)
			elif breaches.portal_views.has(id): breaches.portal_views[id].lamp.light_energy = 0
	gross += infrastructure.prepare_jobs()+infrastructure.short_demand()
	life.rail_load_kw = gross
func _grid_step(fraction: float) -> void:
	var paid := clampf(fraction,0,1)
	var edges: Dictionary = infrastructure.edge_requests.duplicate()
	var jobs_paid: Dictionary = infrastructure.job_requests.duplicate(true)
	var energized: Array = []
	for edge in dig.segments.size():
		if wired(edge) and infrastructure.wires[str(edge)]>0 and not infrastructure.isolated("wire",edge): energized.append(edge)
	var passenger: Node = get_parent().get_node_or_null("Passenger")
	var lamp_paid: bool = passenger!=null and passenger.grid_lamp_requested
	var breaches: Node = get_parent().get_node_or_null("Breaches")
	var portal_lamps: Array = breaches.lamp_requests.duplicate() if breaches!=null else []
	freight.fund(paid)
	car_remaining = maxf(0,car_remaining-build_request*paid)
	if build_request>0 and car_remaining<=0.000000001:
		car_remaining = 0
		car_built = true
		car_view = Visual.car(geometry,at(0))
		status = "Freight car commissioned."
	for serial in charge_requests:
		var pack: Dictionary = inventory.cell(int(serial))
		if not pack.is_empty(): pack.charge = minf(1.0,pack.charge+charge_requests[serial]*paid)
	lighting_fraction = paid
	for i in stations:
		stations[i].get_node("Light").light_energy = paid*1.8 if i in light_hubs else 0.0
	if not charge_requests.is_empty(): inventory.changed.emit()
	if passenger!=null and passenger.is_node_ready(): passenger._grid_step(paid,lamp_paid)
	if breaches!=null: breaches.light_step(paid,portal_lamps)
	infrastructure.settle(paid,edges,jobs_paid,energized)
	prepare()
	changed.emit()
func feed_pylon(hub: int, serial: int) -> bool:
	if hub<=0 or not wired(hub) or not territory.sites[hub].pylon or territory.sites[hub].condition<=0: return false
	var depot: Node = stock(hub)
	var pack: Dictionary = depot.cell(serial)
	if pack.is_empty(): return false
	var drawn: float = minf(pack.charge,maxf(0,12.0-territory.sites[hub].battery)/0.9)
	if drawn<=0: return false
	pack.charge = maxf(0,pack.charge-drawn)
	territory.sites[hub].battery = minf(12,territory.sites[hub].battery+drawn*0.9)
	depot.notify()
	territory.changed.emit()
	changed.emit()
	return true
func snapshot() -> Dictionary:
	var stores := {}
	for key in stocks: stores[key] = stocks[key].snapshot()
	return {"car_built":car_built,"car_remaining":car_remaining,"charge_on":charge_on,"stocks":stores,"conditions":conditions.duplicate(),"auto_feed":auto_feed.duplicate(),"auto_unload":auto_unload.duplicate(),"freight":freight.snapshot(),"infrastructure":infrastructure.snapshot()}
static func validate(data: Variant, segments: int) -> bool:
	if not data is Dictionary or not data.get("car_built") is bool or not data.get("charge_on") is bool or not Model._range(data.get("car_remaining"),0,120): return false
	if data.car_built and data.car_remaining!=0: return false
	if segments==0 and (data.car_built or data.car_remaining>0): return false
	if not data.get("stocks") is Dictionary or not data.get("conditions") is Dictionary or data.stocks.size()!=segments or data.conditions.size()!=segments: return false
	for i in segments:
		if not Model._range(data.conditions.get(str(i)),0,100) or not Stock.validate(data.stocks.get(str(i+1))): return false
	for feature in ["auto_feed","auto_unload"]:
		if data.has(feature):
			if not data[feature] is Dictionary or data[feature].size()!=segments: return false
			for i in segments:
				if not data[feature].get(str(i+1)) is bool: return false
	return true
static func identities_valid(root: Dictionary, rail: Dictionary) -> bool:
	var parts := {}
	var cells := {}
	var stores: Array = [root]
	stores.append_array(rail.stocks.values())
	if not rail.get("freight",{}).get("job",{}).get("cargo",{}).is_empty(): stores.append(rail.freight.job.cargo)
	for store in stores:
		for part in store.parts:
			if part.serial>=root.next_serial or parts.has(part.serial): return false
			parts[part.serial] = true
		for pack in store.cells:
			if pack.serial>=root.next_cell_serial or cells.has(pack.serial): return false
			cells[pack.serial] = true
	return true
func restore(data: Dictionary) -> void:
	assert(validate(data,dig.segments.size()))
	for depot in stocks.values():
		remove_child(depot)
		depot.queue_free()
	stocks.clear()
	car_built = data.car_built
	car_remaining = data.car_remaining
	charge_on = data.charge_on
	conditions = data.conditions.duplicate()
	auto_feed = data.get("auto_feed",{}).duplicate()
	auto_unload = data.get("auto_unload",{}).duplicate()
	sync()
	for key in data.stocks: stocks[key].restore(data.stocks[key])
	freight.restore(data.get("freight",{"rules":[],"next_serial":1,"last_rule":0,"coordinate":0.0,"credit":0.0,"job":{}}))
	if data.has("infrastructure"): infrastructure.restore(data.infrastructure)
	else: infrastructure.reset()
	prepare()
func field_hub(drone: Node) -> int:
	if drone==null or not drone.deployed or drone.destroyed(): return -1
	for i in range(1,hub_count()):
		if wired(i) and territory.sites[i].fob and territory.sites[i].condition>0 and drone.position.distance_to(territory.pad(i))<=8.0: return i
	return -1
func field_stock(drone: Node) -> Node:
	var hub := field_hub(drone)
	return stock(hub) if hub>0 else null
func unload_drone(id: String) -> int:
	var drone: Node = get_parent().get_node("Fleet").drone(id)
	if field_hub(drone)<1: return 0
	return get_parent().get_node("Salvage").deliver(drone)+get_parent().get_node("Recovery").deliver(drone)
