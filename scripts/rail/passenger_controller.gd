extends Node3D
signal changed
const Access = preload("res://scripts/rail/service_access.gd")
const Inventory = preload("res://scripts/simulation/inventory.gd")
const Platform = preload("res://scenes/rail/platform.tscn")
const Seat = preload("res://scenes/rail/passenger_car.tscn")
var installed := false
var remaining := 0.0
var build_request := 0.0
var lamp_request := false
var grid_lamp_requested := false
var home_load_kw := 0.0
var car_load_kw := 0.0
var phase := "idle"
var goal := 0
var aboard := false
var climb := -1.0
var climb_direction := 1
var access: Node3D
var rail_geometry_id := 0
var status := "Retrofit the car, then use the sealed hatch in life support."
@onready var rail: Node = get_parent().get_node("Rail")
@onready var operator: CharacterBody3D = get_parent().get_node("Operator")
@onready var life: Node = get_parent().get_node("LifeSupport")
func _ready() -> void:
	process_physics_priority = -4
	rail.changed.connect(sync)
	prepare()
func reserved() -> bool: return phase!="idle"
func needs_motion() -> bool: return phase in ["calling","travel"]
func construct() -> bool:
	for job in rail.dig.jobs.values():
		if rail.dig.touches_access(job.plan): return false
	if installed or remaining>0 or not rail.car_built or rail.hub_count()<2 or not rail.inventory.spend_scrap(25): return false
	remaining = 90
	status = "Passenger retrofit paid. Keep the grid supplied for commissioning."
	prepare()
	changed.emit()
	return true
func prepare() -> void:
	build_request = minf(1,remaining)
	lamp_request = installed and aboard
	home_load_kw = build_request*0.6+(0.04 if installed else 0.0)
	car_load_kw = 0.05 if lamp_request else 0.0
	if lamp_request and phase=="travel":
		var lamp: Node3D = rail.car_view.get_node("PassengerSeat/Headlamp")
		var reverse: bool = rail.freight.distance_to_hub(goal)<rail.freight.coordinate
		lamp.position.z = 1.08 if reverse else -1.08
		lamp.rotation = Vector3(deg_to_rad(-10),PI if reverse else 0.0,0)
	if installed and not aboard and rail.car_view!=null: rail.car_view.get_node("PassengerSeat/Headlamp").light_energy = 0
	rail.prepare()
func _grid_step(fraction: float, paid_lamp: bool = false) -> void:
	if installed and rail.car_view!=null: rail.car_view.get_node("PassengerSeat/Headlamp").light_energy = 4.0*clampf(fraction,0,1) if paid_lamp else 0.0
	remaining = maxf(0,remaining-build_request*clampf(fraction,0,1))
	if build_request>0 and remaining<=0.000000001:
		remaining = 0
		installed = true
		sync()
		status = "Passenger retrofit ready. Sealed access is in life support."
	if access!=null: access.light_step(clampf(fraction,0,1))
	prepare()
	changed.emit()
func sync() -> void:
	if not installed: return
	if access==null:
		access = Access.new()
		access.name = "SealedAccess"
		add_child(access)
		rail.dig.rebuild_render_geometry()
	if rail_geometry_id==rail.geometry.get_instance_id(): return
	rail_geometry_id = rail.geometry.get_instance_id()
	for hub in rail.stations:
		var platform := Platform.instantiate()
		platform.passenger = self
		platform.hub = hub
		rail.stations[hub].add_child(platform)
	if rail.car_view!=null and not rail.car_view.has_node("PassengerSeat"):
		rail.car_view.add_child(Seat.instantiate())
func _physics_process(delta: float) -> void:
	if climb>=0: advance_climb(delta)
	if aboard: _sync_rider()
	prepare()
func start_climb(from_top: bool) -> bool:
	var entry := Access.climb_position(0 if from_top else 9)
	if not installed or reserved() or climb>=0 or get_parent().get_node("HumanSortie").active or operator.position.distance_to(entry)>1.6: return false
	climb = 0 if from_top else 9
	climb_direction = 1 if from_top else -1
	operator.transport_locked = true
	operator.velocity = Vector3.ZERO
	InputContext.set_context(InputContext.Context.WALK)
	advance_climb(0)
	return true
func advance_climb(seconds: float) -> void:
	if climb<0 or not is_finite(seconds) or seconds<0: return
	climb = clampf(climb+seconds*0.8*climb_direction,0,9)
	operator.position = Access.climb_position(climb)
	access.set_open(climb<3.7)
	if (climb_direction>0 and climb>=9) or (climb_direction<0 and climb<=0):
		climb = -1
		operator.transport_locked = false
		access.set_open(false)
	changed.emit()
func near_station(hub: int) -> bool:
	if not installed or hub<0 or hub>=rail.hub_count() or absf(operator.position.y-rail.at(hub).y)>0.35: return false
	var control: Node3D = rail.stations[hub].get_node("PassengerPlatform/RideControl")
	var eye: Vector3 = operator.position+Vector3(0,1.55,0)
	if eye.distance_to(control.global_position)>2.5: return false
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,control.global_position,1,[operator.get_rid()]))
	return hit.is_empty() or hit.collider==control
func call_car(hub: int) -> bool:
	if reserved() or climb>=0 or not near_station(hub) or not rail.connected(hub) or get_parent().get_node("HumanSortie").active: return false
	goal = hub
	phase = "calling"
	if rail.freight.job.get("phase")=="source": rail.freight.job = {}
	status = "Car reserved. Loaded freight finishes before the physical approach."
	rail.prepare()
	changed.emit()
	return true
func cancel_call() -> bool:
	if aboard or not reserved() or not near_station(goal): return false
	phase = "idle"
	status = "Passenger call cancelled. Standing freight can resume."
	rail.prepare()
	changed.emit()
	return true
func board() -> bool:
	if phase!="waiting" or not rail.freight.job.is_empty() or not near_station(goal) or get_parent().get_node("HumanSortie").active or absf(rail.freight.coordinate-rail.freight.distance_to_hub(goal))>0.00001: return false
	var seat := seat_position()
	if operator.position.distance_to(seat)>2.5 or not _capsule_clear(seat): return false
	aboard = true
	phase = "arrived"
	status = "Seated. Choose a connected hub, or disembark while stopped."
	operator.transport_locked = true
	operator.velocity = Vector3.ZERO
	_sync_rider()
	prepare()
	InputContext.set_context(InputContext.Context.WALK)
	changed.emit()
	return true
func travel(hub: int) -> bool:
	if not aboard or phase!="arrived" or not rail.connected(hub) or hub==goal: return false
	goal = hub
	phase = "travel"
	status = "Riding underground. Keep the grid supplied; E opens ride controls."
	prepare()
	rail.prepare()
	InputContext.set_context(InputContext.Context.WALK)
	changed.emit()
	return true
func seat_position() -> Vector3:
	return rail.car_view.global_transform*Vector3(0,0.45,0.35)
func _sync_rider() -> void:
	operator.position = seat_position()
	operator.velocity = Vector3.ZERO
func car_rid() -> RID:
	return rail.car_view.get_node("PassengerSeat/CarCollision").get_rid()
func _capsule_clear(at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = operator.get_node("Collision").shape
	query.transform.origin = at+Vector3(0,0.85,0)
	query.collision_mask = operator.collision_mask
	query.exclude = [operator.get_rid(),car_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func safe_exit(hub: int) -> Variant:
	for offset in [Vector3(1.05,0,-1.25),Vector3(-1.05,0,-1.25),Vector3(1.05,0,1.25),Vector3(-1.05,0,1.25)]:
		var at: Vector3 = rail.at(hub)+offset+Vector3(0,0.03,0)
		if not _capsule_clear(at): continue
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3(0,0.1,0),at-Vector3(0,0.2,0),1,[operator.get_rid(),car_rid()]))
		if not hit.is_empty() and hit.normal.y>0.8: return at
	return null
func disembark() -> bool:
	if not aboard or phase!="arrived" or absf(rail.freight.coordinate-rail.freight.distance_to_hub(goal))>0.00001: return false
	var exit: Variant = safe_exit(goal)
	if exit==null:
		status = "Platform occupied. Clear a safe exit before disembarking."
		return false
	operator.position = exit
	operator.transport_locked = false
	operator.velocity = Vector3.ZERO
	aboard = false
	phase = "idle"
	status = "Passenger off the car. Standing freight can resume."
	prepare()
	rail.prepare()
	InputContext.set_context(InputContext.Context.WALK)
	changed.emit()
	return true
func motion_clear(next: float) -> bool:
	if not installed or rail.car_view==null: return true
	var body: Node3D = rail.car_view.get_node("PassengerSeat/CarCollision")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body.get_child(1).shape
	query.transform = body.global_transform
	query.collision_mask = 1
	var exclusions: Array[RID] = [body.get_rid()]
	if aboard: exclusions.append(operator.get_rid())
	query.exclude = exclusions
	query.motion = rail.freight.position_at(next)+Vector3(0,0.15,0)-rail.car_view.position
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	return fractions[0]>=0.99999
func drive(seconds: float) -> void:
	if not needs_motion() or not rail.freight.job.is_empty(): return
	var f: Node = rail.freight
	var target: float = f.distance_to_hub(goal)
	if f.path_ready(f.coordinate,target):
		var move: Dictionary = rail.infrastructure.movement(f.coordinate,target,minf(seconds,f.credit))
		var used: float = move.used
		var next: float = move.next
		if motion_clear(next):
			var yaw: float = rail.car_view.rotation.y
			rail.infrastructure.record_travel(f.coordinate,next,used,80.0)
			f.coordinate = next
			f.credit = maxf(0,f.credit-used)
			f.update_view()
			if aboard: operator.rotate_y(wrapf(rail.car_view.rotation.y-yaw,-PI,PI)); _sync_rider()
	if absf(f.coordinate-target)<=0.000001:
		phase = "arrived" if aboard else "waiting"
		status = "Car stopped. Disembark at a clear platform." if aboard else "Car at platform. Board locally."
		changed.emit()
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo() or not InputContext.allows_look(): return
	if climb>=0:
		climb_direction *= -1
	elif aboard: get_parent().get_node("PassengerPanel").open(goal)
	else: return
	get_viewport().set_input_as_handled()
func snapshot() -> Dictionary:
	return {"installed":installed,"remaining":remaining,"phase":phase,"goal":goal,"aboard":aboard,"climb":climb,"climb_direction":climb_direction}
static func validate(data: Variant, hubs: int, car: bool) -> bool:
	if not data is Dictionary or not data.get("installed") is bool or not data.get("aboard") is bool or not Inventory._number(data.get("remaining")) or data.remaining<0 or data.remaining>90: return false
	if (data.installed and data.remaining>0) or ((data.installed or data.remaining>0) and (not car or hubs<2)): return false
	if data.get("phase") not in ["idle","calling","waiting","travel","arrived"] or not Inventory._integer(data.get("goal"),0,maxi(0,hubs-1)) or not Inventory._number(data.get("climb")) or not (data.climb==-1 or (data.climb>=0 and data.climb<=9)) or not Inventory._integer(data.get("climb_direction"),-1,1) or absf(data.climb_direction)!=1: return false
	if not data.installed and (data.phase!="idle" or data.climb!=-1): return false
	if data.aboard!=(data.phase in ["travel","arrived"]) or (data.climb>=0 and data.phase!="idle"): return false
	return true
func restore(data: Dictionary) -> void:
	assert(validate(data,rail.hub_count(),rail.car_built))
	installed = data.installed
	remaining = data.remaining
	phase = data.phase
	goal = int(data.goal)
	aboard = data.aboard
	climb = data.climb
	climb_direction = int(data.climb_direction)
	status = {"idle":"Passenger retrofit ready. Use the sealed service hatch in life support.","calling":"Car reserved. Loaded freight finishes before its approach.","waiting":"Car at platform. Board locally.","travel":"Riding underground. Keep the grid supplied; E opens ride controls.","arrived":"Car stopped. Disembark at a clear platform."}[phase] if installed else ("Passenger retrofit paid. Commissioning in progress." if remaining>0 else "Retrofit the car, then use the sealed hatch in life support.")
	operator.transport_locked = aboard or climb>=0
	if not installed and access!=null:
		remove_child(access)
		access.queue_free()
		access = null
		var floor: Node = get_parent().get_node("Bunker/LifeSupportFloor")
		floor.show()
		floor.get_node("Collision").disabled = false
		for station in rail.stations.values():
			var platform: Node = station.get_node_or_null("PassengerPlatform")
			if platform!=null: station.remove_child(platform); platform.queue_free()
		if rail.car_view!=null:
			var seat: Node = rail.car_view.get_node_or_null("PassengerSeat")
			if seat!=null: rail.car_view.remove_child(seat); seat.queue_free()
		rail_geometry_id = 0
		rail.dig.rebuild_render_geometry()
	sync()
	if aboard: _sync_rider()
	if climb>=0: advance_climb(0)
	prepare()
	changed.emit()
