extends CharacterBody3D
## Grounded bunker movement. No jump or sprint: those are not in the GDD.

@export var walk_speed: float = 2.6
@export var acceleration: float = 16.0
@export var deceleration: float = 20.0
@export var movement_enabled: bool = true


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if movement_enabled and InputContext.allows_movement():
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	var desired := global_basis * Vector3(input.x, 0.0, input.y).limit_length(1.0) * walk_speed
	var rate := acceleration if not input.is_zero_approx() else deceleration
	velocity.x = move_toward(velocity.x, desired.x, rate * delta)
	velocity.z = move_toward(velocity.z, desired.z, rate * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	move_and_slide()
