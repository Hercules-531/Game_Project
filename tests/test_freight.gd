extends GutTest
const Schema = preload("res://scripts/persistence/save_schema.gd")
var session: Node
var w: Node
var rail: Node
var f: Node
var inv: Node
var life: Node
func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/freight_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	w = session.world
	for n in w.get_children(): n.set_physics_process(false)
	rail = w.get_node("Rail")
	f = rail.freight
	inv = w.get_node("Inventory")
	life = w.get_node("LifeSupport")
	for i in [1,2]:
		w.get_node("Territory").sites[i].held = true
		w.get_node("Territory").sites[i].pylon = true
		w.get_node("Territory").sites[i].fob = true
	var segments: Array = []
	for i in 2: segments.append({"kind":"tunnel","source":i,"target":i+1,"width":6.0,"depth":6.0,"height":3.2})
	w.get_node("Excavation").restore({"segments":segments,"rooms":{},"jobs":{},"next_serial":1})
	rail.car_built = true
	rail.sync()
	life.generator_on = false
	life.fuel = 0
	life.battery = 2
	await wait_physics_frames(2)
func after_each() -> void:
	InputContext.menu_locked = false
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func tick(seconds: int = 1) -> void:
	for _i in seconds:
		f.advance(1)
		rail.prepare()
		life.advance(1)
func until_idle(limit: int = 400) -> void:
	for _i in limit:
		tick()
		if f.job.is_empty(): return
	assert_true(false,"Freight must arrive, not only launch")
func test_scrap_physically_moves_with_exact_paid_motor_draw_and_no_repeat_credit() -> void:
	assert_true(f.add_rule(0,1,"scrap",10,10))
	var before: float = life.battery
	f.advance(1)
	rail.prepare()
	var demand: float = life.load_kw()
	assert_almost_eq(rail.life.rail_load_kw,1.56,0.00000001,"Motor 1.5kW plus three station lights")
	life.advance(1)
	assert_eq(inv.scrap,70)
	assert_eq(rail.stock(1).scrap,0)
	assert_eq(f.coordinate,0.0,"No motion before the first real grid payment")
	assert_eq(f.job.cargo.amount,10.0)
	assert_almost_eq(before-life.battery,demand/3600.0,0.00000001)
	f.advance(0.25)
	assert_almost_eq(f.coordinate,0.5,0.000001)
	assert_almost_eq(f.credit,0.75,0.000001)
	assert_almost_eq(rail.car_view.position.distance_to(rail.at(0)+Vector3(0,0.15,0)),0.5,0.00001)
	until_idle()
	assert_eq(rail.stock(1).scrap,10)
	assert_eq(inv.scrap,70)
	assert_almost_eq(f.coordinate,f.distance_to_hub(1),0.00001)
	tick(5)
	assert_eq(rail.stock(1).scrap,10)
	assert_eq(inv.scrap,70)
func test_rations_fuel_and_specific_spares_keep_quantity_identity_and_condition() -> void:
	assert_true(f.add_rule(0,1,"rations",3,3))
	until_idle()
	assert_eq(inv.rations,1.0)
	assert_eq(rail.stock(1).rations,3.0)
	assert_true(f.add_rule(0,2,"fuel",5,5))
	until_idle()
	assert_eq(inv.fuel,55.0)
	assert_eq(rail.stock(2).fuel,5.0)
	var part: Dictionary = inv.parts[1].duplicate()
	assert_true(f.add_rule(0,1,"part",1,1,"thermal"))
	until_idle()
	assert_eq(rail.stock(1).parts.size(),1)
	assert_eq(rail.stock(1).parts[0],part)
	assert_true(inv.part(int(part.serial)).is_empty())
	assert_eq(inv.parts.size(),2)
	assert_eq(Schema.validate(Schema.capture(w)),"")
func test_charged_and_empty_pack_round_trip_can_recharge_without_creating_energy() -> void:
	inv.add_cell()
	inv.cells[0].charge = 1.0
	assert_true(f.add_rule(0,1,"charged",1,1))
	until_idle()
	assert_true(inv.cells.is_empty())
	assert_eq(rail.stock(1).cells[0],{"serial":1,"charge":1.0})
	w.get_node("Territory").sites[1].battery = 0
	rail.auto_feed["1"] = true
	rail._physics_process(0.01)
	assert_almost_eq(w.get_node("Territory").sites[1].battery,0.9,0.000001)
	assert_eq(rail.stock(1).cells[0].charge,0.0)
	assert_true(f.add_rule(1,0,"empty",1,1))
	until_idle()
	assert_eq(inv.cells[0],{"serial":1,"charge":0.0})
	assert_true(rail.stock(1).cells.is_empty())
	f.toggle_rule(1)
	f.toggle_rule(2)
	rail.set_charging(true)
	life.battery = 2
	tick(10)
	assert_almost_eq(inv.cells[0].charge,10.0/3600.0,0.00000001)
	assert_eq(inv.next_cell_serial,2)
func test_approach_source_does_not_teleport_supply_and_empty_source_does_not_deadlock() -> void:
	rail.stock(2).scrap = 8
	assert_true(f.add_rule(2,1,"scrap",8,8))
	tick(2)
	assert_eq(f.job.phase,"source")
	assert_eq(rail.stock(2).scrap,8)
	assert_lt(f.coordinate,f.distance_to_hub(2))
	rail.stock(2).scrap = 0
	tick(120)
	assert_true(f.job.is_empty())
	assert_eq(rail.stock(1).scrap,0)
	assert_true(f.add_rule(0,1,"scrap",5,5))
	until_idle()
	assert_eq(rail.stock(1).scrap,5)
func test_blackout_stops_after_paid_reserve_and_wireless_weather_cannot_cut_trip() -> void:
	assert_true(f.add_rule(0,1,"scrap",10,10))
	tick()
	life.battery = 0
	life.supplied_fraction = 1
	f.advance(1)
	rail.prepare()
	life.advance(5)
	var at: float = f.coordinate
	f.advance(10)
	assert_eq(f.coordinate,at)
	assert_eq(f.credit,0.0)
	assert_eq(rail.stock(1).scrap,0)
	life.battery = 2
	w.get_node("Weather").current = "aurora"
	w.get_node("Radio").drops = {"pylon_1":1000.0,"pylon_2":1000.0}
	until_idle()
	assert_eq(rail.stock(1).scrap,10)
func test_full_destination_holds_loaded_goods_even_after_rule_is_disabled() -> void:
	assert_true(f.add_rule(0,1,"scrap",10,10))
	tick()
	rail.stock(1).scrap = 1000000
	assert_true(f.toggle_rule(1))
	tick(70)
	assert_eq(f.job.phase,"delivery")
	assert_eq(f.job.cargo.amount,10.0)
	assert_eq(inv.scrap,70)
	assert_eq(rail.stock(1).scrap,1000000)
	rail.stock(1).scrap -= 10
	f.advance(0.1)
	assert_true(f.job.is_empty())
	assert_eq(rail.stock(1).scrap,1000000)
	tick(5)
	assert_eq(inv.scrap,70)
func test_mid_trip_reload_preserves_cargo_credit_position_and_global_identity() -> void:
	inv.add_cell()
	inv.cells[0].charge = 1.0
	assert_true(f.add_rule(0,1,"charged",1,1))
	tick(12)
	f.advance(0.25)
	rail.prepare()
	var data := Schema.capture(w)
	assert_eq(Schema.validate(data),"")
	var at: float = f.coordinate
	var credit: float = f.credit
	var bad := data.duplicate(true)
	bad.inventory.cells.append(bad.rail.freight.job.cargo.cells[0].duplicate())
	assert_false(Schema.validate(bad).is_empty())
	bad = data.duplicate(true)
	bad.rail.freight.credit = 1.01
	assert_false(Schema.validate(bad).is_empty())
	bad = data.duplicate(true)
	bad.rail.freight.job.cargo.cells[0].charge = -1
	assert_false(Schema.validate(bad).is_empty())
	assert_true(session.save_current())
	assert_true(session.continue_game())
	w = session.world
	for n in w.get_children(): n.set_physics_process(false)
	rail = w.get_node("Rail")
	f = rail.freight
	life = w.get_node("LifeSupport")
	inv = w.get_node("Inventory")
	assert_almost_eq(f.coordinate,at,0.000001)
	assert_almost_eq(f.credit,credit,0.00000001)
	assert_eq(int(f.job.cargo.cells[0].serial),1)
	assert_eq(f.job.cargo.cells[0].charge,1.0)
	assert_true(inv.cells.is_empty())
	until_idle()
	assert_eq(rail.stock(1).cells.size(),1)
	assert_eq(int(rail.stock(1).cells[0].serial),1)
	assert_eq(Schema.validate(Schema.capture(w)),"")
func test_field_unload_service_and_repair_use_only_nearby_fob_stock() -> void:
	var d: Node = w.get_node("Fleet").drone("mule_01")
	d.deployed = true
	d.position = w.get_node("Territory").pad(1)+Vector3(2,0,0)
	var item: Node = w.get_node("Salvage").items["scrap_01"]
	item.state = "carried"
	item.carrier_id = d.identity
	d.cargo_kg = item.definition.mass
	var depot: Node = rail.stock(1)
	assert_eq(rail.unload_drone(d.identity),1)
	assert_eq(depot.scrap,int(item.definition.amount))
	assert_eq(inv.scrap,80)
	assert_eq(rail.unload_drone(d.identity),0)
	assert_eq(d.cargo_kg,0.0)
	depot.add_part("thermal",55.0)
	var workshop: Node = w.get_node("Workshop")
	assert_true(workshop.remove(d.identity,"sensor_b"))
	assert_eq(inv.parts.size(),3)
	assert_true(workshop.fit(d.identity,"sensor_b",int(depot.parts[0].serial)))
	assert_eq(d.condition.sensor_b,55.0)
	var before: int = depot.scrap
	assert_true(workshop.repair(d.identity,"sensor_b"))
	assert_eq(depot.scrap,before-9)
	assert_eq(inv.scrap,80)
	d.position.x += 20
	assert_false(workshop.remove(d.identity,"sensor_b"))
	assert_eq(rail.unload_drone(d.identity),0)
	d.position = w.get_node("Territory").pad(1)
	w.get_node("Territory").sites[1].fob = false
	assert_false(workshop.remove(d.identity,"sensor_b"))
	assert_eq(Schema.validate(Schema.capture(w)),"")
func test_capacity_mass_rule_limits_and_terminal_fit() -> void:
	assert_false(f.add_rule(0,0,"scrap",10,10))
	assert_false(f.add_rule(0,3,"scrap",10,10))
	assert_false(f.add_rule(0,1,"unknown",10,10))
	assert_false(f.add_rule(0,1,"part",1,1,"missing"))
	for _i in 25:
		inv.add_cell()
		inv.cells.back().charge = 1.0
	assert_true(f.add_rule(0,1,"charged",25,100))
	tick()
	assert_eq(f.job.cargo.cells.size(),20,"200kg physical load limit")
	assert_eq(inv.cells.size(),5)
	var ui: Node = w.get_node("FreightPanel")
	ui.open()
	await wait_process_frames(3)
	assert_lte(ui.panel.get_combined_minimum_size().x,640.0)
	assert_lte(ui.panel.get_combined_minimum_size().y,480.0)
	assert_lte(ui.panel.get_child(0).get_child(0).get_child(-1).get_global_rect().end.y,480.0)
	w.get_node("FleetPanel").open()
	w.get_node("RailPanel").open()
	ui.open()
	for button in ui.panel.find_children("*","Button",true,false):
		if button.text=="OPEN FIT / REPAIR USING HULL'S LOCAL STOCK": button.pressed.emit()
	assert_false(w.get_node("FleetPanel").panel.visible,"Fleet overlay must not cover the lower-layer workshop")
	assert_false(w.get_node("RailPanel").panel.visible)
	assert_false(ui.panel.visible)
	assert_true(w.get_node("WorkshopPanel").panel.visible)
func test_auto_unload_stripped_parts_and_archive_exclusion() -> void:
	var d: Node = w.get_node("Fleet").drone("mule_01")
	d.deployed = true
	d.position = w.get_node("Territory").pad(1)
	var rec: Node = w.get_node("Recovery")
	var record: Dictionary = rec.records["derelict_01"]
	record.state = "parts"
	record.owner = d.identity
	record.parts = [{"id":"sonar","condition":45.0}]
	d.cargo_kg = 21
	var research: Node = w.get_node("Research")
	research.archives.recovery = {"state":"carried","carrier":d.identity}
	rail.auto_unload["1"] = true
	rail._physics_process(0.01)
	assert_eq(rail.stock(1).parts.size(),1)
	assert_eq(rail.stock(1).parts[0].condition,45.0)
	assert_eq(inv.parts.size(),3)
	assert_eq(d.cargo_kg,1.0)
	assert_eq(research.archives.recovery.state,"carried","Knowledge still needs its explicit home recovery")
	rail._physics_process(0.01)
	assert_eq(rail.stock(1).parts.size(),1)
	assert_eq(Schema.validate(Schema.capture(w)),"")
func test_full_pack_store_holds_delivery_and_pending_factory_output() -> void:
	inv.add_cell()
	inv.cells[0].charge = 1.0
	assert_true(f.add_rule(0,1,"charged",1,1))
	tick()
	for _i in 128:
		inv.add_cell()
		rail.stock(1).cells.append(inv.cells.pop_back())
	tick(70)
	assert_eq(f.job.cargo.cells.size(),1)
	assert_eq(rail.stock(1).cells.size(),128)
	var pack: Dictionary = rail.stock(1).cells.pop_back()
	inv.cells.append(pack)
	f.advance(0.1)
	assert_true(f.job.is_empty())
	assert_eq(rail.stock(1).cells.size(),128)
	var factory: Node = w.get_node("Fabrication")
	for id in ["recovery","network","heavy","excavation"]:
		w.get_node("Research").completed.append(id)
		w.get_node("Research").archives[id] = {"state":"delivered","carrier":""}
	assert_true(factory.start("portable_cell"))
	# Fill home after the paid job starts, as returning freight can do.
	for _i in 127: inv.cells.append(rail.stock(1).cells.pop_back())
	life.battery = 2
	life.advance(45)
	assert_eq(inv.cells.size(),128)
	assert_eq(factory.job.remaining,45.0)
	inv.cells.pop_back()
	life.advance(45)
	assert_true(factory.job.is_empty())
	assert_eq(inv.cells.size(),128)
	assert_eq(inv.cells.back().charge,0.0)
func test_v30_migration_keeps_stocks_without_freight_or_free_motor_credit() -> void:
	var data := Schema.capture(w)
	data.version = 30
	data.rail.erase("freight")
	data.rail.erase("auto_feed")
	data.rail.erase("auto_unload")
	assert_eq(Schema.validate(data),"")
	Schema.restore(w,data)
	assert_true(f.rules.is_empty())
	assert_true(f.job.is_empty())
	assert_eq(f.credit,0.0)
	assert_eq(inv.scrap,80)
	assert_eq(rail.stock(1).scrap,0)
func test_disabling_empty_approach_stops_new_loading_without_teleporting_car() -> void:
	rail.stock(2).scrap = 8
	assert_true(f.add_rule(2,1,"scrap",8,8))
	tick(2)
	var at: float = f.coordinate
	assert_gt(at,0.0)
	assert_true(f.toggle_rule(1))
	assert_true(f.job.is_empty())
	assert_eq(f.coordinate,at)
	tick(5)
	assert_eq(f.coordinate,at)
	assert_eq(rail.stock(2).scrap,8)
	assert_eq(rail.stock(1).scrap,0)
