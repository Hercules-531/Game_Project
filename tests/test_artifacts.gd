extends GutTest
const Schema = preload("res://scripts/persistence/save_schema.gd")
const Scene = preload("res://scenes/drones/drone.tscn")
const Router = preload("res://scripts/sensors/sensor_router.gd")
var s: Node
var w: Node
var artifacts: Node
var mule: Node
var power: Node
var life: Node
func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	process_mode = Node.PROCESS_MODE_ALWAYS
	s = load("res://scenes/ui/main_menu.tscn").instantiate()
	s.save_path = "user://tests/artifacts_%d.json" % Time.get_ticks_usec()
	add_child_autofree(s)
	s.new_game()
	w = s.world
	artifacts = w.get_node("Artifacts")
	mule = w.get_node("Fleet").drone("mule_01")
	power = w.get_node("DronePower")
	life = w.get_node("LifeSupport")
	for node in [power,life,w.get_node("Orders"),w.get_node("Trace"),w.get_node("Weather")]: node.set_physics_process(false)
	w.get_node("Radio").dropout_chance = 0.0
	await wait_physics_frames(2)
func after_each() -> void:
	InputContext.menu_locked = false
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func available(id: String) -> void:
	artifacts.devices[id] = {"state":"delivered","carrier":"","socket":""}
	artifacts._apply(id)
func heavy() -> Node:
	var g: Node = Scene.instantiate()
	g.identity = "artifact_goliath"
	g.hull_id = "goliath"
	g.battery = 0.2
	g.deployed = true
	g.position = Vector3(-4,0.02,-17)
	w.get_node("Fleet").add_child(g)
	return g
func test_real_retrieval_loader_finite_mass_unique_socket_and_save() -> void:
	var id := "thermal"
	mule.deployed = true
	mule.position = artifacts.DEFINITIONS[id].at+Vector3(0,0,2.2)
	await wait_physics_frames(2)
	assert_true(artifacts.recover_nearest(mule))
	assert_eq(mule.cargo_kg,1.0)
	assert_false(artifacts.fit(id,"bunker"),"Carried device is not yet workshop stock")
	assert_false(artifacts.recover_nearest(mule))
	var carried := JSON.parse_string(JSON.stringify(Schema.capture(w))) as Dictionary
	assert_eq(Schema.validate(carried),"")
	Schema.restore(w,carried)
	mule = w.get_node("Fleet").drone("mule_01")
	mule.position = Vector3(-2,0.02,-14)
	await wait_physics_frames(2)
	assert_true(w.get_node("FleetControl").request_machine_transfer(mule,false))
	w.get_node("FleetControl").advance_transfer(8)
	assert_eq(artifacts.devices[id].state,"delivered")
	assert_eq(mule.cargo_kg,0.0)
	var payload: float = mule.payload_remaining()
	assert_true(artifacts.fit(id,mule.identity))
	assert_eq(mule.payload_remaining(),payload-1.0)
	assert_false(artifacts.fit(id,"bunker"),"One device cannot occupy two sockets")
	available("neural")
	assert_false(artifacts.fit("neural",mule.identity),"One universal slot per hull")
	assert_true(artifacts.remove(mule.identity))
	assert_eq(mule.payload_remaining(),payload)
	assert_true(artifacts.fit(id,"bunker"))
	assert_eq(life.artifact_heat_multiplier,0.7)
	assert_true(s.save_current())
	assert_true(s.continue_game())
	w = s.world
	artifacts = w.get_node("Artifacts")
	life = w.get_node("LifeSupport")
	assert_eq(artifacts.fitted("bunker"),id)
	assert_eq(life.artifact_heat_multiplier,0.7,"Reload does not compound the effect")
	assert_eq(w.get_node("Inventory").scrap,80)
func test_thermal_small_silence_heavy_ten_meter_thaw_and_base_cost() -> void:
	available("thermal")
	mule.position = Vector3(20,0.02,-40)
	assert_true(artifacts.fit("thermal",mule.identity))
	mule.deployed = true
	mule.velocity = Vector3(1,0,0)
	var quiet_draw: float = power.required_kw(mule)
	assert_eq(w.get_node("Emissions").sound_reach(mule),0.0)
	mule.deployed = false
	assert_true(artifacts.remove(mule.identity))
	mule.deployed = true
	assert_gt(power.required_kw(mule),quiet_draw,"Small siphon removes cold draw")
	assert_gt(w.get_node("Emissions").sound_reach(mule),0.0)
	var g: Node = heavy()
	assert_true(artifacts.fit("thermal",g.identity))
	g.position = Vector3(20,0.02,-185)
	mule.position = g.position+Vector3(4,0,0)
	await wait_physics_frames(2)
	w.get_node("Emissions").source_frame = -1
	var thermal_source := false
	for source in w.get_node("Emissions").sources():
		thermal_source = thermal_source or (source.source==g.identity and source.kind=="heat" and source.reach==10.0)
	assert_true(thermal_source,"Stranded heavy siphon still emits its physical warmth")
	assert_true(artifacts.heat_at(g.position+Vector3(-10,0,0)))
	assert_false(artifacts.heat_at(g.position+Vector3(-10.01,0,0)))
	assert_eq(w.get_node("EnvironmentHazards").cold_multiplier(mule.position),0.0)
	assert_eq(w.get_node("EnvironmentHazards").frost_factor(mule.position),1.0)
	var wall := preload("res://scripts/world/surface_kit.gd").box(w.get_node("Surface"),"HeatBlock",Vector3(0.3,4,8),g.position+Vector3(2,2,0))
	await wait_physics_frames(2)
	assert_false(artifacts.heat_at(mule.position),"Heat cannot cross a concrete obstruction")
	wall.queue_free()
	g.position = Vector3(-4,0.02,-17)
	mule.position = Vector3(24,0.02,-185)
	await wait_physics_frames(2)
	assert_eq(w.get_node("EnvironmentHazards").frost_factor(mule.position),0.6)
	assert_true(artifacts.remove(g.identity))
	life.heater_on = false
	var base: float = life.load_kw()
	life.heater_on = true
	var heating: float = life.load_kw()-base
	assert_true(artifacts.fit("thermal","bunker"))
	assert_almost_eq(life.load_kw()-base,heating*0.7,0.00000001)
	assert_true(artifacts.remove("bunker"))
	assert_almost_eq(life.load_kw()-base,heating,0.00000001)
func test_neural_small_frames_heavy_pilot_and_triple_logic_without_motor_speed() -> void:
	available("neural")
	assert_eq(Router.tier(mule),0)
	assert_true(artifacts.fit("neural",mule.identity))
	assert_true(Router.neural(mule))
	mule.deployed = true
	mule.position = Vector3(20,0.02,-40)
	var ccd: Node = mule.get_node("CCD")
	ccd.set_physics_process(false)
	ccd.accumulator = 0.0
	var frames: int = ccd.frame_count
	for i in 60: ccd.advance(1.0/60.0)
	assert_eq(ccd.frame_count-frames,60,"Crisp artifact feed is not CCD-limited")
	mule.deployed = false
	assert_true(artifacts.remove(mule.identity))
	assert_eq(Router.tier(mule),0)
	var g: Node = heavy()
	assert_true(artifacts.fit("neural",g.identity))
	var bank: Node = Scene.instantiate()
	bank.identity = "neural_bank"
	bank.hull_id = "tender"
	bank.battery = 12.0
	bank.deployed = true
	bank.position = g.position+Vector3(0,0,3)
	assert_true(bank.install("utility","power_coupler"))
	w.get_node("Fleet").add_child(bank)
	await wait_physics_frames(2)
	assert_true(w.get_node("PowerTether").attach(g.identity,bank.identity))
	var control: Node = w.get_node("FleetControl")
	control.select(g.identity)
	control.panel_open = true
	control.piloting = true
	InputContext.set_context(InputContext.Context.TERMINAL)
	control.piloting = true
	control._physics_process(1.0/60.0)
	assert_true(control.piloting,"Heavy neural interface permits direct pilot input")
	assert_false(Router.neural(g),"Heavy effect does not grant a free clean sensor")
	control.stop_all()
	assert_true(artifacts.remove(g.identity))
	assert_false(artifacts.fit("neural","missing_machine"))
	var orders: Node = w.get_node("Orders")
	orders.decision_clock = 0.0
	var count: int = orders.decision_count
	for i in 60: orders._physics_process(1.0/60.0)
	var baseline: int = orders.decision_count-count
	assert_eq(baseline,12)
	var speed: float = mule.hull().speed
	assert_true(artifacts.fit("neural","bunker"))
	orders.decision_clock = 0.0
	count = orders.decision_count
	for i in 60: orders._physics_process(1.0/60.0)
	assert_eq(orders.decision_count-count,baseline*3)
	assert_eq(mule.hull().speed,speed,"Logic acceleration does not triple physical movement")
	assert_true(artifacts.remove("bunker"))
	assert_eq(orders.logic_rate,1.0)
func test_photonic_trickle_external_offset_and_independent_base_generation() -> void:
	available("photonic")
	assert_true(artifacts.fit("photonic",mule.identity))
	mule.deployed = true
	mule.position = Vector3(20,0.02,-40)
	mule.battery = 0.5
	var draw: float = power.required_kw(mule)
	power.advance(36)
	assert_almost_eq(mule.battery,0.5+(0.05-draw)*0.01,0.0000001)
	mule.deployed = false
	assert_true(artifacts.remove(mule.identity))
	var g: Node = heavy()
	var before: float = power.required_kw(g)
	assert_true(artifacts.fit("photonic",g.identity))
	assert_almost_eq(power.required_kw(g),before*0.8,0.0000001)
	assert_false(g.has_power(),"Partial photonic offset cannot replace an umbilical")
	assert_true(artifacts.remove(g.identity))
	assert_almost_eq(power.required_kw(g),before,0.0000001)
	assert_true(artifacts.fit("photonic","bunker"))
	life.generator_on = false
	life.battery = 1.0
	var demand: float = life.load_kw()
	life.advance(1)
	assert_almost_eq(life.battery,1.0+(0.25-demand)/3600.0,0.0000001)
	w.get_node("Solar")._update()
	assert_eq(life.artifact_aux_kw,0.25,"Solar updates cannot erase artifact generation")
	assert_true(artifacts.remove("bunker"))
	assert_eq(life.artifact_aux_kw,0.0)
func test_invalid_duplicate_missing_payload_migration_and_ui_fit() -> void:
	available("thermal")
	assert_true(artifacts.fit("thermal","bunker"))
	var data := Schema.capture(w)
	data.artifacts.neural = {"state":"fitted","carrier":"","socket":"bunker"}
	assert_ne(Schema.validate(data),"")
	data = Schema.capture(w)
	data.artifacts.thermal.socket = "missing_hull"
	assert_ne(Schema.validate(data),"")
	data = Schema.capture(w)
	data.artifacts.thermal.socket = "mule_01"
	data.fleet[0].cargo_kg = 81.0
	assert_ne(Schema.validate(data),"","Fitted artifact mass must also fit the hull")
	var old := Schema.capture(w)
	old.version = 26
	old.erase("artifacts")
	assert_eq(Schema.validate(old),"")
	var panel: Node = w.get_node("ArtifactPanel")
	panel.open()
	await wait_process_frames(2)
	assert_lte(panel.panel.get_combined_minimum_size().x,640.0)
	assert_lte(panel.panel.get_combined_minimum_size().y,480.0)
	var buttons: Array = panel.panel.find_children("*","Button",true,false)
	assert_lte(buttons.back().global_position.y+buttons.back().size.y,480.0)
	buttons.back().pressed.emit()
	assert_true(w.get_node("WorkshopPanel").panel.visible)
	w.get_node("WorkshopPanel").panel.hide()
	w.get_node("FleetPanel").open()
	await wait_process_frames(2)
	assert_lte(w.get_node("FleetPanel").panel.get_combined_minimum_size().x,640.0)
func test_each_breaker_effect_survives_repeated_restore_without_stacking() -> void:
	for id in ["thermal","neural","photonic"]:
		available(id)
		assert_true(artifacts.fit(id,"bunker"))
		var state := JSON.parse_string(JSON.stringify(Schema.capture(w))) as Dictionary
		assert_eq(Schema.validate(state),"")
		Schema.restore(w,state)
		Schema.restore(w,state)
		assert_eq(life.artifact_heat_multiplier,0.7 if id=="thermal" else 1.0)
		assert_eq(life.artifact_aux_kw,0.25 if id=="photonic" else 0.0)
		assert_eq(w.get_node("Orders").logic_rate,3.0 if id=="neural" else 1.0)
		assert_true(artifacts.remove("bunker"))
		assert_eq(life.artifact_heat_multiplier,1.0)
		assert_eq(life.artifact_aux_kw,0.0)
		assert_eq(w.get_node("Orders").logic_rate,1.0)
func test_actual_physics_frames_hold_twelve_thirtysix_and_fifteen_hz() -> void:
	var orders: Node = w.get_node("Orders")
	orders.set_physics_process(true)
	orders.decision_clock = 0.0
	var before: int = orders.decision_count
	await wait_physics_frames(120)
	assert_between(orders.decision_count-before,23,25,"Actual physics must not double-count near the interval boundary")
	available("neural")
	assert_true(artifacts.fit("neural","bunker"))
	orders.decision_clock = 0.0
	before = orders.decision_count
	await wait_physics_frames(120)
	assert_between(orders.decision_count-before,71,73)
	var hover: Node = w.get_node("Fleet").drone("hover_01")
	hover.deployed = true
	hover.position = Vector3(20,0.02,-40)
	var ccd: Node = hover.get_node("CCD")
	ccd.accumulator = 0.0
	before = ccd.frame_count
	await wait_physics_frames(120)
	assert_between(ccd.frame_count-before,29,31,"Original CCD stays at 15Hz in the real loop")
