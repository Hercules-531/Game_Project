extends GutTest
const Schema = preload("res://scripts/persistence/save_schema.gd")
const RailModel = preload("res://scripts/rail/rail_network.gd")
var session: Node
var w: Node
var rail: Node
var life: Node
var inv: Node
func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/rail_power_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	w = session.world
	rail = w.get_node("Rail")
	life = w.get_node("LifeSupport")
	inv = w.get_node("Inventory")
	for node in [rail,life,w.get_node("Territory"),w.get_node("DronePower"),w.get_node("Fabrication"),w.get_node("Weather"),w.get_node("Trace")]: node.set_physics_process(false)
	await wait_physics_frames(2)
func after_each() -> void:
	InputContext.menu_locked = false
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func connect_tunnels(count: int = 1) -> void:
	var territory: Node = w.get_node("Territory")
	for i in range(1,count+1):
		territory.sites[i].held = true
		territory.sites[i].pylon = true
	var state := {"segments":[],"rooms":{},"jobs":{},"next_serial":1}
	for i in count: state.segments.append({"kind":"tunnel","source":i,"target":i+1,"width":4.0,"depth":6.0,"height":2.4})
	w.get_node("Excavation").restore(state)
	rail.sync()
func unlock() -> void:
	for id in ["recovery","network","heavy","excavation"]:
		w.get_node("Research").completed.append(id)
		w.get_node("Research").archives[id] = {"state":"delivered","carrier":""}
func dark() -> void:
	life.generator_on = false
	life.fuel = 0
	life.battery = 0
	life.aux_generation_kw = 0
	life.artifact_aux_kw = 0
func test_finished_tunnels_commission_tracks_stations_distinct_depots_and_wires() -> void:
	assert_eq(rail.hub_count(),0)
	assert_null(rail.stock(0))
	assert_false(rail.construct_car())
	var scrap: int = inv.scrap
	connect_tunnels(2)
	assert_eq(rail.hub_count(),3)
	assert_eq(rail.stations.size(),3)
	assert_eq(rail.stocks.size(),2)
	assert_eq(inv.scrap,scrap,"Existing lining already paid for rails")
	assert_same(rail.stock(0),inv)
	rail.stock(1).scrap = 9
	assert_eq(rail.stock(2).scrap,0)
	assert_eq(inv.scrap,scrap)
	assert_almost_eq(life.rail_load_kw,0.14,0.00000001,"Three station lamps plus four service-chase lamps")
	assert_eq(rail.stations[2].position.y,-6.0)
	assert_eq(rail.geometry.get_child_count(),5,"Two routes and three stations")
	rail.sync()
	assert_eq(rail.stock(1).scrap,9)
	w.get_node("Radio").drops = {"pylon_1":100.0,"pylon_2":100.0}
	assert_true(rail.connected(2),"Wireless dropout never controls wired paths")
	for weather in ["smog","ash","rain","aurora"]:
		w.get_node("Weather").current = weather
		assert_true(rail.connected(2),"Healthy wire holds through "+weather)
	rail.conditions["0"] = 0.0
	assert_false(rail.connected(1))
	assert_false(rail.connected(2))
	assert_true(rail.wired(2),"A broken track does not cut independent conduit")
	rail.prepare()
	assert_almost_eq(life.rail_load_kw,0.14,0.00000001)
func test_car_requires_research_one_payment_and_fresh_fractional_grid_work() -> void:
	connect_tunnels()
	assert_false(rail.construct_car())
	unlock()
	assert_true(rail.construct_car())
	assert_eq(inv.scrap,40)
	assert_false(rail.construct_car())
	dark()
	life.supplied_fraction = 1
	life.advance(3)
	assert_eq(rail.car_remaining,120.0,"Stale fraction cannot fund construction")
	assert_eq(rail.stations[0].get_node("Light").light_energy,0.0)
	life.battery = life.load_kw()/3600.0*0.5
	life.advance(1)
	assert_almost_eq(rail.car_remaining,119.5,0.000001)
	assert_almost_eq(rail.stations[0].get_node("Light").light_energy,0.9,0.000001)
	life.battery = 2
	life.advance(119)
	assert_false(rail.car_built)
	life.advance(1)
	assert_true(rail.car_built)
	assert_not_null(rail.car_view)
	assert_eq(rail.car_remaining,0.0)
	assert_eq(inv.scrap,40)
	var view: Node = rail.car_view
	life.advance(4)
	assert_same(rail.car_view,view,"Completion never duplicates car")
	assert_almost_eq(life.rail_load_kw,0.08,0.00000001)
func test_portable_factory_empty_identity_and_fresh_power() -> void:
	var factory: Node = w.get_node("Fabrication")
	assert_false(factory.start("portable_cell"))
	unlock()
	assert_true(factory.start("portable_cell"))
	assert_eq(inv.scrap,72)
	assert_false(factory.start("portable_cell"))
	dark()
	life.supplied_fraction = 1
	factory.advance(100)
	life.advance(3)
	assert_eq(factory.job.remaining,45.0)
	assert_eq(inv.cells.size(),0)
	life.battery = 2
	life.advance(45)
	assert_true(factory.job.is_empty())
	assert_eq(inv.cells.size(),1)
	assert_eq(inv.cells[0].charge,0.0,"Manufacturing creates empty storage, no energy")
	assert_eq(inv.cells[0].serial,1)
	assert_eq(inv.next_cell_serial,2)
	assert_true(factory.start("portable_cell"))
	life.advance(45)
	assert_eq(inv.cells.size(),2)
	assert_eq(inv.cells[1].serial,2)
	assert_eq(inv.cells[1].charge,0.0)
func test_pack_charging_caps_total_load_and_conserves_partial_payment() -> void:
	connect_tunnels()
	inv.add_cell()
	inv.add_cell()
	inv.cells[0].charge = 1.0-0.0001
	rail.set_charging(true)
	assert_almost_eq(life.rail_load_kw,1.08,0.00000001)
	dark()
	life.supplied_fraction = 1
	life.advance(2)
	assert_almost_eq(inv.cells[0].charge,0.9999,0.00000001)
	var before: float = inv.cells[0].charge+inv.cells[1].charge
	var demand: float = life.load_kw()/3600.0
	life.battery = demand*0.5
	life.advance(1)
	assert_almost_eq(inv.cells[0].charge+inv.cells[1].charge-before,0.5/3600.0,0.000000001)
	assert_almost_eq(life.battery,0.0,0.00000001)
	life.battery = 2
	life.advance(2)
	assert_eq(inv.cells[0].charge,1.0)
	inv.cells[1].charge = 1.0-0.00001
	rail.prepare()
	assert_almost_eq(life.rail_load_kw,0.116,0.00000001)
	life.advance(1)
	assert_eq(inv.cells[1].charge,1.0)
	assert_almost_eq(life.rail_load_kw,0.08,0.00000001)
	rail.set_charging(false)
	assert_eq(rail.charge_requests.size(),0)
func test_field_pack_transfer_keeps_identity_residual_and_efficiency() -> void:
	connect_tunnels()
	inv.add_cell()
	var pack: Dictionary = inv.cells.pop_back()
	pack.charge = 1.0
	var depot: Node = rail.stock(1)
	depot.cells.append(pack)
	w.get_node("Territory").sites[1].battery = 11.55
	assert_false(rail.feed_pylon(0,1))
	assert_false(rail.feed_pylon(2,1))
	assert_true(rail.feed_pylon(1,1))
	assert_almost_eq(pack.charge,0.5,0.000001)
	assert_eq(w.get_node("Territory").sites[1].battery,12.0)
	assert_false(rail.feed_pylon(1,1))
	w.get_node("Territory").sites[1].battery = 0
	assert_true(rail.feed_pylon(1,1))
	assert_almost_eq(w.get_node("Territory").sites[1].battery,0.45,0.000001)
	assert_eq(depot.cells.size(),1)
	assert_eq(pack.serial,1)
	assert_almost_eq(pack.charge,0.0,0.000001)
	assert_false(rail.feed_pylon(1,1))
func test_save_rejects_stock_duplicates_and_restores_paid_construction_without_credit() -> void:
	connect_tunnels()
	unlock()
	inv.add_cell()
	inv.cells[0].charge = 0.25
	rail.stock(1).add_part("sonar",65.0)
	assert_true(rail.construct_car())
	life.advance(9)
	var data := Schema.capture(w)
	assert_eq(Schema.validate(data),"")
	var bad := data.duplicate(true)
	bad.rail.stocks["1"].parts.append(bad.inventory.parts[0].duplicate())
	assert_false(Schema.validate(bad).is_empty())
	bad = data.duplicate(true)
	bad.rail.stocks["1"].cells.append(bad.inventory.cells[0].duplicate())
	assert_false(Schema.validate(bad).is_empty())
	bad = data.duplicate(true)
	bad.rail.stocks["1"].cells.append({"serial":999,"charge":0.2})
	assert_false(Schema.validate(bad).is_empty())
	assert_true(session.save_current())
	assert_true(session.continue_game())
	w = session.world
	rail = w.get_node("Rail")
	life = w.get_node("LifeSupport")
	inv = w.get_node("Inventory")
	assert_eq(rail.car_remaining,111.0)
	assert_eq(inv.scrap,40)
	assert_eq(inv.cells[0].charge,0.25)
	assert_eq(rail.stock(1).parts[0].condition,65.0)
	assert_eq(rail.stations[0].get_node("Light").light_energy,0.0,"Restoring a saved fraction cannot illuminate for free")
	assert_false(rail.construct_car())
	assert_almost_eq(life.rail_load_kw,0.68,0.00000001)
func test_legacy_tunnel_migration_and_terminal_fit() -> void:
	connect_tunnels()
	var data := Schema.capture(w)
	data.version = 29
	data.erase("rail")
	data.inventory.erase("cells")
	data.inventory.erase("next_cell_serial")
	assert_eq(Schema.validate(data),"")
	Schema.restore(w,data)
	assert_eq(rail.hub_count(),2)
	assert_eq(rail.stock(1).scrap,0)
	assert_false(rail.car_built)
	assert_eq(inv.scrap,80)
	assert_true(inv.cells.is_empty())
	var ui: Node = w.get_node("RailPanel")
	ui.open()
	await wait_process_frames(3)
	assert_lte(ui.panel.get_combined_minimum_size().x,640.0)
	assert_lte(ui.panel.get_combined_minimum_size().y,480.0)
	var rows: Node = ui.build_button.get_parent()
	assert_lte(rows.get_child(-1).get_global_rect().end.y,480.0)
func test_same_step_completion_commissions_before_save_and_malformed_packs_fail() -> void:
	var dig: Node = w.get_node("Excavation")
	w.get_node("Territory").sites[1].held = true
	# Reproduce completion's signal order: update plan, notify, rebuild, changed.
	dig.segments.append({"kind":"tunnel","source":0,"target":1,"width":4.0,"depth":6.0,"height":2.4})
	dig.completed.emit("tunnel",0,1)
	dig.grid = dig.Plan.grid(dig.segments,dig.rooms)
	dig.geometry.rebuild(dig.grid)
	dig.changed.emit()
	assert_eq(rail.hub_count(),2)
	assert_eq(rail.stocks.size(),1)
	assert_eq(Schema.validate(Schema.capture(w)),"","Save in the completion step includes newly commissioned stock")
	var data := Schema.capture(w)
	data.inventory.cells = [{"serial":1,"charge":1.01}]
	data.inventory.next_cell_serial = 2
	assert_false(Schema.validate(data).is_empty())
	data.inventory.cells[0].charge = -0.01
	assert_false(Schema.validate(data).is_empty())
	data.inventory.cells[0].charge = NAN
	assert_false(Schema.validate(data).is_empty())
	data.inventory.cells[0].charge = 0.0
	data.inventory.cells[0].serial = 1.5
	assert_false(Schema.validate(data).is_empty())
