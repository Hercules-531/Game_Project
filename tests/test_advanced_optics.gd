extends GutTest
const Schema = preload("res://scripts/persistence/save_schema.gd")
const Router = preload("res://scripts/sensors/sensor_router.gd")
const Kit = preload("res://scripts/world/surface_kit.gd")
var session: Node
var w: Node
var drone: Node
var optics: Node
func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/advanced_optics_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	w = session.world
	drone = w.get_node("Fleet").drone("mule_01")
	optics = drone.get_node("Multispectrum")
	for node in [w.get_node("LifeSupport"),w.get_node("DronePower"),w.get_node("Conditions")]: node.set_physics_process(false)
	w.get_node("Radio").dropout_chance = 0
	await wait_physics_frames(2)
func after_each() -> void:
	InputContext.menu_locked = false
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func fit() -> void:
	drone.remove_module("sensor_a")
	assert_true(drone.install("sensor_a","multispectrum"))
	drone.deployed = true
	drone.position = Vector3(20,0.02,-40)
	await wait_physics_frames(2)
func landmark(label: String, at: Vector3) -> Node3D:
	var body := Kit.box(w.get_node("Surface"),label,Vector3(0.5,1,0.5),at+Vector3(0,0.5,0))
	body.add_to_group("sensor_landmarks")
	body.set_meta("classification",label)
	return body
func has_class(tags: Array, label: String) -> bool:
	for tag in tags:
		if tag["class"]==label: return true
	return false
func test_earned_paid_fabrication_and_actual_hardware_power_cost() -> void:
	assert_false(w.get_node("Fabrication").start("multispectrum"))
	assert_eq(w.get_node("Inventory").scrap,80)
	for id in ["recovery","network","heavy","optics"]:
		w.get_node("Research").completed.append(id)
		w.get_node("Research").archives[id] = {"state":"delivered","carrier":""}
	var fabrication: Node = w.get_node("Fabrication")
	assert_true(fabrication.start("multispectrum"))
	assert_eq(w.get_node("Inventory").scrap,0)
	fabrication.advance(180)
	var serial := -1
	for part in w.get_node("Inventory").parts:
		if part.id=="multispectrum": serial = part.serial
	assert_gt(serial,0)
	assert_true(w.get_node("Workshop").remove(drone.identity,"sensor_a"))
	var before: float = drone.draw_kw()
	assert_true(w.get_node("Workshop").fit(drone.identity,"sensor_a",serial))
	assert_almost_eq(drone.draw_kw()-before,0.8,0.000001)
	assert_eq(Router.tier(drone),2)
	assert_eq(w.get_node("Inventory").scrap,0)
	assert_eq(Schema.validate(Schema.capture(w)),"")
func test_current_frustum_zoom_cover_range_and_hidden_tags() -> void:
	await fit()
	var front: Node3D = landmark("VISIBLE CACHE",Vector3(20,0.02,-50))
	var side: Node3D = landmark("SIDE EQUIPMENT",Vector3(26,0.02,-50))
	var behind: Node3D = landmark("BEHIND",Vector3(20,0.02,-30))
	var far: Node3D = landmark("TOO FAR",Vector3(20,0.02,-125))
	var hidden: Node3D = landmark("HIDDEN",Vector3(17,0.02,-51))
	hidden.hide()
	await wait_physics_frames(2)
	var tags: Array = optics.classifications()
	assert_true(has_class(tags,"VISIBLE CACHE"))
	assert_true(has_class(tags,"SIDE EQUIPMENT"))
	assert_false(has_class(tags,"BEHIND"))
	assert_false(has_class(tags,"TOO FAR"))
	assert_false(has_class(tags,"HIDDEN"))
	assert_true(optics.configure(true,4))
	tags = optics.classifications()
	assert_true(has_class(tags,"VISIBLE CACHE"))
	assert_false(has_class(tags,"SIDE EQUIPMENT"),"Zoom narrows the actual visible tags")
	for tag in tags:
		assert_true(Rect2(0,0,1,1).has_point(tag.uv))
	assert_true(optics.configure(false,1))
	var wall := Kit.box(w.get_node("Surface"),"OccludingWall",Vector3(3,3,0.3),Vector3(20,1.5,-46))
	await wait_physics_frames(2)
	assert_false(has_class(optics.classifications(),"VISIBLE CACHE"))
	wall.queue_free()
	front.queue_free()
	side.queue_free()
	behind.queue_free()
	far.queue_free()
func test_real_sixty_hz_fault_blackout_worn_lens_and_repair() -> void:
	await fit()
	var ccd: Node = drone.get_node("CCD")
	var before: int = ccd.frame_count
	await wait_physics_frames(60)
	assert_between(ccd.frame_count-before,59,61)
	drone.faults.sensor_a = 8
	before = ccd.frame_count
	await wait_physics_frames(5)
	assert_eq(ccd.frame_count,before,"Fault supplies no new frames")
	assert_true(optics.classifications().is_empty())
	drone.faults.clear()
	drone.condition.sensor_a = 10
	before = ccd.frame_count
	ccd.accumulator = 0
	await wait_physics_frames(120)
	assert_between(ccd.frame_count-before,41,43,"Worn lens runs at 35% efficiency")
	drone.deployed = false
	w.get_node("Inventory").scrap = 20
	assert_true(w.get_node("Workshop").repair(drone.identity,"sensor_a"))
	assert_lt(w.get_node("Inventory").scrap,20)
	assert_eq(drone.condition.sensor_a,100.0)
	drone.deployed = true
	drone.battery = 0
	before = ccd.frame_count
	await wait_physics_frames(5)
	assert_eq(ccd.frame_count,before)
	assert_true(optics.classifications().is_empty())
func test_packet_loss_removes_tags_and_modes_save_without_granting_hardware() -> void:
	await fit()
	landmark("CACHE",Vector3(20,0.02,-50))
	await wait_physics_frames(2)
	assert_true(optics.configure(true,2))
	var saved := JSON.parse_string(JSON.stringify(Schema.capture(w))) as Dictionary
	assert_eq(Schema.validate(saved),"")
	assert_true(session.save_current())
	assert_true(session.continue_game())
	w = session.world
	drone = w.get_node("Fleet").drone("mule_01")
	optics = drone.get_node("Multispectrum")
	assert_true(optics.night_vision)
	assert_eq(optics.zoom,2.0)
	w.get_node("Radio").drops[drone.identity] = 2
	assert_true(optics.classifications().is_empty())
	assert_false(optics.configure(false,4))
	var bad := saved.duplicate(true)
	bad.fleet[0].optics.zoom = 3
	assert_ne(Schema.validate(bad),"")
	bad = saved.duplicate(true)
	bad.fleet[0].erase("optics")
	assert_ne(Schema.validate(bad),"")
	var legacy := saved.duplicate(true)
	legacy.version = 27
	for record in legacy.fleet: record.erase("optics")
	assert_eq(Schema.validate(legacy),"")
	var hover: Node = w.get_node("Fleet").drone("hover_01")
	assert_eq(Router.tier(hover),1)
	assert_false(hover.get_node("Multispectrum").configure(true,4))
func test_actual_terminal_toggles_zoom_and_fits_without_neural_free_tags() -> void:
	await fit()
	var panel: Node = w.get_node("FleetPanel")
	panel.open()
	panel.night_vision.button_pressed = true
	panel.zoom.select(2)
	panel.zoom.item_selected.emit(2)
	assert_true(optics.night_vision)
	assert_eq(optics.zoom,4.0)
	await wait_process_frames(2)
	assert_true(panel.classifications.visible)
	assert_true(panel.ccd_display.material.get_shader_parameter("night_vision"))
	assert_eq(panel.ccd_display.material.get_shader_parameter("digital_zoom"),4.0)
	assert_lte(panel.panel.get_combined_minimum_size().x,640.0)
	assert_lte(panel.panel.get_combined_minimum_size().y,480.0)
	var buttons: Array = panel.panel.find_children("*","Button",true,false)
	assert_lte(buttons.back().global_position.y+buttons.back().size.y,480.0)
	drone.deployed = false
	drone.remove_module("sensor_a")
	w.get_node("Artifacts").devices.neural = {"state":"delivered","carrier":"","socket":""}
	assert_true(w.get_node("Artifacts").fit("neural",drone.identity))
	drone.deployed = true
	assert_true(Router.neural(drone))
	assert_eq(Router.tier(drone),1)
	assert_true(optics.classifications().is_empty())
	assert_false(optics.configure(true,4),"Neural clean feed is not free multispectrum hardware")
