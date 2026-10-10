extends GutTest

var world: Node
var radio: Node
var mule: Node


func before_each() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	radio = world.get_node("Radio")
	radio.set_physics_process(false)
	mule = world.get_node("Fleet").drone("mule_01")
	mule.deployed = true
	mule.position = Vector3(0,0.02,-80)
	await wait_physics_frames(3)


func test_distance_occlusion_and_seeded_dropouts() -> void:
	var clear: float = radio.quality(mule)
	assert_gt(clear,0.0)
	load("res://scripts/world/surface_kit.gd").box(world.get_node("Surface"),"RadioWall",Vector3(10,12,1),Vector3(0,6,-50),"rock")
	await wait_physics_frames(2)
	assert_lt(radio.quality(mule),clear)
	mule.position.z = -200.0
	assert_eq(radio.quality(mule),0.0)
	mule.position.z = -30.0
	radio.dropout_chance = 1.0
	radio.advance(12.0)
	assert_eq(radio.quality(mule),0.0)
	var saved: Dictionary = radio.snapshot()
	radio.advance(2.1)
	assert_gt(radio.quality(mule),0.0)
	radio.restore(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(radio.quality(mule),0.0,"Reload preserves active dropout")
	assert_eq(str(radio.rng.state),saved.rng)


func test_delayed_commands_expire_and_loss_cancels_pending_actions() -> void:
	var link = load("res://scripts/telemetry/command_link.gd").new()
	link.send("m",Vector2(0,-1),1.5)
	assert_eq(link.receive("m",true),Vector2.ZERO)
	link.advance(1.5)
	assert_eq(link.receive("m",true),Vector2(0,-1))
	link.advance(0.3)
	assert_eq(link.receive("m",true),Vector2.ZERO)
	link.send("m",Vector2(0,-1),1.5)
	link.send_action("m","camera",1.5)
	link.receive("m",false)
	link.advance(2.0)
	assert_eq(link.receive("m",true),Vector2.ZERO,"No old throttle after reconnect")
	assert_true(link.ready_actions().is_empty())
	var control: Node = world.get_node("FleetControl")
	mule.position.z = -200.0
	assert_false(control.request_action("camera"))
