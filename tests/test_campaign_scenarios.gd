extends GutTest
## Integrated opening: actual delayed commands, body motion and live costs.
const Router = preload("res://scripts/sensors/sensor_router.gd")
var session: Node
var w: Node
var mule: Node
var control: Node
var metrics: Array = []
var metres := 0.0
func before_each() -> void:
	Engine.time_scale = 1
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/campaign_opening_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	bind_world()
	w.get_node("Weather").force("sunlight")
	w.get_node("Weather").set_physics_process(false)
func bind_world() -> void:
	w = session.world
	mule = w.get_node("Fleet").drone("mule_01")
	control = w.get_node("FleetControl")
func after_each() -> void:
	Engine.time_scale = 1
	InputContext.menu_locked = false
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func measure(phase: String) -> void:
	var life: Node = w.get_node("LifeSupport")
	metrics.append({"phase":phase,"simulation_seconds":w.elapsed_seconds,"field_metres":metres,"mule_kwh":mule.battery,"joints":mule.components.joints,"cell":mule.components.cell,"fuel":life.fuel,"grid_kwh":life.battery,"rations":life.rations,"scrap":w.get_node("Inventory").scrap,"trace":w.get_node("Trace").trace[0],"optics_tier":Router.tier(mule)})
func drive_to(at: Vector3) -> bool:
	for _step in 1800:
		var gap: Vector3 = at-mule.position
		gap.y = 0
		if gap.length()<0.45:
			control.held = Vector2.ZERO
			control.stop_all()
			return true
		var turn := angle_difference(mule.rotation.y,atan2(-gap.x,-gap.z))
		if w.get_node("Radio").quality(mule)>0: control.piloting = true
		control.held = Vector2(-clampf(turn*1.8,-1,1),-1 if absf(turn)<0.35 else 0)
		var before: Vector3 = mule.position
		await wait_physics_frames(1)
		metres += mule.position.distance_to(before)
	control.held = Vector2.ZERO
	control.stop_all()
	return false
func transfer(deploy: bool) -> bool:
	control.held = Vector2.ZERO
	control.stop_all()
	if not control.request_transfer(deploy): return false
	for _step in 600:
		if control.transfer.is_empty(): return mule.deployed==deploy
		await wait_physics_frames(1)
	return false
func save_measurements(name: String, data: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/verification"))
	var file := FileAccess.open("res://builds/verification/"+name+".json",FileAccess.WRITE)
	assert_not_null(file)
	if file!=null: file.store_string(JSON.stringify(data,"\t"))
func test_live_opening_salvage_camera_and_reload_preserve_costs_and_hardware() -> void:
	metrics.clear()
	metres = 0
	measure("new_game")
	assert_eq(Router.tier(mule),0)
	w.get_node("FleetPanel").open()
	Engine.time_scale = 4
	assert_true(await transfer(true))
	assert_true(await drive_to(Vector3(-3,0.02,-46)),"Actual linked steering must reach the salvage")
	assert_true(w.get_node("Salvage").recover_nearest(mule))
	assert_eq(w.get_node("Inventory").scrap,80)
	assert_true(await drive_to(Vector3(-2,0.02,-14)))
	assert_true(await transfer(false))
	assert_eq(w.get_node("Inventory").scrap,96)
	measure("scrap_delivered")
	assert_true(await transfer(true))
	assert_true(await drive_to(Vector3(4,0.02,-60)))
	assert_true(w.get_node("CameraDiscovery").recover(mule))
	assert_eq(Router.tier(mule),0,"Carrying a camera is not an installed camera")
	assert_true(await drive_to(Vector3(-2,0.02,-14)))
	assert_true(await transfer(false))
	measure("camera_delivered")
	var ccd_serial := -1
	for part in w.get_node("Inventory").parts:
		if part.id=="ccd": ccd_serial = int(part.serial)
	assert_gt(ccd_serial,0)
	assert_true(w.get_node("Workshop").remove(mule.identity,"sensor_b"))
	assert_true(w.get_node("Workshop").fit(mule.identity,"sensor_b",ccd_serial))
	assert_eq(Router.tier(mule),1)
	assert_false(w.get_node("Fabrication").start("ccd"))
	assert_gt(metres,140.0)
	assert_lt(mule.battery,1.0,"Live travel spends actual energy")
	assert_lt(mule.components.joints,100.0,"Live travel wears actual joints")
	assert_lt(w.get_node("LifeSupport").fuel,120.0)
	assert_gt(w.get_node("Trace").trace[0],0.0)
	measure("camera_fitted")
	Engine.time_scale = 1
	assert_true(session.save_current())
	var paid_energy: float = mule.battery
	var paid_condition: float = mule.components.joints
	assert_true(session.continue_game())
	bind_world()
	assert_eq(Router.tier(mule),1)
	assert_eq(w.get_node("Inventory").scrap,96)
	assert_almost_eq(mule.battery,paid_energy,0.000001)
	assert_almost_eq(float(mule.components.joints),paid_condition,0.000001)
	assert_eq(w.get_node("CameraDiscovery").state,"delivered")
	measure("reloaded")
	save_measurements("m43a_opening",{"kind":"automated_live_physics","time_scale":4,"weather":"held sunlight","measurements":metrics})
func test_one_hour_idle_life_support_reserve_is_not_a_human_playtime_claim() -> void:
	var life: Node = w.get_node("LifeSupport")
	var before: Dictionary = life.snapshot()
	life.advance(3600)
	assert_false(life.dead)
	assert_almost_eq(life.fuel,before.fuel-60.0,0.000001)
	assert_almost_eq(life.rations,before.rations-2.0,0.000001)
	assert_eq(life.oxygen,100.0)
	assert_eq(life.temperature,18.0)
	assert_gt(life.battery,0.0)
	save_measurements("m43a_idle_reserve",{"kind":"isolated_reserve_calculation","model_seconds":3600,"before":before,"after":life.snapshot(),"human_playtime_hours":0})
