extends Node
var environment: Environment
@onready var weather: Node = get_parent().get_node("Weather")
@onready var sun: DirectionalLight3D = get_parent().get_node("Surface/SurfaceSun")
func _ready() -> void:
	environment = get_parent().get_node("Bunker/Environment").environment.duplicate()
	weather.changed.connect(_update)
	_update()
func _update() -> void:
	var clear: bool = weather.current == "sunlight"
	environment.background_color = Color(0.17,0.23,0.28) if clear else Color(0.02,0.025,0.025)
	sun.light_energy = 1.3 if clear else 0.8
	var smog: bool = weather.current == "smog"
	var ash: bool = weather.current == "ash"
	environment.fog_enabled = smog or ash
	environment.fog_density = 0.025 if smog else (0.012 if ash else 0.0)
	environment.fog_light_color = Color(0.38,0.32,0.27) if ash else Color(0.16,0.26,0.23)
func _physics_process(_delta: float) -> void:
	for drone in get_parent().get_node("Fleet").get_children():
		var camera: Camera3D = drone.get_node("CCD").camera
		if camera != null:
			camera.environment = environment
			camera.far = 35.0 if weather.current == "smog" else 100.0
			camera.compositor = preload("res://resources/render/ps1_compositor.tres")
	var operator: Node3D = get_parent().get_node("Operator")
	var camera: Camera3D = operator.get_node("Head/Camera")
	camera.environment = environment if operator.position.z < -10.0 else null
	camera.compositor = preload("res://resources/render/ps1_compositor.tres") if operator.position.z < -10.0 else null
