extends Node3D
signal changed
const TREE = preload("res://resources/progression/tech_tree.tres")
const Visual = preload("res://scripts/progression/archive_visual.gd")
const Drone = preload("res://scripts/drones/drone.gd")
const Cargo = preload("res://scripts/salvage/cargo_hold.gd")
const LEGACY_RECIPES = ["tracked_frame","heavy_winch","tread_scraper","sealed_housing","goliath_frame","tender_frame","biped_frame","power_coupler","solar_panel","prefab_winch","drill"]
var completed: Array = []
var legacy_recipes: Array = []
var job: Dictionary = {}
var archives: Dictionary = {}
var bodies: Dictionary = {}
var status := "Recover physical archives, unload them, then research with scrap and power."
@onready var life: Node = get_parent().get_node("LifeSupport")
@onready var fleet: Node = get_parent().get_node("Fleet")

func _ready() -> void:
	for id in TREE.topics:
		archives[id] = {"state":"available","carrier":""}
		var body := Node3D.new()
		body.name = id
		body.position = TREE.topics[id].at
		add_child(body)
		var visual := Visual.new()
		visual.name = "Visual"
		body.add_child(visual)
		var solid := StaticBody3D.new()
		solid.name = "Body"
		body.add_child(solid)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.65,0.45,0.5)
		collision.shape = shape
		collision.position.y = 0.225
		solid.add_child(collision)
		body.add_to_group("sensor_landmarks")
		body.set_meta("thermal",0.05)
		body.set_meta("classification","Sealed archive")
		bodies[id] = body
	life.energy_step.connect(_energy_step)

func has_technology(id: String) -> bool:
	return id in completed

func recipe_topic(recipe: String) -> String:
	for id in TREE.topics:
		if recipe in TREE.topics[id].recipes: return id
	return ""

func permits_recipe(recipe: String) -> bool:
	var topic := recipe_topic(recipe)
	return topic.is_empty() or topic in completed or recipe in legacy_recipes

func start(id: String) -> bool:
	if not TREE.topics.has(id) or not job.is_empty() or id in completed:
		status = "Research unavailable or queue occupied."
		return false
	if archives[id].state != "delivered":
		status = "Recover and unload the matching archive first."
		return false
	for prerequisite in TREE.topics[id].prerequisites:
		if prerequisite not in completed:
			status = "Requires " + TREE.topics[prerequisite].name + "."
			return false
	if not get_parent().get_node("Inventory").spend_scrap(TREE.topics[id].scrap):
		status = "Insufficient scrap for research."
		return false
	job = {"topic":id,"remaining":TREE.topics[id].seconds}
	life.research_load_kw = 0.35
	status = "Research paid. Progress requires live grid supply."
	changed.emit()
	return true

func _energy_step(fraction: float) -> void:
	if job.is_empty(): return
	job.remaining = maxf(0.0,job.remaining - clampf(fraction,0.0,1.0))
	if job.remaining <= 0.0:
		completed.append(job.topic)
		status = TREE.topics[job.topic].name + " complete."
		job.clear()
		life.research_load_kw = 0.0
	changed.emit()

func recover_nearest(drone: Node) -> bool:
	if not Cargo.can_load(drone,1.0): return false
	var nearest := ""
	var gap := 3.0
	for id in archives:
		var distance: float = drone.global_position.distance_to(bodies[id].global_position)
		if archives[id].state == "available" and distance <= gap:
			nearest = id
			gap = distance
	if nearest.is_empty(): return false
	var ray := PhysicsRayQueryParameters3D.create(drone.global_position + Vector3(0,0.7,0),bodies[nearest].global_position + Vector3(0,0.3,0),1,[drone.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.collider != bodies[nearest].get_node("Body"): return false
	archives[nearest] = {"state":"carried","carrier":drone.identity}
	drone.cargo_kg += 1.0
	_apply(nearest)
	status = "Archive attached. Unload it before research."
	changed.emit()
	return true

func deliver(drone: Node, exterior: bool = false) -> int:
	if drone == null: return 0
	var gantry: bool = exterior and drone.hull().external_power and drone.position.distance_to(Vector3(0,0.02,-14)) <= 8.0
	if not gantry and (drone.deployed or drone.position.z < -6.0): return 0
	var delivered := 0
	for id in archives:
		if archives[id].state != "carried" or archives[id].carrier != drone.identity: continue
		archives[id] = {"state":"delivered","carrier":""}
		drone.cargo_kg = maxf(0.0,drone.cargo_kg - 1.0)
		_apply(id)
		delivered += 1
	if delivered > 0:
		status = "Archives unloaded. Research is now available at the workshop."
		changed.emit()
	return delivered

func _physics_process(_delta: float) -> void:
	for id in archives:
		if archives[id].state != "carried": continue
		var drone: Node = fleet.drone(archives[id].carrier)
		if drone != null: bodies[id].global_position = drone.global_position + drone.global_basis * Vector3(0,1.1,0.6)

func _apply(id: String) -> void:
	bodies[id].visible = archives[id].state != "delivered"
	bodies[id].get_node("Body").collision_layer = 1 if archives[id].state == "available" else 0
	if archives[id].state == "available": bodies[id].position = TREE.topics[id].at

func snapshot() -> Dictionary:
	return {"completed":completed.duplicate(),"legacy":legacy_recipes.duplicate(),"job":job.duplicate(),"archives":archives.duplicate(true)}

static func validate(data: Variant) -> bool:
	if not data is Dictionary or not data.get("completed") is Array or data.completed.size() > TREE.topics.size() or not data.get("legacy") is Array or data.legacy.size() > LEGACY_RECIPES.size() or not data.get("job") is Dictionary or not data.get("archives") is Dictionary or data.archives.size() != TREE.topics.size(): return false
	var seen := {}
	for id in data.completed:
		if not TREE.topics.has(id) or seen.has(id): return false
		seen[id] = true
		for prerequisite in TREE.topics[id].prerequisites:
			if prerequisite not in data.completed: return false
	seen.clear()
	for id in data.legacy:
		if id not in LEGACY_RECIPES or seen.has(id): return false
		seen[id] = true
	for id in TREE.topics:
		var record: Variant = data.archives.get(id)
		if not record is Dictionary or record.get("state") not in ["available","carried","delivered"] or not record.get("carrier") is String or record.carrier.length() > 80 or ((record.state == "carried") != (not record.carrier.is_empty())): return false
		if id in data.completed and record.state != "delivered": return false
	if data.job.is_empty(): return true
	var id: Variant = data.job.get("topic")
	if not TREE.topics.has(id) or id in data.completed or data.archives[id].state != "delivered" or not Drone._range(data.job.get("remaining"),0.000001,TREE.topics[id].seconds): return false
	for prerequisite in TREE.topics[id].prerequisites:
		if prerequisite not in data.completed: return false
	return true

func restore(data: Dictionary) -> void:
	assert(validate(data))
	completed = data.completed.duplicate()
	legacy_recipes = data.legacy.duplicate()
	job = data.job.duplicate()
	archives = data.archives.duplicate(true)
	for id in archives: _apply(id)
	life.research_load_kw = 0.0 if job.is_empty() else 0.35
	changed.emit()
