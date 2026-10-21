extends Node
## One physical car. Cargo identities move between stores; paid motion is finite.
const Inventory = preload("res://scripts/simulation/inventory.gd")
const Model = preload("res://scripts/drones/drone.gd")
const Network = preload("res://scripts/world/territory_network.gd")
const KINDS = ["scrap","rations","fuel","part","charged","empty"]
var rules: Array = []
var next_serial := 1
var last_rule := 0
var coordinate := 0.0
var credit := 0.0
var request := 0.0
var job: Dictionary = {}
@onready var rail: Node = get_parent()
func distance_to_hub(hub: int) -> float:
	var result := 0.0
	for i in hub: result += rail.at(i).distance_to(rail.at(i+1))
	return result
func position_at(value: float) -> Vector3:
	return route_point(rail.dig.segments,value)
static func route_point(segments: Array, value: float) -> Vector3:
	for i in segments.size():
		var a := Network.pad(i)
		var b := Network.pad(i+1)
		a.y = -6
		b.y = -6
		var length := a.distance_to(b)
		if value<=length: return a.lerp(b,clampf(value/length,0,1))
		value -= length
	var end := Network.pad(segments.size())
	end.y = -6
	return end
func add_rule(source: int, target: int, kind: String, minimum: int, batch: int, module: String = "") -> bool:
	var rule := {"serial":next_serial,"source":source,"target":target,"kind":kind,"minimum":minimum,"batch":batch,"module":module,"enabled":true}
	if rules.size()>=32 or next_serial>=1000000 or not valid_rule(rule,rail.hub_count()): return false
	rules.append(rule)
	next_serial += 1
	rail.changed.emit()
	return true
func toggle_rule(serial: int) -> bool:
	for rule in rules:
		if int(rule.serial)==serial:
			rule.enabled = not rule.enabled
			if not rule.enabled and job.get("serial",-1)==serial and job.get("phase")=="source": job = {}
			rail.changed.emit()
			return true
	return false
static func valid_rule(rule: Variant, hubs: int) -> bool:
	if not rule is Dictionary or rule.get("kind") not in KINDS or not rule.get("enabled") is bool: return false
	for key in ["source","target"]:
		if not Inventory._integer(rule.get(key),0,hubs-1): return false
	if rule.source==rule.target or not Inventory._integer(rule.get("serial"),1,999999) or not Inventory._integer(rule.get("minimum"),1,1000000) or not Inventory._integer(rule.get("batch"),1,200): return false
	return rule.get("module") is String and ((rule.kind=="part" and Inventory.CATALOG.module(rule.module)!=null) or (rule.kind!="part" and rule.module==""))
static func matching(pack: Dictionary, kind: String) -> bool:
	return pack.charge>=0.99 if kind=="charged" else pack.charge<=0.000000001
func count_at(hub: int, rule: Dictionary) -> float:
	var depot: Node = rail.stock(hub)
	if depot==null: return 0
	if rule.kind in ["scrap","rations","fuel"]: return float(depot.get(rule.kind))
	var count := 0
	if rule.kind=="part":
		for part in depot.parts:
			if part.id==rule.module: count += 1
	else:
		for pack in depot.cells:
			if matching(pack,rule.kind): count += 1
	return count
func target_coordinate() -> float:
	var passenger: Node = rail.get_parent().get_node_or_null("Passenger")
	if job.is_empty() and passenger!=null and passenger.needs_motion(): return distance_to_hub(passenger.goal)
	return distance_to_hub(int(job.source if job.phase=="source" else job.target)) if not job.is_empty() else coordinate
func path_ready(a: float, b: float) -> bool:
	var start := 0.0
	for i in rail.dig.segments.size():
		var end := distance_to_hub(i+1)
		if maxf(a,b)>start+0.000001 and minf(a,b)<end-0.000001 and rail.conditions.get(str(i),100.0)<=0: return false
		start = end
	return true
func dispatch() -> void:
	if not job.is_empty() or not rail.car_built: return
	var passenger: Node = rail.get_parent().get_node_or_null("Passenger")
	if passenger!=null and passenger.reserved(): return
	# Rotate accepted rules so a continuously hungry depot cannot starve the rest.
	var ordered: Array = rules.filter(func(rule: Dictionary): return rule.serial>last_rule)
	ordered.append_array(rules.filter(func(rule: Dictionary): return rule.serial<=last_rule))
	for rule in ordered:
		if not rule.enabled or not rail.connected(int(rule.source)) or not rail.connected(int(rule.target)): continue
		if count_at(int(rule.target),rule)>=rule.minimum or count_at(int(rule.source),rule)<1: continue
		job = rule.duplicate(true)
		job.phase = "source"
		job.cargo = {}
		last_rule = int(rule.serial)
		return
func prepare() -> float:
	request = maxf(0,1.0-credit) if rail.car_built and absf(target_coordinate()-coordinate)>0.000001 and path_ready(coordinate,target_coordinate()) else 0.0
	return request*1.5
func fund(fraction: float) -> void:
	credit = minf(1,credit+request*clampf(fraction,0,1))
func _notify(depot: Node) -> void:
	if depot==rail.inventory: depot.changed.emit()
	else: depot.notify()
func _load() -> bool:
	var source: Node = rail.stock(int(job.source))
	var quantity := mini(int(job.batch),maxi(0,ceili(job.minimum-count_at(int(job.target),job))))
	var cargo := {"kind":job.kind,"module":job.module,"amount":0.0,"parts":[],"cells":[]}
	if job.kind in ["scrap","rations","fuel"]:
		cargo.amount = float(mini(quantity,mini(200,floori(float(source.get(job.kind))))))
		if cargo.amount<=0: return false
		source.set(job.kind,source.get(job.kind)-int(cargo.amount) if job.kind=="scrap" else source.get(job.kind)-cargo.amount)
	else:
		var mass := 0.0
		var items: Array = source.parts if job.kind=="part" else source.cells
		var selected: Array = cargo.parts if job.kind=="part" else cargo.cells
		for item in items.duplicate():
			var wanted: bool = item.id==job.module if job.kind=="part" else matching(item,job.kind)
			var weight: float = Inventory.CATALOG.module(item.id).mass_kg if job.kind=="part" else 10.0
			if not wanted or selected.size()>=quantity or mass+weight>200: continue
			selected.append(item)
			items.erase(item)
			mass += weight
		if selected.is_empty(): return false
	job.cargo = cargo
	job.phase = "delivery"
	_notify(source)
	return true
func _unload() -> bool:
	var target: Node = rail.stock(int(job.target))
	var cargo: Dictionary = job.cargo
	if cargo.kind in ["scrap","rations","fuel"]:
		if float(target.get(cargo.kind))+cargo.amount>1000000: return false
		target.set(cargo.kind,target.get(cargo.kind)+int(cargo.amount) if cargo.kind=="scrap" else target.get(cargo.kind)+cargo.amount)
	else:
		var items: Array = target.parts if cargo.kind=="part" else target.cells
		var loaded: Array = cargo.parts if cargo.kind=="part" else cargo.cells
		if items.size()+loaded.size()>(2000 if cargo.kind=="part" else 128): return false
		items.append_array(loaded)
	job = {}
	_notify(target)
	rail.changed.emit()
	return true
func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds<=0 or not rail.car_built: return
	var passenger: Node = rail.get_parent().get_node_or_null("Passenger")
	if job.is_empty() and passenger!=null and passenger.reserved(): passenger.drive(seconds); return
	var available := minf(seconds,credit)
	for _event in 4:
		dispatch()
		if job.is_empty(): break
		var destination := target_coordinate()
		if absf(destination-coordinate)<=0.000001:
			coordinate = destination
			if job.phase=="source":
				if not _load(): job = {}; continue
			else:
				if not _unload(): break
			continue
		if available<=0 or not path_ready(coordinate,destination): break
		var used := minf(available,absf(destination-coordinate)/2.0)
		var next := move_toward(coordinate,destination,used*2.0)
		if passenger!=null and not passenger.motion_clear(next): break
		coordinate = next
		available -= used
		credit = maxf(0,credit-used)
	update_view()
func update_view() -> void:
	if rail.car_view==null: return
	rail.car_view.position = position_at(coordinate)+Vector3(0,0.15,0)
	var ahead := position_at(minf(distance_to_hub(maxi(0,rail.hub_count()-1)),coordinate+0.01))-position_at(maxf(0,coordinate-0.01))
	if ahead.length_squared()>0.00000001: rail.car_view.rotation.y = atan2(-ahead.x,-ahead.z)
func snapshot() -> Dictionary:
	return {"rules":rules.duplicate(true),"next_serial":next_serial,"last_rule":last_rule,"coordinate":coordinate,"credit":credit,"job":job.duplicate(true)}
static func validate(data: Variant, segments: Array, built: bool) -> bool:
	if not data is Dictionary or not data.get("rules") is Array or data.rules.size()>32 or not data.get("job") is Dictionary or not Inventory._integer(data.get("next_serial"),1,1000000) or not Inventory._integer(data.get("last_rule"),0,int(data.next_serial)-1) or not Model._range(data.get("credit"),0,1): return false
	var total := 0.0
	for plan in segments: total += preload("res://scripts/world/territory_network.gd").pad(int(plan.source)).distance_to(preload("res://scripts/world/territory_network.gd").pad(int(plan.target)))
	if not Model._range(data.get("coordinate"),0,total) or (not built and (data.coordinate!=0 or data.credit!=0 or not data.job.is_empty())): return false
	var seen := {}
	for rule in data.rules:
		if not valid_rule(rule,segments.size()+1 if not segments.is_empty() else 0) or rule.serial>=data.next_serial or seen.has(rule.serial): return false
		seen[rule.serial] = true
	if data.job.is_empty(): return true
	var job: Dictionary = data.job
	if not valid_rule(job,segments.size()+1) or not seen.has(job.serial) or job.get("phase") not in ["source","delivery"] or not job.get("cargo") is Dictionary: return false
	if job.phase=="source": return job.cargo.is_empty()
	var cargo: Dictionary = job.cargo
	if cargo.get("kind")!=job.kind or cargo.get("module")!=job.module or not Model._range(cargo.get("amount"),0,200) or not cargo.get("parts") is Array or not Inventory.validate_cells(cargo.get("cells")): return false
	if not Inventory.validate({"scrap":0,"fuel":0.0,"rations":0.0,"parts":cargo.parts,"cells":cargo.cells,"hulls":{},"next_serial":10000000,"next_cell_serial":10000000}): return false
	var mass: float = cargo.amount
	var count: float = cargo.amount
	if cargo.kind in ["scrap","rations","fuel"]:
		if not cargo.parts.is_empty() or not cargo.cells.is_empty() or cargo.amount<=0 or cargo.amount!=int(cargo.amount): return false
	elif cargo.kind=="part":
		if cargo.amount!=0 or not cargo.cells.is_empty() or cargo.parts.is_empty(): return false
		for part in cargo.parts:
			if part.id!=job.module: return false
			mass += Inventory.CATALOG.module(part.id).mass_kg
		count = cargo.parts.size()
	else:
		if cargo.amount!=0 or not cargo.parts.is_empty() or cargo.cells.is_empty(): return false
		for pack in cargo.cells:
			if not matching(pack,cargo.kind): return false
		mass = cargo.cells.size()*10.0
		count = cargo.cells.size()
	return mass<=200 and count<=job.batch
func restore(data: Dictionary) -> void:
	assert(validate(data,rail.dig.segments,rail.car_built))
	rules = data.rules.duplicate(true)
	next_serial = int(data.next_serial)
	last_rule = int(data.last_rule)
	coordinate = data.coordinate
	credit = data.credit
	job = data.job.duplicate(true)
	request = 0
	update_view()
