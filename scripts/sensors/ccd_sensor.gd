extends Node

var viewport: SubViewport
var camera: Camera3D
var frame_count: int = 0
var accumulator: float = 0.0


func _ready() -> void:
	get_parent().configuration_changed.connect(_configure)
	_configure()


func _configure() -> void:
	var clean: bool = preload("res://scripts/sensors/sensor_router.gd").clean(get_parent())
	if not clean and not "ccd" in get_parent().modules.values():
		if is_instance_valid(viewport):
			remove_child(viewport)
			viewport.queue_free()
		viewport = null
		camera = null
		return
	if viewport!=null:
		viewport.size = Vector2i(640,480) if clean else Vector2i(240,180)
		return
	if RenderingServer.get_rendering_device() == null:
		return
	viewport = SubViewport.new()
	viewport.name = "OpticalViewport"
	viewport.size = Vector2i(640,480) if clean else Vector2i(240,180)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(viewport)
	camera = Camera3D.new()
	camera.name = "CCDCamera"
	camera.fov = 70.0
	camera.near = 0.05
	camera.far = 100.0
	viewport.add_child(camera)
	camera.current = true


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	var router = preload("res://scripts/sensors/sensor_router.gd")
	var neural: bool = router.neural(get_parent())
	var advanced: bool = router.advanced(get_parent())
	if not get_parent().has_power() or not router.working(get_parent()):
		return
	var rate: float = 60.0 if neural else (60.0*minf(1,get_parent().module_efficiency("multispectrum")) if advanced else 15.0)
	accumulator += delta
	if accumulator + 0.000000001 < 1.0/rate:
		return
	accumulator = maxf(0,accumulator-(1.0/rate)*floor((accumulator+0.000000001)*rate))
	frame_count += 1
	if viewport != null:
		camera.global_transform = eye_transform()
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func eye_transform() -> Transform3D:
	var body: Node3D = get_parent()
	var offset := Vector3(0,0.85,-0.76)
	if body.hull_id == "goliath": offset = Vector3(-0.45,1.65,-1.86)
	elif body.hull_id == "tender": offset = Vector3(0,1.35,-1.25)
	elif body.hull_id == "biped": offset = Vector3(0,1.6,-0.45)
	return body.global_transform * Transform3D(Basis.IDENTITY,offset)

func in_frustum(at: Vector3) -> bool:
	var relative := eye_transform().affine_inverse() * at
	var vertical := tan(deg_to_rad(35.0))
	if get_parent().module_efficiency("multispectrum")>0: vertical /= get_parent().get_node("Multispectrum").zoom
	return relative.z < -0.05 and relative.z >= -100.0 and absf(relative.x) <= -relative.z * vertical * 4.0 / 3.0 and absf(relative.y) <= -relative.z * vertical
