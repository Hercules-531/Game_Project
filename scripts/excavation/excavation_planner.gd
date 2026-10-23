extends Node3D
signal changed
signal completed(kind: String, source: int, target: int)
const Plan = preload("res://scripts/excavation/excavation_plan.gd")
const Model = preload("res://scripts/drones/drone.gd")
const Access = preload("res://scripts/rail/service_access.gd")
var segments: Array = []
var rooms: Dictionary = {}
var jobs: Dictionary = {}
var next_serial := 1
var grid: Dictionary = {}
var reservations: Dictionary = {}
var geometry: Node3D
var status := "Mark a route or room on ground already held. Assign a powered drill hull."
@onready var fleet: Node = get_parent().get_node("Fleet")
@onready var territory: Node = get_parent().get_node("Territory")
@onready var tether: Node = get_parent().get_node("PowerTether")
func _ready() -> void:
	process_physics_priority = -40
	geometry = preload("res://scripts/excavation/excavation_geometry.gd").new()
	geometry.name = "Underground"
	add_child(geometry)
	var tick := preload("res://scripts/excavation/excavation_tick.gd").new()
	tick.name = "PaidWork"
	add_child(tick)
func busy(id: String) -> bool:
	for job in jobs.values():
		if job.worker==id: return true
	return false
func controls(id: String) -> bool: return reservations.get(id,false)
func held(band: int) -> bool:
	if band<0 or band>=6 or not territory.sites[band].held: return false
	if band==0: return true
	var site: Dictionary = territory.sites[band]
	if site.pylon and site.condition>0: return true
	var relay: Node = territory.relay_body(band)
	return relay!=null and not relay.destroyed() and relay.deployed and relay.module_efficiency("high_gain_dish")>0 and relay.position.distance_to(territory.pad(band))<=6
func _worker_ready(d: Node, plan: Dictionary, powered: bool = true) -> bool:
	if d==null or not d.deployed or d.destroyed() or d.component_efficiency("cell")<=0 or d.module_efficiency("drill")<=0: return false
	if d.position.distance_to(territory.pad(int(plan.source))+Vector3(-4,0,-4))>3: return false
	if not held(int(plan.source)) or not held(int(plan.target)): return false
	return not powered or d.has_power()
func preview(plan: Dictionary) -> Dictionary:
	if not Plan.expansion(plan,segments,rooms) or not held(int(plan.source)) or not held(int(plan.target)): return {}
	var breaches: Node = get_parent().get_node_or_null("Breaches")
	return Plan.quote(plan,work_grid(),breaches.cleared_ranges() if breaches!=null else {})
func work_grid() -> Dictionary:
	var passenger: Node = get_parent().get_node_or_null("Passenger")
	return Access.corridor(grid) if passenger!=null and passenger.installed else grid
func request(worker: String, kind: String, source: int, target: int, width: float, depth: float, height: float) -> bool:
	var plan := {"kind":kind,"source":source,"target":target,"width":width,"depth":6.0 if kind=="tunnel" else depth,"height":height}
	var quote := preview(plan)
	var d: Node = fleet.drone(worker)
	if preload("res://scripts/drones/work_reservations.gd").busy(get_parent(),worker): return false
	var passenger: Node = get_parent().get_node_or_null("Passenger")
	if passenger!=null and passenger.remaining>0 and touches_access(plan):
		status = "Home access is being commissioned. Wait before assigning overlapping excavation."
		return false
	if jobs.size()>=32 or next_serial>=1000000 or busy(worker) or quote.is_empty() or not get_parent().get_node("Research").has_technology("excavation") or not _worker_ready(d,plan) or not d.get_node("Controller").available or get_parent().get_node("Radio").quality(d)<=0:
		status = "Needs earned adjacent hubs, an available drill hull at staging, power and link."
		return false
	if territory.job.get("id","")==worker or get_parent().get_node("FleetControl").transfer.get("id","")==worker: return false
	var area := Plan.cells(plan)
	for job in jobs.values():
		var other := Plan.cells(job.plan)
		for cell in area:
			if other.has(cell):
				status = "Another assignment occupies that footprint."
				return false
	if not get_parent().get_node("Inventory").spend_scrap(quote.scrap):
		status = "Insufficient scrap for the marked excavation."
		return false
	var id := "dig_%06d" % next_serial
	jobs[id] = {"serial":next_serial,"worker":worker,"plan":plan,"seconds":quote.seconds,"remaining":quote.seconds,"scrap":quote.scrap}
	next_serial += 1
	tether.work_supply.discard(worker)
	territory.work_supply.discard(worker)
	reservations[worker] = true
	d.work_noise = 4
	d.get_node("Controller").stop()
	d.get_node("Controller").available = false
	status = "Assignment paid. Keep the drill hull supplied and its worksite linked."
	changed.emit()
	return true
func _release(worker: String) -> void:
	reservations.erase(worker)
	tether.work_supply.discard(worker)
	territory.work_supply.discard(worker)
	var d: Node = fleet.drone(worker)
	if d!=null:
		d.work_noise = 0
		d.get_node("Controller").available = true
func cancel(worker: String) -> bool:
	var d: Node = fleet.drone(worker)
	if d==null: return false
	if not d.destroyed() and get_parent().get_node("Radio").quality(d)<=0 and d.position.distance_to(Vector3(0,0.02,-14))>8: return false
	for id in jobs.keys():
		if jobs[id].worker!=worker: continue
		jobs.erase(id)
		_release(worker)
		status = "Assignment cancelled; spent scrap and work are not refunded."
		changed.emit()
		return true
	return false
func _physics_process(_delta: float) -> void: prepare()
func prepare() -> void:
	for id in jobs.keys():
		var job: Dictionary = jobs[id]
		var d: Node = fleet.drone(job.worker)
		if d==null or d.destroyed():
			jobs.erase(id)
			_release(job.worker)
			status = "Drill hull lost. Unfinished excavation was abandoned."
			changed.emit()
			continue
		var linked: bool = get_parent().get_node("Radio").quality(d)>0 or get_parent().get_node("Orders").field_powered(d.identity)
		var active: bool = linked and _worker_ready(d,job.plan)
		reservations[d.identity] = active
		d.work_noise = 4.0 if active else 0.0
		d.get_node("Controller").available = not active
		if active: d.get_node("Controller").stop()
func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds<=0: return
	var rebuild := false
	for id in jobs.keys():
		var job: Dictionary = jobs[id]
		var d: Node = fleet.drone(job.worker)
		if not _worker_ready(d,job.plan,false): continue
		var paid: Dictionary
		if get_parent().get_node("Orders").field_powered(d.identity):
			paid = {"seconds":seconds,"linked":true}
		else:
			paid = tether.work_supply.consume(d.identity,seconds)
			if paid.seconds<=0: paid = territory.work_supply.consume(d.identity,seconds)
		if not paid.linked or paid.seconds<=0: continue
		job.remaining = maxf(0,job.remaining-paid.seconds*d.module_efficiency("drill"))
		var breaches: Node = get_parent().get_node_or_null("Breaches")
		if breaches!=null: breaches.record_drill(job,paid.seconds)
		if job.remaining>0.000001: continue
		var plan: Dictionary = job.plan
		if plan.kind=="tunnel":
			if int(plan.source)==segments.size(): segments.append(plan.duplicate())
			else: segments[int(plan.source)] = plan.duplicate()
		else: rooms[str(int(plan.source))] = plan.duplicate()
		jobs.erase(id)
		_release(d.identity)
		rebuild = true
		status = "Excavation complete. Finished space added to the underground plan."
		completed.emit(plan.kind,int(plan.source),int(plan.target))
	if rebuild:
		grid = Plan.grid(segments,rooms)
		rebuild_render_geometry()
	changed.emit()
func snapshot() -> Dictionary:
	return {"segments":segments.duplicate(true),"rooms":rooms.duplicate(true),"jobs":jobs.duplicate(true),"next_serial":next_serial}
static func touches_access(plan: Dictionary) -> bool:
	if not Plan.valid(plan): return false
	var access := Access.corridor({})
	for cell in Plan.cells(plan):
		if access.has(cell): return true
	return false
static func validate(data: Variant, passenger_access: bool = false, portal_ranges: Dictionary = {}, check_quote: bool = true) -> bool:
	if not data is Dictionary or not data.get("segments") is Array or data.segments.size()>5 or not data.get("rooms") is Dictionary or data.rooms.size()>6 or not data.get("jobs") is Dictionary or data.jobs.size()>32 or not Model._range(data.get("next_serial"),1,1000000) or data.next_serial!=int(data.next_serial): return false
	for i in data.segments.size():
		var plan: Variant = data.segments[i]
		if not Plan.valid(plan) or plan.kind!="tunnel" or int(plan.source)!=i: return false
	for key in data.rooms:
		var plan: Variant = data.rooms[key]
		if not key is String or not key.is_valid_int() or str(int(key))!=key or not Plan.valid(plan) or plan.kind!="room" or str(int(plan.source))!=key or not Plan.reachable(int(plan.source),data.segments): return false
	var existing := Plan.grid(data.segments,data.rooms)
	if passenger_access: existing = Access.corridor(existing)
	var workers := {}
	var occupied := {}
	for id in data.jobs:
		var job: Variant = data.jobs[id]
		if not id is String or not job is Dictionary or not Model._range(job.get("serial"),1,data.next_serial-1) or job.serial!=int(job.serial) or id!="dig_%06d" % int(job.serial) or not job.get("worker") is String or job.worker.is_empty() or job.worker.length()>80 or workers.has(job.worker): return false
		if not Plan.valid(job.get("plan")) or not Plan.expansion(job.plan,data.segments,data.rooms): return false
		if job.has("noise_clock") and (not Model._range(job.noise_clock,0,5) or job.noise_clock>=5): return false
		var quote := Plan.quote(job.plan,existing,portal_ranges)
		if not Model._range(job.get("seconds"),Plan.BALANCE.minimum_seconds,1000000) or not Model._range(job.get("remaining"),0.000001,job.seconds): return false
		if check_quote and not _matches_quote(job,quote):
			# Work paid before service chases were commissioned keeps its original
			# price and duration. New requests always use the cleared-volume quote.
			if portal_ranges.is_empty() or not _matches_quote(job,Plan.quote(job.plan,existing)): return false
		workers[job.worker] = true
		var area := Plan.cells(job.plan)
		for cell in area:
			if occupied.has(cell): return false
			occupied[cell] = true
	return true
static func _matches_quote(job: Dictionary, quote: Dictionary) -> bool:
	return not quote.is_empty() and absf(job.seconds-quote.seconds)<=0.00001 and job.get("scrap")==quote.scrap
func restore(data: Dictionary, portal_ranges: Dictionary = {}) -> void:
	# Schema checks the saved baseline before the retrofit is restored.
	assert(validate(data,false,portal_ranges) or validate(data,true,portal_ranges))
	for job in jobs.values(): _release(job.worker)
	segments = data.segments.duplicate(true)
	rooms = data.rooms.duplicate(true)
	jobs = data.jobs.duplicate(true)
	next_serial = int(data.next_serial)
	for job in jobs.values():
		tether.work_supply.discard(job.worker)
		territory.work_supply.discard(job.worker)
	grid = Plan.grid(segments,rooms)
	rebuild_render_geometry()
	prepare()
	changed.emit()

func rebuild_render_geometry() -> void:
	var passenger: Node = get_parent().get_node_or_null("Passenger")
	var breaches: Node = get_parent().get_node_or_null("Breaches")
	var cuts: Dictionary = breaches.portal_cells() if breaches!=null else {}
	if passenger!=null and passenger.installed:
		var access = preload("res://scripts/rail/service_access.gd")
		geometry.rebuild(access.corridor(grid),access.roof_holes(),cuts)
	else: geometry.rebuild(grid,{},cuts)
