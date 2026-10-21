extends Node3D
const Kit = preload("res://scripts/world/surface_kit.gd")
const Interaction = preload("res://scripts/interaction/interactable.gd")
var passenger: Node
var hub := 0
var control: Node3D
func _ready() -> void:
	control = Kit.box(self,"RideControl",Vector3(0.3,0.32,0.16),Vector3(1.35,1.3,0.85),"metal")
	var use := Interaction.new()
	use.name = "Interaction"
	use.display_name = "Rail passenger / " + ("home" if hub==0 else "depot %d" % hub)
	control.add_child(use)
	use.used.connect(func(_target): passenger.get_parent().get_node("PassengerPanel").open(hub))
