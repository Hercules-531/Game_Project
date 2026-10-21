extends Node
const Part = preload("res://scripts/drones/part_condition.gd")
const Inventory = preload("res://scripts/simulation/inventory.gd")
const Job = preload("res://scripts/infrastructure/maintenance_job.gd")
const Work = preload("res://scripts/drones/work_reservations.gd")
var wires: Dictionary = {}
var isolations: Dictionary = {}
var rail_faults: Dictionary = {}
var wire_faults: Dictionary = {}
var cycles: Dictionary = {}
var jobs: Dictionary = {}
var reservations: Dictionary = {}
var edge_requests: Dictionary = {}
var job_requests: Dictionary = {}
var loss_kw := 0.0
var short_kw := 0.0
var rng := RandomNumberGenerator.new()
var status := "Keep rails and conduit serviced; assign a torch hull at the source hub."
@onready var rail: Node = get_parent()
func _ready() -> void: rng.seed = 140539
func sync() -> void:
	for i in rail.dig.segments.size():
		wires.get_or_add(str(i),100.0)
		isolations.get_or_add(str(i),false)
		for kind in ["rail","wire"]: cycles.get_or_add(kind+str(i),0.0)
func isolated(kind: String, edge: int) -> bool: return jobs.has(kind+str(edge)) or (kind=="wire" and isolations.get(str(edge),false))
func toggle_isolation(edge: int) -> bool:
	if edge<0 or edge>=rail.dig.segments.size() or not wired(edge): return false
	isolations[str(edge)] = not isolations[str(edge)]
	status = "Conduit isolated at its source port." if isolations[str(edge)] else "Conduit reconnected at its source port."
	rail.prepare()
	rail.changed.emit()
	return true
func wire_ready(edge: int) -> bool:
	return wires.get(str(edge),100.0)>0 and wire_faults.get(str(edge),0.0)<=0 and not isolated("wire",edge)
func rail_ready(edge: int) -> bool:
	return rail.conditions.get(str(edge),100.0)>0 and rail_faults.get(str(edge),0.0)<=0 and not isolated("rail",edge)
func wired(hub: int) -> bool:
	if hub<0 or hub>=rail.hub_count(): return false
	for i in hub:
		if not wire_ready(i): return false
	return true
func coordinate_hub(coordinate: float) -> int:
	for i in rail.dig.segments.size():
		if coordinate<=rail.freight.distance_to_hub(i+1)+0.000001: return 0 if coordinate<=0.000001 else i+1
	return maxi(0,rail.hub_count()-1)
func begin_demand() -> void:
	edge_requests.clear()
	job_requests.clear()
	loss_kw = 0
	short_kw = 0
func demand(hub: int, useful_kw: float) -> float:
	if useful_kw<=0 or not wired(hub): return 0
	var flow := useful_kw
	for edge in range(hub-1,-1,-1):
		flow /= Part.efficiency(wires[str(edge)])/1.2
		edge_requests[str(edge)] = edge_requests.get(str(edge),0.0)+flow
	loss_kw += flow-useful_kw
	return flow
func short_demand() -> float:
	var gross := 0.0
	for key in wire_faults:
		var edge := int(key)
		if wire_faults[key]<=0 or wires[key]<=0 or isolated("wire",edge) or not wired(edge): continue
		gross += demand(edge,2.0)
		edge_requests[key] = edge_requests.get(key,0.0)+2.0
		short_kw += 2.0
	return gross
func condition(kind: String, edge: int) -> float:
	return rail.conditions.get(str(edge),100.0) if kind=="rail" else wires.get(str(edge),100.0)
func faults(kind: String) -> Dictionary: return rail_faults if kind=="rail" else wire_faults
func length(edge: int) -> float: return rail.at(edge).distance_to(rail.at(edge+1))
func busy(id: String) -> bool:
	for job in jobs.values():
		if job.worker==id: return true
	return false
func controls(id: String) -> bool: return reservations.get(id,false)
func worker_ready(d: Node, edge: int) -> bool:
	if d==null or d.destroyed() or not d.has_power() or d.module_efficiency("torch")<=0 or not wired(edge): return false
	if edge==0:
		return (not d.deployed and d.position.distance_to(Vector3(-4.3,0.02,1))<=5) or (d.deployed and d.position.distance_to(rail.territory.pad(0))<=8)
	return d.deployed and rail.territory.sites[edge].fob and rail.territory.sites[edge].condition>0 and d.position.distance_to(rail.territory.pad(edge))<=8
func prepare_jobs() -> float:
	var gross := 0.0
	reservations.clear()
	for key in jobs.keys():
		var job: Dictionary = jobs[key]
		var d: Node = rail.get_parent().get_node("Fleet").drone(job.worker)
		if d==null or d.destroyed():
			jobs.erase(key)
			_release(job.worker)
			status = "Maintenance hull lost. Assignment abandoned without refund."
			continue
		var active := worker_ready(d,int(job.edge))
		reservations[d.identity] = active
		d.work_noise = 0.75 if active else 0.0
		d.get_node("Controller").available = not active
		if not active: continue
		d.get_node("Controller").stop()
		var seconds: float = minf(1.0,job.remaining/d.module_efficiency("torch"))
		if not d.hull().external_power and not rail.get_parent().get_node("Orders").field_powered(d.identity):
			var draw: float = rail.get_parent().get_node("DronePower").required_kw(d)
			if draw>0: seconds = minf(seconds,d.battery*3600.0/draw)
		job_requests[key] = {"seconds":seconds,"efficiency":d.module_efficiency("torch")}
		gross += demand(int(job.edge),seconds)
	return gross
func request(kind: String, edge: int, worker: String) -> bool:
	if kind not in ["rail","wire"] or edge<0 or edge>=rail.dig.segments.size(): return false
	var key := kind+str(edge)
	var d: Node = rail.get_parent().get_node("Fleet").drone(worker)
	if jobs.has(key) or jobs.size()>=10 or Work.busy(rail.get_parent(),worker):
		status = "The component or selected hull is already assigned."
		return false
	if not worker_ready(d,edge) or not d.get_node("Controller").available:
		status = "Needs a powered torch hull at the source bay or FOB, with healthy upstream wire."
		return false
	if rail.territory.job.get("id","")==worker or rail.get_parent().get_node("FleetControl").transfer.get("id","")==worker: return false
	var value := condition(kind,edge)
	var fault: bool = faults(kind).get(str(edge),0.0)>0
	var quote := Job.quote(value,fault,length(edge))
	if quote.scrap<=0:
		status = "Component already serviced."
		return false
	if not rail.stock(edge).spend_scrap(quote.scrap):
		status = "Insufficient scrap in this source hub's store."
		return false
	jobs[key] = {"kind":kind,"edge":edge,"worker":worker,"condition":value,"fault":fault,"scrap":quote.scrap,"seconds":quote.seconds,"remaining":quote.seconds}
	status = "Maintenance paid. Keep the source wired and its torch hull supplied."
	rail.prepare()
	rail.changed.emit()
	return true
func _release(id: String) -> void:
	reservations.erase(id)
	var d: Node = rail.get_parent().get_node("Fleet").drone(id)
	if d!=null:
		d.work_noise = 0
		d.get_node("Controller").available = true
func cancel(kind: String, edge: int) -> bool:
	var key := kind+str(edge)
	if not jobs.has(key): return false
	var worker: String = jobs[key].worker
	var d: Node = rail.get_parent().get_node("Fleet").drone(worker)
	if d!=null and not d.destroyed() and not wired(edge) and rail.get_parent().get_node("Radio").quality(d)<=0: return false
	jobs.erase(key)
	_release(worker)
	status = "Maintenance cancelled; paid materials are not refunded."
	rail.prepare()
	rail.changed.emit()
	return true
func cycle(kind: String, edge: int, seconds: float) -> void:
	var key := kind+str(edge)
	cycles[key] = cycles.get(key,0.0)+seconds
	while cycles[key]>=60.0-0.000000001:
		cycles[key] = maxf(0,cycles[key]-60.0)
		if condition(kind,edge)>0 and faults(kind).get(str(edge),0.0)<=0 and rng.randf()<Part.malfunction_chance(condition(kind,edge)): faults(kind)[str(edge)] = 8.0
func settle(fraction: float, requested_edges: Dictionary, requested_jobs: Dictionary, energized: Array) -> void:
	for timers in [rail_faults,wire_faults]:
		for key in timers.keys():
			timers[key] = maxf(0,timers[key]-1.0)
			if timers[key]<=0: timers.erase(key)
	var paid := clampf(fraction,0,1)
	for edge in energized:
		var key := str(edge)
		wires[key] = maxf(0,wires[key]-0.00025*paid-requested_edges.get(key,0.0)*paid/3600.0*0.5)
		cycle("wire",edge,paid)
	for key in requested_jobs:
		if not jobs.has(key): continue
		var job: Dictionary = jobs[key]
		job.remaining = maxf(0,job.remaining-requested_jobs[key].seconds*requested_jobs[key].efficiency*paid)
		if job.remaining>0.000000001: continue
		if job.kind=="rail": rail.conditions[str(int(job.edge))] = 100.0
		else: wires[str(int(job.edge))] = 100.0
		faults(job.kind).erase(str(int(job.edge)))
		cycles[key] = 0.0
		jobs.erase(key)
		_release(job.worker)
		status = "Maintenance complete. Component restored to 100%."
func movement(from: float, to: float, seconds: float) -> Dictionary:
	if seconds<=0 or not wired(coordinate_hub(maxf(from,to))): return {"next":from,"used":0.0}
	var direction := signf(to-from)
	for edge in rail.dig.segments.size():
		var start: float = rail.freight.distance_to_hub(edge)
		var end: float = rail.freight.distance_to_hub(edge+1)
		if (direction>0 and (from<start-0.000001 or from>=end-0.000001)) or (direction<0 and (from<=start+0.000001 or from>end+0.000001)): continue
		if not rail_ready(edge): return {"next":from,"used":0.0}
		var speed := 2.0*Part.efficiency(condition("rail",edge))/1.2
		var boundary: float = minf(to,end) if direction>0 else maxf(to,start)
		var used := minf(seconds,absf(boundary-from)/speed)
		return {"next":move_toward(from,boundary,used*speed),"used":used}
	return {"next":from,"used":0.0}
func record_travel(from: float, to: float, seconds: float, payload: float) -> void:
	var distance := absf(to-from)
	if distance<=0: return
	for edge in rail.dig.segments.size():
		var low: float = rail.freight.distance_to_hub(edge)
		var high: float = rail.freight.distance_to_hub(edge+1)
		var travelled := maxf(0,minf(maxf(from,to),high)-maxf(minf(from,to),low))
		if travelled<=0: continue
		rail.conditions[str(edge)] = maxf(0,rail.conditions[str(edge)]-travelled*0.001*(1.0+payload/200.0))
		cycle("rail",edge,seconds*travelled/distance)
func snapshot() -> Dictionary:
	return {"wires":wires.duplicate(),"isolations":isolations.duplicate(),"rail_faults":rail_faults.duplicate(),"wire_faults":wire_faults.duplicate(),"cycles":cycles.duplicate(),"jobs":jobs.duplicate(true),"rng":str(rng.state)}
static func validate(data: Variant, segments: Array) -> bool:
	if not data is Dictionary or not data.get("rng") is String or not data.rng.is_valid_int(): return false
	for field in ["wires","isolations","rail_faults","wire_faults","cycles","jobs"]:
		if not data.get(field) is Dictionary: return false
	if data.wires.size()!=segments.size() or data.isolations.size()!=segments.size() or data.cycles.size()!=segments.size()*2 or data.jobs.size()>10: return false
	for i in segments.size():
		if not Inventory._number(data.wires.get(str(i))) or data.wires[str(i)]<0 or data.wires[str(i)]>100: return false
		if not data.isolations.get(str(i)) is bool: return false
		for kind in ["rail","wire"]:
			var clock: Variant = data.cycles.get(kind+str(i))
			if not Inventory._number(clock) or clock<0 or clock>=60: return false
	for field in ["rail_faults","wire_faults"]:
		for key in data[field]:
			if not key is String or str(int(key))!=key or int(key)<0 or int(key)>=segments.size() or not Inventory._number(data[field][key]) or data[field][key]<=0 or data[field][key]>8: return false
	var workers := {}
	for key in data.jobs:
		var job: Variant = data.jobs[key]
		if not job is Dictionary or not Inventory._integer(job.get("edge"),0,segments.size()-1): return false
		var length: float = preload("res://scripts/world/territory_network.gd").pad(int(job.edge)).distance_to(preload("res://scripts/world/territory_network.gd").pad(int(job.edge)+1))
		if not Job.valid(job,length) or key!=job.kind+str(int(job.edge)) or workers.has(job.worker): return false
		workers[job.worker] = true
	return true
func restore(data: Dictionary) -> void:
	assert(validate(data,rail.dig.segments))
	for job in jobs.values(): _release(job.worker)
	wires = data.wires.duplicate()
	isolations = data.isolations.duplicate()
	rail_faults = data.rail_faults.duplicate()
	wire_faults = data.wire_faults.duplicate()
	cycles = data.cycles.duplicate()
	jobs = data.jobs.duplicate(true)
	for job in jobs.values(): job.edge = int(job.edge)
	rng.state = data.rng.to_int()
	begin_demand()
func reset() -> void:
	for job in jobs.values(): _release(job.worker)
	wires.clear()
	isolations.clear()
	rail_faults.clear()
	wire_faults.clear()
	cycles.clear()
	jobs.clear()
	reservations.clear()
	rng.seed = 140539
	sync()
	begin_demand()
