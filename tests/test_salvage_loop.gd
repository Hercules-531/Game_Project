extends GutTest

var world: Node
var mule: Node
var salvage: Node

func before_each() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	mule = world.get_node("Fleet").drone("mule_01")
	salvage = world.get_node("Salvage")
	await wait_physics_frames(2)

func after_each() -> void:
	await wait_process_frames(2)

func test_salvage_payload_delivery_and_repeated_unload_conserve_resources() -> void:
	assert_false(salvage.recover_nearest(mule))
	mule.deployed = true
	mule.position = Vector3(-3,0.02,-46)
	mule.cargo_kg = 80.0
	assert_false(salvage.recover_nearest(mule))
	mule.cargo_kg = 0.0
	assert_true(salvage.recover_nearest(mule))
	assert_eq(mule.cargo_kg,24.0)
	assert_eq(world.get_node("Inventory").scrap,80,"Pickup grants no stock")
	assert_false(salvage.recover_nearest(mule))
	assert_eq(salvage.deliver(mule),0,"Field cannot unload into bunker")
	mule.position = Vector3(-2,0.02,-14)
	var control: Node = world.get_node("FleetControl")
	assert_true(control.request_transfer(false))
	control.advance_transfer(8.0)
	assert_eq(world.get_node("Inventory").scrap,96)
	assert_eq(mule.cargo_kg,0.0)
	assert_eq(salvage.deliver(mule),0)
	assert_eq(world.get_node("Inventory").scrap,96)

func test_carried_save_and_stock_supply_delivery_survive_reload() -> void:
	var hover: Node = world.get_node("Fleet").drone("hover_01")
	hover.deployed = true
	hover.position = Vector3(12,0.02,-75)
	assert_true(salvage.recover_nearest(hover))
	var schema = load("res://scripts/persistence/save_schema.gd")
	var data: Dictionary = JSON.parse_string(JSON.stringify(schema.capture(world)))
	assert_eq(schema.validate(data),"")
	schema.restore(world,data)
	hover = world.get_node("Fleet").drone("hover_01")
	assert_eq(hover.cargo_kg,10.0)
	assert_eq(salvage.items.fuel_01.state,"carried")
	hover.deployed = false
	hover.position = Vector3(-4,0.02,0.8)
	assert_eq(salvage.deliver(hover),1)
	assert_eq(world.get_node("Inventory").fuel,80.0)
	assert_eq(salvage.deliver(hover),0)
	data.salvage[1].carrier = "missing"
	assert_ne(schema.validate(data),"")
