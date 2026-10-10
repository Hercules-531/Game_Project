extends Node3D
signal changed
const COST := 24
const BUILD_SECONDS := 60.0
const BASE_KW := 1.0
var installed := false
var enabled := true
var remaining := 0.0
var model: Node3D
@onready var life: Node = get_parent().get_node("LifeSupport")
@onready var weather: Node = get_parent().get_node("Weather")
func _ready() -> void:
	life.energy_step.connect(_tick)
	weather.changed.connect(_update)
	model = Node3D.new()
	add_child(model)
	var kit = preload("res://scripts/world/surface_kit.gd")
	kit.box(model,"Mast",Vector3(0.15,4.1,0.15),Vector3(5,2.05,-14),"metal",false)
	for x in [4.4,5.6]:
		var deck = kit.box(model,"Collector",Vector3(1.0,0.07,0.85),Vector3(x,4.15,-14),"metal",false)
		deck.rotation_degrees.x = 25.0
		deck.get_child(0).material_override.set_shader_parameter("tint",Color(0.45,0.6,0.74))
		for z in [-0.25,0.0,0.25]:
			kit.box(deck,"CellDivider",Vector3(0.95,0.012,0.018),Vector3(0,0.045,z),"metal",false)
	_update()
func construct() -> bool:
	if installed or remaining > 0.0 or life.dead or not get_parent().get_node("Inventory").spend_scrap(COST):
		return false
	remaining = BUILD_SECONDS
	_update()
	return true
func toggle() -> void:
	enabled = not enabled
	_update()
func output_kw() -> float:
	if not installed or not enabled:
		return 0.0
	var at := Vector3(5,4.3,-14)
	var sun: DirectionalLight3D = get_parent().get_node("Surface/SurfaceSun")
	var ray := PhysicsRayQueryParameters3D.create(at,at + sun.global_basis.z * 80.0,1)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return 0.0
	return BASE_KW * (1.75 if weather.current == "sunlight" else 1.0)
func _tick(fraction: float) -> void:
	if remaining > 0.0:
		remaining = maxf(0.0,remaining - fraction)
		if remaining <= 0.0: installed = true
	_update()
func _update() -> void:
	life.solar_load_kw = 0.6 if remaining > 0.0 else 0.0
	life.aux_generation_kw = output_kw()
	model.visible = installed
	changed.emit()
func snapshot() -> Dictionary:
	return {"installed":installed,"enabled":enabled,"remaining":remaining}
static func validate(data: Variant) -> bool:
	if not data is Dictionary or not data.get("installed") is bool or not data.get("enabled") is bool: return false
	var value: Variant = data.get("remaining")
	return (value is float or value is int) and is_finite(value) and value >= 0.0 and value <= BUILD_SECONDS and not (data.installed and value > 0.0)
func restore(data: Dictionary) -> void:
	assert(validate(data))
	installed = data.installed
	enabled = data.enabled
	remaining = data.remaining
	_update()
