extends Node3D
const Kit = preload("res://scripts/world/surface_kit.gd")
const Interaction = preload("res://scripts/interaction/interactable.gd")
var hatch: Node3D
var lights: Array = []
@onready var passenger: Node = get_parent()
static func corridor(existing: Dictionary) -> Dictionary:
	var result := existing.duplicate()
	for x in range(-2,2):
		for z in range(-13,10): result[Vector2i(x,z)] = maxf(result.get(Vector2i(x,z),0),3.2)
	return result
static func roof_holes() -> Dictionary:
	return {Vector2i(-1,7):true,Vector2i(0,7):true,Vector2i(-1,8):true,Vector2i(0,8):true}
static func climb_position(progress: float) -> Vector3:
	if progress<1.5: return Vector3(0,0,6.5+progress)
	if progress<7.5: return Vector3(0,1.5-progress,8)
	return Vector3(0,-6,8-(progress-7.5))
func _ready() -> void:
	var floor: Node = passenger.get_parent().get_node("Bunker/LifeSupportFloor")
	floor.hide()
	floor.get_node("Collision").disabled = true
	for x in [-2.15,2.15]: Kit.box(self,"FloorSide",Vector3(2.3,0.2,4),Vector3(x,-0.1,8),"rock")
	for z in [6.5,9.5]: Kit.box(self,"FloorEnd",Vector3(2,0.2,1),Vector3(0,-0.1,z),"rock")
	for x in [-1.1,1.1]: Kit.box(self,"ShaftSide",Vector3(0.2,6.9,2.2),Vector3(x,-2.55,8),"crust")
	Kit.box(self,"ShaftRear",Vector3(2.2,6.9,0.2),Vector3(0,-2.55,9.1),"crust")
	Kit.box(self,"ShaftFront",Vector3(2.2,3,0.2),Vector3(0,-1.5,6.9),"crust")
	for x in [-0.42,0.42]: Kit.box(self,"LadderRail",Vector3(0.08,6.0,0.08),Vector3(x,-3,8.65),"metal",false)
	for i in 19: Kit.box(self,"Rung",Vector3(0.9,0.05,0.08),Vector3(0,-5.8+i*0.3,8.65),"metal",false)
	hatch = Kit.box(self,"Hatch",Vector3(2,0.12,2),Vector3(0,-0.06,8),"metal")
	for upper in [true,false]:
		var y := 1.25 if upper else -4.75
		var control := Kit.box(self,"HatchControl",Vector3(0.35,0.3,0.12),Vector3(0.72,y,6.85),"metal")
		var use := Interaction.new()
		use.name = "Interaction"
		use.display_name = "Sealed rail access / climb " + ("down" if upper else "up")
		control.add_child(use)
		use.used.connect(func(_target): passenger.start_climb(upper))
	for z in [0,-10]:
		var light := OmniLight3D.new()
		light.position = Vector3(0,-3.2,z)
		light.light_color = Color(0.72,0.85,0.69)
		light.omni_range = 12
		light.light_energy = 0
		add_child(light)
		lights.append(light)
	var sign := Label3D.new()
	sign.text = "14 / UNDERGROUND RAIL\nSEALED SERVICE ACCESS"
	sign.position = Vector3(0,2.0,6.82)
	sign.rotation.y = PI
	sign.pixel_size = 0.0025
	sign.font_size = 32
	add_child(sign)
func set_open(opened: bool) -> void:
	var breaches: Node = passenger.get_parent().get_node_or_null("Breaches")
	if breaches!=null: opened = opened or breaches.entrances.get("service_hatch",{}).get("forced",false)
	hatch.position = Vector3(0,0.95,9) if opened else Vector3(0,-0.06,8)
	hatch.rotation.x = PI/2 if opened else 0.0
	hatch.get_child(1).disabled = opened
func light_step(fraction: float) -> void:
	for light in lights: light.light_energy = 1.2*fraction
