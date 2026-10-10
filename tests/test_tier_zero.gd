extends GutTest

var world: Node
var mule: Node


func before_each() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	mule = world.get_node("Fleet").drone("mule_01")
	mule.deployed = true
	mule.position = Vector3(0,0.02,-25)
	await wait_physics_frames(3)


func after_each() -> void:
	await wait_process_frames(2)


func test_sonar_is_ping_refreshed_and_hardware_gated() -> void:
	var sonar: Node = mule.get_node("Sonar")
	assert_true(sonar.ping())
	assert_gt(sonar.echoes.size(),0,"Real pylon/rubble/boundary returns")
	var echoes: Array = sonar.echoes.duplicate()
	assert_false(sonar.ping(),"Cooldown prevents sampling every frame")
	mule.position.z = -80.0
	await wait_physics_frames(5)
	assert_eq(sonar.echoes,echoes,"Moving never grants a new sonar map without ping")
	sonar.clock += 3.0
	assert_true(sonar.ping())
	assert_ne(sonar.echoes,echoes)
	sonar.clock += 9.0
	sonar._physics_process(0.0)
	assert_true(sonar.echoes.is_empty())
	mule.remove_module("sensor_a")
	assert_false(sonar.ping())
	assert_eq(mule.find_children("*","Camera3D",true,false).size(),0,"Blind hull has no ordinary optical camera")


func test_ir_returns_heat_without_identity_and_respects_occlusion() -> void:
	mule.position = Vector3(9,0.02,-32)
	await wait_physics_frames(2)
	var thermal: Node = mule.get_node("Thermal")
	var readings: Array = thermal.sample()
	assert_eq(readings.size(),1,"Warm vent, cold pylons do not expose ordinary geometry")
	assert_false(readings[0].has("id"))
	var wall: Node = load("res://scripts/world/surface_kit.gd").box(world.get_node("Surface"),"TestOccluder",Vector3(5,3,1),Vector3(9,1.5,-40),"rock")
	await wait_physics_frames(2)
	assert_true(thermal.sample().is_empty(),"Concrete hides the heat return")
	wall.queue_free()
	mule.remove_module("sensor_b")
	assert_true(thermal.sample().is_empty())
