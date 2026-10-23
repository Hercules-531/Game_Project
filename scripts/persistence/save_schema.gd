extends RefCounted

const VERSION := 35
const Breaches = preload("res://scripts/threats/breach_system.gd")
const Infrastructure = preload("res://scripts/infrastructure/infrastructure_condition.gd")
const Passenger = preload("res://scripts/rail/passenger_controller.gd")
const Freight = preload("res://scripts/rail/freight_controller.gd")
const Rail = preload("res://scripts/rail/rail_network.gd")
const Excavation = preload("res://scripts/excavation/excavation_planner.gd")
const Artifacts = preload("res://scripts/artifacts/artifact_system.gd")
const Siege = preload("res://scripts/threats/siege_controller.gd")
const Defense = preload("res://scripts/defense/defense_system.gd")
const Territory = preload("res://scripts/world/territory_network.gd")
const Research = preload("res://scripts/progression/research_system.gd")
const Trace = preload("res://scripts/threats/sector_trace.gd")
const Threats = preload("res://scripts/threats/threat_system.gd")
const Emissions = preload("res://scripts/simulation/emission_events.gd")
const Tether = preload("res://scripts/drones/power_tether.gd")
const Hazards = preload("res://scripts/world/environment_hazards.gd")
const Solar = preload("res://scripts/world/solar_collector.gd")
const Weather = preload("res://scripts/world/weather_system.gd")
const Orders = preload("res://scripts/autonomy/order_runner.gd")
const Suit = preload("res://scripts/player/hazard_suit.gd")
const Recovery = preload("res://scripts/recovery/recovery_controller.gd")
const Salvage = preload("res://scripts/salvage/delivery_zone.gd")
const Failsafes = preload("res://scripts/autonomy/failsafe_controller.gd")
const Conditions = preload("res://scripts/drones/malfunction_system.gd")
const Radio = preload("res://scripts/telemetry/radio_network.gd")
const DronePower = preload("res://scripts/drones/power_system.gd")
const Discovery = preload("res://scripts/salvage/camera_discovery.gd")
const LifeSupport = preload("res://scripts/simulation/life_support.gd")
const Fleet = preload("res://scripts/drones/fleet.gd")
const Inventory = preload("res://scripts/simulation/inventory.gd")
const Fabrication = preload("res://scripts/workshop/fabrication_queue.gd")
const CONTROL_PATHS := ["CommandCRT", "TelemetryCRT", "MapCRT", "WorkshopBench",
	"LifeBreaker", "PowerBreaker", "CommandSwitch", "WorkshopSwitch",
	"Airlock/InnerDoor", "AirlockControlOutside", "AirlockControlInside"]


static func capture(world: Node) -> Dictionary:
	var operator: Node3D = world.get_node("Operator")
	var controls := {}
	for path in CONTROL_PATHS:
		controls[path] = world.get_node("Bunker/" + path + "/Interaction").powered
	var airlock := world.get_node("Bunker/Airlock")
	return {"version":VERSION,"elapsed":world.elapsed_seconds,
		"operator":{"position":[operator.position.x,operator.position.y,operator.position.z],
			"yaw":operator.rotation.y,"pitch":operator.get_node("Head").rotation.x},
		"controls":controls,"airlock":{"open":String(airlock.opened_side),
			"outer_authorized":airlock.outer_authorized},
		"life_support":world.get_node("LifeSupport").snapshot(),
		"fleet":world.get_node("Fleet").snapshot(),
		"inventory":world.get_node("Inventory").snapshot(),
		"fabrication":world.get_node("Fabrication").snapshot(),
		"camera_discovery":world.get_node("CameraDiscovery").snapshot(),
		"drone_power":world.get_node("DronePower").snapshot(),
		"radio":world.get_node("Radio").snapshot(),
		"conditions":world.get_node("Conditions").snapshot(),
		"failsafes":world.get_node("Failsafes").snapshot(),
		"salvage":world.get_node("Salvage").snapshot(),
		"recovery":world.get_node("Recovery").snapshot(),
		"human_sortie":world.get_node("HumanSortie").snapshot(),
		"orders":world.get_node("Orders").snapshot(),
		"weather":world.get_node("Weather").snapshot(),
		"solar":world.get_node("Solar").snapshot(),
		"hazards":world.get_node("EnvironmentHazards").snapshot(),
		"power_tethers":world.get_node("PowerTether").snapshot(),
		"emissions":world.get_node("Emissions").snapshot(),
		"threats":world.get_node("Threats").snapshot(),
		"trace":world.get_node("Trace").snapshot(),
		"research":world.get_node("Research").snapshot(),
		"territory":world.get_node("Territory").snapshot(),
		"defense":world.get_node("Defense").snapshot(),
		"siege":world.get_node("Siege").snapshot(),
		"artifacts":world.get_node("Artifacts").snapshot(),
		"excavation":world.get_node("Excavation").snapshot(),
		"rail":world.get_node("Rail").snapshot(),
		"passenger":world.get_node("Passenger").snapshot(),
		"breaches":world.get_node("Breaches").snapshot()}


static func validate(data: Variant) -> String:
	if not data is Dictionary:
		return "Invalid save structure."
	if not _number(data.get("version")) or data.version != int(data.version) or data.version < 1 or data.version > VERSION:
		return "Unsupported save version."
	if not _number(data.get("elapsed")) or data.elapsed < 0:
		return "Invalid simulation time."
	var operator: Variant = data.get("operator")
	if not operator is Dictionary:
		return "Missing operator state."
	var position: Variant = operator.get("position")
	if not position is Array or position.size() != 3:
		return "Invalid operator position."
	for value in position:
		if not _number(value) or absf(float(value)) > 1000000.0:
			return "Invalid operator position."
	if not _number(operator.get("yaw")) or not _number(operator.get("pitch")):
		return "Invalid camera rotation."
	if absf(float(operator.pitch)) > PI / 2.0:
		return "Invalid camera pitch."
	var controls: Variant = data.get("controls")
	if not controls is Dictionary:
		return "Missing control state."
	for path in CONTROL_PATHS:
		if not controls.get(path) is bool:
			return "Invalid control state."
	var airlock: Variant = data.get("airlock")
	if not airlock is Dictionary or airlock.get("open") not in ["","inner","outer"]:
		return "Invalid airlock state."
	if not airlock.get("outer_authorized") is bool:
		return "Invalid surface authorization."
	if airlock.open == "outer" and not airlock.outer_authorized:
		return "Inconsistent airlock state."
	if data.version >= 2 and not LifeSupport.validate(data.get("life_support")):
		return "Invalid life-support state."
	if data.version >= 3 and not Fleet.validate(data.get("fleet")):
		return "Invalid fleet state."
	if data.version >= 5:
		for machine in data.fleet:
			if not machine.get("deployed") is bool:
				return "Invalid deployment state."
	if data.version >= 4 and (not Inventory.validate(data.get("inventory")) or not Fabrication.validate(data.get("fabrication"))):
		return "Invalid workshop state."
	if data.version >= 6:
		if not Discovery.validate(data.get("camera_discovery")):
			return "Invalid camera discovery."
		if data.camera_discovery.state == "carried":
			var found := false
			for machine in data.fleet:
				found = found or (machine.id == data.camera_discovery.owner and machine.cargo_kg >= 4.0)
			if not found:
				return "Missing camera carrier."
	if data.version >= 7 and not DronePower.validate(data.get("drone_power")):
		return "Invalid charging state."
	if data.version >= 8 and not Radio.validate(data.get("radio")):
		return "Invalid radio schedule."
	if data.version >= 9:
		if not Conditions.validate(data.get("conditions")):
			return "Invalid wear schedule."
		for machine in data.fleet:
			if not machine.has("components") or not machine.has("faults"):
				return "Missing chassis condition."
	if data.version >= 10 and not Failsafes.validate(data.get("failsafes")):
		return "Invalid breadcrumb state."
	if data.version >= 11:
		if data.version >= 12 and not Recovery.validate(data.get("recovery")):
			return "Invalid recovery state."
		if not Salvage.validate(data.get("salvage"),data.version < 17):
			return "Invalid salvage state."
		var masses := {}
		for record in data.salvage:
			if record.state == "carried":
				for definition in Salvage.CATALOG.sites:
					if definition.id == record.id:
						masses[record.carrier] = masses.get(record.carrier,0.0) + definition.mass
		if data.camera_discovery.state == "carried":
			masses[data.camera_discovery.owner] = masses.get(data.camera_discovery.owner,0.0) + 4.0
		if data.version >= 12:
			for record in data.recovery.values():
				if record.state == "parts":
					masses[record.owner] = masses.get(record.owner,0.0) + 20.0
		if data.version >= 23:
			if not Research.validate(data.get("research")): return "Invalid research state."
			for record in data.research.archives.values():
				if record.state == "carried": masses[record.carrier] = masses.get(record.carrier,0.0) + 1.0
		if data.version >= 24:
			if not Territory.validate(data.get("territory")): return "Invalid territory state."
			for id in data.territory.cargo:
				masses[id] = masses.get(id,0.0) + Territory.PRODUCTS[data.territory.cargo[id]].mass
		if data.version >= 25:
			if not Defense.validate(data.get("defense")): return "Invalid defense state."
			for id in data.defense.ammo: masses[id] = masses.get(id,0.0)+data.defense.ammo[id]*0.02
			for id in data.defense.kits: masses[id] = masses.get(id,0.0)+data.defense.kits[id]
		if data.version>=27:
			if not Artifacts.validate(data.get("artifacts")): return "Invalid artifact state."
			for record in data.artifacts.values():
				if record.state=="carried": masses[record.carrier] = masses.get(record.carrier,0.0)+1.0
		for id in masses:
			var found := false
			for machine in data.fleet:
				found = found or (machine.id == id and machine.cargo_kg + 0.000001 >= masses[id])
			if not found:
				return "Invalid salvage carrier mass."
	if data.version >= 12:
		if not Recovery.validate(data.get("recovery")):
			return "Invalid recovery state."
		for id in data.recovery:
			var record: Dictionary = data.recovery[id]
			var found := false
			for machine in data.fleet:
				if record.state == "awake" and machine.id == id:
					found = true
				if record.state in ["parts","stripping","towing"] and machine.id == record.owner:
					found = record.state != "parts" or machine.cargo_kg >= 20.0
			if record.state in ["awake","parts","stripping","towing"] and not found:
				return "Missing recovered frame or carrier."
	if data.version >= 13:
		if not Suit.validate(data.get("human_sortie")):
			return "Invalid human sortie."
		if data.human_sortie.active and not data.airlock.outer_authorized:
			return "Suit lacks surface authorization."
		if not data.human_sortie.escort.is_empty():
			var found := false
			for machine in data.fleet:
				found = found or machine.id == data.human_sortie.escort
			if not found:
				return "Missing human escort."
	if data.version >= 14:
		if not Orders.validate(data.get("orders")):
			return "Invalid rule program."
		for id in data.orders:
			var found := false
			for machine in data.fleet:
				found = found or machine.id == id
			if not found:
				return "Missing programmed frame."
			if data.orders[id].mode == "return" and data.orders[id].return_cursor >= data.failsafes.get(id,{}).get("points",[]).size():
				return "Invalid remembered return cursor."
	if data.version >= 15 and not Weather.validate(data.get("weather")):
		return "Invalid weather schedule."
	if data.version >= 16 and not Solar.validate(data.get("solar")):
		return "Invalid solar construction."
	if data.version >= 17 and not Hazards.validate(data.get("hazards")):
		return "Invalid environmental hazards."
	if data.version >= 18 and not data.hazards.has("contamination"):
		return "Missing hotspot contamination."
	if data.version >= 19 and not data.hazards.has("vent_cycles"):
		return "Missing geothermal exposure."
	if data.version >= 20:
		if not Tether.validate(data.get("power_tethers")): return "Invalid power tethers."
		for id in data.power_tethers:
			var receiver := false
			var donor := false
			for machine in data.fleet:
				receiver = receiver or (machine.id == id and Fleet.CATALOG.hull(machine.hull).external_power)
				donor = donor or (machine.id == data.power_tethers[id] and machine.hull == "tender" and "power_coupler" in machine.modules.values())
			if not receiver or not donor: return "Missing convoy frame or coupler."
	if data.version >= 21:
		if not Emissions.validate(data.get("emissions")) or not Threats.validate(data.get("threats")): return "Invalid threat or emissions state."
		for machine in data.fleet:
			if not machine.has("integrity"): return "Missing structural integrity."
		if not data.human_sortie.has("flash"): return "Missing emergency flash cooldown."
	if data.version >= 22:
		if not Trace.validate(data.get("trace")): return "Invalid sector trace or nest clocks."
		for nest in data.trace.nests:
			for id in nest.population:
				var found := false
				for actor in data.threats: found = found or actor.id == id
				if not found: return "Missing nest patrol."
	if data.version >= 23 and not Research.validate(data.get("research")): return "Invalid research state."
	if data.version >= 24:
		if not Territory.validate(data.get("territory")): return "Invalid territory state."
		var machines := {}
		for record in data.fleet: machines[record.id] = record
		for site in data.territory.sites:
			if not site.relay.is_empty() and not machines.has(site.relay): return "Missing relay chassis."
		for id in data.territory.cargo:
			if not machines.has(id) or machines[id].hull != "goliath" or "prefab_winch" not in machines[id].modules.values(): return "Missing prefab carrier."
		for id in data.territory.power_links:
			if not machines.has(id) or machines[id].hull != "goliath" or data.power_tethers.has(id): return "Invalid pylon receiver."
	if data.version>=25:
		if not Defense.validate(data.get("defense")): return "Invalid defense state."
		for key in data.defense.perimeters:
			if not data.territory.sites[int(key)].get("perimeter",false): return "Unbuilt perimeter."
		for i in 6:
			if data.territory.sites[i].get("perimeter",false) and not data.defense.perimeters.has(str(i)): return "Missing perimeter."
		for group in ["ammo","kits","cooldowns","pending","decoys"]:
			for id in data.defense[group]:
				var found := false
				for record in data.fleet: found = found or record.id==id
				if not found: return "Missing defense carrier."
	if data.version>=26:
		if not Siege.validate(data.get("siege")): return "Invalid siege state."
		for id in data.siege.roster:
			var found := false
			for record in data.threats: found = found or record.id==id
			if not found or id not in data.trace.nests[int(data.siege.band)].population: return "Missing siege patrol."
	if data.version>=27:
		if not Artifacts.validate(data.get("artifacts")): return "Invalid artifact state."
		for record in data.artifacts.values():
			if record.state!="fitted" or record.socket=="bunker": continue
			var found := false
			for machine in data.fleet:
				if machine.id!=record.socket: continue
				found = true
				var mass: float = machine.cargo_kg+1.0
				for part in machine.modules.values(): mass += Fleet.CATALOG.module(part).mass_kg
				if mass>Fleet.CATALOG.hull(machine.hull).payload_kg: return "Artifact exceeds hull payload."
			if not found: return "Missing artifact hull."
	if data.version>=28:
		for machine in data.fleet:
			if not machine.has("optics"): return "Missing optical settings."
	if data.version>=29:
		var access: bool = data.version>=32 and data.get("passenger") is Dictionary and data.passenger.get("installed")==true
		var ranges := {}
		if data.version>=35:
			if not Excavation.validate(data.get("excavation"),access,{},false) or not data.get("breaches") is Dictionary: return "Invalid excavation structure."
			var grid := Excavation.Plan.grid(data.excavation.segments,data.excavation.rooms)
			if not Breaches.Portal.valid(data.breaches.get("portals"),data.excavation.segments,grid): return "Invalid ingress geometry."
			ranges = Breaches.Portal.cleared_ranges(data.breaches.portals)
		if not Excavation.validate(data.get("excavation"),access,ranges): return "Invalid excavation state."
		for plan in data.excavation.segments:
			if not data.territory.sites[int(plan.source)].held or not data.territory.sites[int(plan.target)].held: return "Excavation crosses unheld ground."
		for plan in data.excavation.rooms.values():
			if not data.territory.sites[int(plan.source)].held: return "Room crosses unheld ground."
		for job in data.excavation.jobs.values():
			if not data.territory.sites[int(job.plan.source)].held or not data.territory.sites[int(job.plan.target)].held: return "Job crosses unheld ground."
			var found := false
			for machine in data.fleet:
				if machine.id==job.worker:
					found = machine.deployed and "drill" in machine.modules.values()
			if not found or data.territory.job.get("id","")==job.worker: return "Invalid excavation worker."
	if data.version>=30:
		if not data.inventory.has("cells") or not data.inventory.has("next_cell_serial"): return "Missing portable cell inventory."
		if not Rail.validate(data.get("rail"),data.excavation.segments.size()): return "Invalid rail infrastructure."
		if data.version>=31 and (not data.rail.has("auto_feed") or not data.rail.has("auto_unload")): return "Missing depot service settings."
		if data.version>=31 or data.rail.has("freight"):
			if not Freight.validate(data.rail.get("freight"),data.excavation.segments,data.rail.car_built): return "Invalid rail freight."
		if not Rail.identities_valid(data.inventory,data.rail): return "Duplicate or unallocated depot stock identity."
	if data.version>=32:
		var hubs: int = data.excavation.segments.size()+1 if not data.excavation.segments.is_empty() else 0
		if not Passenger.validate(data.get("passenger"),hubs,data.rail.car_built): return "Invalid passenger state."
		var p: Dictionary = data.passenger
		if (p.aboard or p.climb>=0) and data.human_sortie.active: return "Underground transport cannot use a surface suit."
		if p.phase in ["waiting","travel","arrived"] and not data.rail.freight.job.is_empty(): return "Passenger car still carries freight."
		if p.phase in ["waiting","arrived"]:
			var distance := 0.0
			for i in int(p.goal): distance += Territory.pad(i).distance_to(Territory.pad(i+1))
			if absf(data.rail.freight.coordinate-distance)>0.00001: return "Passenger platform does not match car position."
		var saved := Vector3(data.operator.position[0],data.operator.position[1],data.operator.position[2])
		if p.aboard:
			var coordinate: float = data.rail.freight.coordinate
			var point := Freight.route_point(data.excavation.segments,coordinate)
			var direction := (Freight.route_point(data.excavation.segments,coordinate+0.01)-Freight.route_point(data.excavation.segments,maxf(0,coordinate-0.01))).normalized()
			if saved.distance_to(point+Vector3(0,0.6,0)-direction*0.35)>0.05: return "Passenger is not in the rail seat."
		if p.climb>=0 and saved.distance_to(Passenger.Access.climb_position(p.climb))>0.05: return "Operator is not on the access ladder."
	if data.version>=33 or (data.version>=30 and data.rail.has("infrastructure")):
		if not Infrastructure.validate(data.rail.get("infrastructure"),data.excavation.segments): return "Invalid infrastructure state."
		for job in data.rail.infrastructure.jobs.values():
			var found := false
			for machine in data.fleet:
				if machine.id==job.worker: found = "torch" in machine.modules.values()
			if not found or data.territory.job.get("id","")==job.worker: return "Missing or conflicting maintenance hull."
			for dig_job in data.excavation.jobs.values():
				if dig_job.worker==job.worker: return "Hull assigned to two work sites."
	if data.version>=34:
		if not Breaches.validate(data.get("breaches"),data.excavation.segments.size(),data.passenger.installed,data.version<35): return "Invalid entrance or ingress state."
		var actors := {}
		for actor in data.threats: actors[actor.id] = true
		for id in data.breaches.routes:
			if not actors.has(id): return "Missing physical intruder."
			if data.version>=35 and data.breaches.routes[id].climb>=0:
				for actor in data.threats:
					if actor.id==id and Vector3(actor.at[0],actor.at[1],actor.at[2]).distance_to(Breaches.Access.climb_position(data.breaches.routes[id].climb))>0.05: return "Invalid intruder climb pose."
		for id in data.breaches.cooldowns:
			var found := false
			for machine in data.fleet: found = found or machine.id==id
			if not found: return "Missing entrance service hull."
	return ""


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func restore(world: Node, data: Dictionary) -> void:
	assert(validate(data).is_empty())
	var operator := world.get_node("Operator")
	var position: Array = data.operator.position
	operator.position = Vector3(position[0],position[1],position[2])
	operator.velocity = Vector3.ZERO
	operator.rotation.y = data.operator.yaw
	operator.get_node("Head").rotation.x = data.operator.pitch
	world.elapsed_seconds = data.elapsed
	# Version 1 predates life support; migrate once with the opening supplies.
	if data.version >= 2:
		world.get_node("LifeSupport").restore(data.life_support)
	if data.version >= 3:
		world.get_node("Fleet").restore(data.fleet)
	if data.version >= 4:
		world.get_node("Inventory").restore(data.inventory)
		world.get_node("Fabrication").restore(data.fabrication)
	if data.version >= 6:
		world.get_node("CameraDiscovery").restore(data.camera_discovery)
	if data.version >= 7:
		world.get_node("DronePower").restore(data.drone_power)
	if data.version >= 8:
		world.get_node("Radio").restore(data.radio)
	if data.version >= 9:
		world.get_node("Conditions").restore(data.conditions)
	if data.version >= 10:
		world.get_node("Failsafes").restore(data.failsafes)
	if data.version >= 11:
		world.get_node("Salvage").restore(data.salvage)
	if data.version >= 12:
		world.get_node("Recovery").restore(data.recovery)
	if data.version >= 13:
		world.get_node("HumanSortie").restore(data.human_sortie)
	if data.version >= 14:
		world.get_node("Orders").restore(data.orders)
	if data.version >= 15:
		world.get_node("Weather").restore(data.weather)
	if data.version >= 16:
		world.get_node("Solar").restore(data.solar)
	if data.version >= 17:
		world.get_node("EnvironmentHazards").restore(data.hazards)
	if data.version >= 20:
		world.get_node("PowerTether").restore(data.power_tethers)
	if data.version >= 21:
		world.get_node("Emissions").restore(data.emissions)
		world.get_node("Threats").restore(data.threats)
	if data.version >= 22:
		world.get_node("Trace").restore(data.trace)
	if data.version >= 23:
		world.get_node("Research").restore(data.research)
	else:
		world.get_node("Research").legacy_recipes = Research.LEGACY_RECIPES.duplicate()
	if data.version >= 24: world.get_node("Territory").restore(data.territory)
	if data.version >= 25: world.get_node("Defense").restore(data.defense)
	if data.version >= 26: world.get_node("Siege").restore(data.siege)
	elif data.version>=22:
		# Old home-known patrols had their home overwritten with the airlock.
		# Coordination now owns the southward order; keep a genuine retreat home.
		for nest in world.get_node("Trace").nests:
			for id in nest.population:
				var actor: Node = world.get_node("Threats").actors.get(id)
				if actor!=null and actor.home.z>=-20: actor.home = nest.position
	if data.version>=27: world.get_node("Artifacts").restore(data.artifacts)
	if data.version>=29: world.get_node("Excavation").restore(data.excavation,Breaches.Portal.cleared_ranges(data.breaches.portals) if data.version>=35 else {})
	if data.version>=30: world.get_node("Rail").restore(data.rail)
	else: world.get_node("Rail").sync()
	if data.version>=32: world.get_node("Passenger").restore(data.passenger)
	else: world.get_node("Passenger").restore({"installed":false,"remaining":0.0,"phase":"idle","goal":0,"aboard":false,"climb":-1.0,"climb_direction":1})
	for path in CONTROL_PATHS:
		var control := world.get_node("Bunker/" + path + "/Interaction")
		control.powered = data.controls[path]
		control.power_changed.emit(control.powered)
	var airlock := world.get_node("Bunker/Airlock")
	airlock.opened_side = StringName(data.airlock.open)
	airlock.outer_authorized = data.airlock.outer_authorized
	for side in ["InnerDoor","OuterDoor"]:
		var door: AnimatableBody3D = airlock.get_node(side)
		door.sync_to_physics = false
		door.position.x = 1.8 if data.airlock.open == ("inner" if side == "InnerDoor" else "outer") else 0.0
		door.sync_to_physics = true
	airlock.state_changed.emit()
	if data.version>=34: world.get_node("Breaches").restore(data.breaches,data.version<35)
	else: world.get_node("Breaches").reset()
