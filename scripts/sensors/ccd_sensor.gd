extends Node

var viewport: SubViewport
var camera: Camera3D
var frame_count: int = 0
var accumulator: float = 0.0


func _ready() -> void:
	get_parent().configuration_changed.connect(_configure)
	_configure()


func _configure() -> void:
	if not "ccd" in get_parent().modules.values():
		if is_instance_valid(viewport):
			remove_child(viewport)
			viewport.queue_free()
		viewport = null
		camera = null
		return
	if viewport != null or RenderingServer.get_rendering_device() == null:
		return
	viewport = SubViewport.new()
	viewport.name = "OpticalViewport"
	viewport.size = Vector2i(240,180)
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
	if not get_parent().has_power() or get_parent().module_efficiency("ccd") <= 0.0:
		return
	accumulator += delta
	if accumulator + 0.000000001 < 1.0 / 15.0:
		return
	accumulator = fmod(accumulator,1.0 / 15.0)
	frame_count += 1
	if viewport != null:
		var offset := Vector3(0,0.85,-0.76)
		if get_parent().hull_id == "goliath": offset = Vector3(-0.45,1.65,-1.86)
		elif get_parent().hull_id == "tender": offset = Vector3(0,1.35,-1.25)
		camera.global_transform = get_parent().global_transform * Transform3D(Basis.IDENTITY,offset)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
