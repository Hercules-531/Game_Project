extends Node
## Remote steering moves the actual collision body, never the operator.

var command := Vector2.ZERO
var available: bool = true


func _physics_process(delta: float) -> void:
	var body: CharacterBody3D = get_parent()
	if not body.deployed or not available or body.battery <= 0.0 or body.component_efficiency("joints") <= 0.0 or body.component_efficiency("cell") <= 0.0:
		body.velocity = Vector3.ZERO
		return
	body.rotation.y = wrapf(body.rotation.y - command.x * 1.4 * delta,-PI,PI)
	var desired: Vector3 = body.global_basis * Vector3(0,0,command.y) * body.hull().speed * body.component_efficiency("joints") * body.speed_multiplier * body.terrain_multiplier
	if body.silent_running:
		desired *= 0.35
	body.velocity.x = move_toward(body.velocity.x,desired.x,8.0 * delta)
	body.velocity.z = move_toward(body.velocity.z,desired.z,8.0 * delta)
	body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 9.8 * delta
	body.move_and_slide()


func stop() -> void:
	command = Vector2.ZERO
	get_parent().velocity = Vector3.ZERO
