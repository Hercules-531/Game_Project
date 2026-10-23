extends Node
var environment: Environment
var rain: CPUParticles3D
@onready var weather: Node = get_parent().get_node("Weather")
@onready var sun: DirectionalLight3D = get_parent().get_node("Surface/SurfaceSun")
func _ready() -> void:
	environment = get_parent().get_node("Bunker/Environment").environment.duplicate()
	rain = CPUParticles3D.new()
	rain.name = "AcidStreaks"
	rain.amount = 120
	# Keep non-colliding streaks above ground rather than inside sealed tunnels.
	rain.lifetime = 0.45
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(9,0,9)
	rain.direction = Vector3.DOWN
	rain.spread = 4.0
	rain.initial_velocity_min = 8.0
	rain.initial_velocity_max = 12.0
	var streak := BoxMesh.new()
	streak.size = Vector3(0.012,0.4,0.012)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/rain_streak.gdshader")
	material.set_shader_parameter("surface_texture",preload("res://scripts/world/surface_kit.gd").METAL)
	streak.material = material
	rain.mesh = streak
	get_parent().get_node("Surface").add_child(rain)
	rain.global_position = Vector3(0,7,-22)
	weather.changed.connect(_update)
	_update()
func update_roofs(portals: Dictionary) -> void:
	var rects := PackedVector4Array()
	var planes := PackedVector4Array()
	for rect in [Rect2(-1.3,-6,2.6,12),Rect2(-7.3,-2,6,6),Rect2(1.3,-2,6,6),Rect2(-3.3,6,6.6,4),Rect2(-2.3,-10,4.6,4)]:
		rects.append(Vector4(rect.position.x,rect.position.y,rect.end.x,rect.end.y))
		planes.append(Vector4(0,2.8,0,0))
	for layout in portals.values():
		rects.append(Vector4(layout.start,layout.row+2,layout.start+9,layout.row+4))
		planes.append(Vector4(-1.0/3.0,2.6+layout.start/3.0,0,0))
	var count := rects.size()
	rects.resize(16)
	planes.resize(16)
	rain.mesh.material.set_shader_parameter("roof_count",count)
	rain.mesh.material.set_shader_parameter("roof_rects",rects)
	rain.mesh.material.set_shader_parameter("roof_planes",planes)
func _update() -> void:
	var clear: bool = weather.current == "sunlight"
	environment.background_color = Color(0.17,0.23,0.28) if clear else Color(0.02,0.025,0.025)
	sun.light_energy = 1.3 if clear else 0.8
	var smog: bool = weather.current == "smog"
	var ash: bool = weather.current == "ash"
	environment.fog_enabled = smog or ash
	environment.fog_density = 0.025 if smog else (0.012 if ash else 0.0)
	environment.fog_light_color = Color(0.38,0.32,0.27) if ash else Color(0.16,0.26,0.23)
	if weather.current == "rain":
		environment.fog_enabled = true
		environment.fog_density = 0.006
		environment.fog_light_color = Color(0.14,0.20,0.17)
		sun.light_energy = 0.45
	if weather.current == "aurora":
		environment.background_color = Color(0.15,0.055,0.21)
		environment.ambient_light_color = Color(0.52,0.35,0.68)
	else:
		environment.ambient_light_color = get_parent().get_node("Bunker/Environment").environment.ambient_light_color
	rain.emitting = weather.current == "rain"
	rain.visible = rain.emitting
func _physics_process(_delta: float) -> void:
	for drone in get_parent().get_node("Fleet").get_children():
		var camera: Camera3D = drone.get_node("CCD").camera
		if camera != null:
			camera.environment = environment
			camera.far = 35.0 if weather.current == "smog" else 100.0
			camera.compositor = preload("res://resources/render/ps1_compositor.tres")
	var operator: Node3D = get_parent().get_node("Operator")
	var breaches: Node = get_parent().get_node_or_null("Breaches")
	var selected: Node = get_parent().get_node("FleetControl").selected()
	rain.global_position = (selected.position if selected != null and selected.deployed else operator.position) + Vector3(0,7,0)
	rain.global_position.y = maxf(7.0,rain.global_position.y)
	rain.global_position.z = minf(-22.0,rain.global_position.z)
	var camera: Camera3D = operator.get_node("Head/Camera")
	var exterior: bool = operator.position.z < -10.0 and operator.position.y > -2.0
	if breaches!=null and breaches.is_node_ready(): exterior = not breaches.indoors(operator.position)
	camera.environment = environment if exterior else null
	camera.compositor = preload("res://resources/render/ps1_compositor.tres") if exterior else null
