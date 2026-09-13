extends Node

signal target_changed(target: OutpostInteractable)
@export var reach: float = 2.0
var target: OutpostInteractable
@onready var operator: CharacterBody3D = get_parent()
@onready var camera: Camera3D = operator.get_node("Head/Camera")


func _physics_process(_delta: float) -> void:
	var next := find_target()
	if next != target:
		target = next
		target_changed.emit(target)


func find_target() -> OutpostInteractable:
	if not InputContext.allows_movement():
		return null
	var start := camera.global_position
	var end := start - camera.global_basis.z * reach
	var query := PhysicsRayQueryParameters3D.create(start, end, 1, [operator.get_rid()])
	var hit := operator.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var node: Node = hit.collider
	while node != null and node != get_tree().current_scene:
		var interaction := node.get_node_or_null("Interaction") as OutpostInteractable
		if interaction != null:
			return interaction if interaction.enabled else null
		node = node.get_parent()
	return null


func use_target() -> bool:
	# Re-query at activation so stale focus cannot bypass range or occlusion.
	var current := find_target()
	if current == null:
		return false
	current.use()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo():
		if use_target():
			get_viewport().set_input_as_handled()
