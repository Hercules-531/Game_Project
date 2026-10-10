extends Node
## Remote steering moves the actual collision body, never the operator.

var command := Vector2.ZERO
var available: bool = true


func _physics_process(delta: float) -> void:
	var body: CharacterBody3D = get_parent()
	if not body.deployed or not available or not body.has_power() or body.component_efficiency("joints") <= 0.0:
		body.velocity = Vector3.ZERO
		return
	body.rotation.y = wrapf(body.rotation.y - command.x * 1.4 * delta,-PI,PI)
	var desired: Vector3 = body.global_basis * Vector3(0,0,command.y) * body.hull().speed * body.component_efficiency("joints") * body.speed_multiplier * body.terrain_multiplier
	if body.silent_running:
		desired *= 0.35
	_step_onto_floor(body,desired * delta)
	body.velocity.x = move_toward(body.velocity.x,desired.x,8.0 * delta)
	body.velocity.z = move_toward(body.velocity.z,desired.z,8.0 * delta)
	body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 9.8 * delta
	body.move_and_slide()

func _step_onto_floor(body: CharacterBody3D, motion: Vector3) -> void:
	if _can_step(body,motion):
		body.global_position += Vector3.UP * body.hull().step_height

func can_traverse(motion: Vector3) -> bool:
	var body: CharacterBody3D = get_parent()
	return not body.test_move(body.global_transform,motion) or _can_step(body,motion.limit_length(0.05))

func _can_step(body: CharacterBody3D, motion: Vector3) -> bool:
	if not body.is_on_floor() or motion.length() < 0.00001 or not body.test_move(body.global_transform,motion):
		return false
	var height: float = body.hull().step_height
	var lift := Vector3.UP * height
	if height <= 0.0 or body.test_move(body.global_transform,lift):
		return false
	var raised: Transform3D = body.global_transform
	raised.origin += lift
	if body.test_move(raised,motion):
		return false
	var collision: CollisionShape3D = body.get_node("Collision")
	var toe: Vector3 = body.global_position + motion.normalized() * (collision.shape.size.z * 0.5 + 0.12)
	var ray := PhysicsRayQueryParameters3D.create(toe + Vector3.UP * (height + 0.2),toe - Vector3.UP * 0.1,1,[body.get_rid()])
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < cos(body.floor_max_angle):
		return false
	# Lift only after clear vertical/horizontal sweeps and a walkable floor probe.
	return true


func stop() -> void:
	command = Vector2.ZERO
	get_parent().velocity = Vector3.ZERO
