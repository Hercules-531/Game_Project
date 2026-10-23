extends GutTest
const Campaign = preload("res://resources/world/campaign.tres")
const Schema = preload("res://scripts/persistence/save_schema.gd")
var session: Node
var w: Node
func before_each() -> void:
	Engine.time_scale = 1
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/bands_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	bind_world()
func bind_world() -> void:
	w = session.world
	for n in w.get_children(): n.set_physics_process(false)
	for actor in w.get_node("Threats").actors.values(): actor.set_physics_process(false)
func after_each() -> void:
	Engine.time_scale = 1
	get_tree().paused = false
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func test_authored_bounds_unique_finite_supplies_and_actual_northward_pressure() -> void:
	assert_true(Campaign.valid())
	var known := {}
	for band in Campaign.bands:
		for item in band.salvage():
			assert_false(known.has(item.id))
			known[item.id] = true
			assert_true(w.get_node("Salvage").items.has(item.id))
			assert_gt(float(item.mass),0.0)
		var nest: Node = w.get_node("Trace").nests[band.index]
		assert_eq(nest.integrity,200.0+100*band.index)
		if band.index>0:
			assert_gt(nest.integrity,w.get_node("Trace").nests[band.index-1].integrity)
			assert_lt(nest.remaining,w.get_node("Trace").nests[band.index-1].remaining)
	assert_eq(w.get_node("Territory").frontier(),0,"Authored content grants no territory")
	assert_false(w.get_node("Territory").anchor("mule_01",2))
	await wait_physics_frames(2)
	assert_true(w.get_node("Defense").footprint_clear(0),"Authored supplies must not obstruct paid perimeter construction")
	for band in Campaign.bands:
		assert_true(w.get_node("Defense").footprint_clear(band.index),"Keep earned pad construction clear in "+band.title)
	var blocked_band: Resource = Campaign.bands[0].duplicate(true)
	blocked_band.scrap_sites.append(Vector3(10,0.02,-66))
	assert_false(blocked_band.valid(),"Supply sites cannot occupy future earned ramp apertures")
	if Campaign.bands.size()>=3:
		var nearest := INF
		for at in Campaign.bands[2].route: nearest = minf(nearest,at.distance_to(w.get_node("Research").TREE.topics.heavy.at))
		assert_lt(nearest,2.0,"Substation route must reach the actual archive pickup range")
	if Campaign.bands.size()>=4:
		for objective in [w.get_node("Research").TREE.topics.excavation.at,w.get_node("Artifacts").DEFINITIONS.neural.at]:
			var nearest := INF
			for at in Campaign.bands[3].route: nearest = minf(nearest,at.distance_to(objective))
			assert_lt(nearest,2.0,"Fourth band must reach its actual archive and artifact")
	if Campaign.bands.size()>=5:
		for objective in [w.get_node("Research").TREE.topics.optics.at,w.get_node("Artifacts").DEFINITIONS.photonic.at]:
			var nearest := INF
			for at in Campaign.bands[4].route: nearest = minf(nearest,at.distance_to(objective))
			assert_lt(nearest,2.0,"Fifth band must reach its actual optics and photonic discoveries")
func test_new_finite_crate_uses_real_payload_loader_and_does_not_duplicate_after_reload() -> void:
	var salvage: Node = w.get_node("Salvage")
	var d: Node = w.get_node("Fleet").drone("mule_01")
	var item: Node = salvage.items["band_01_scrap_01"]
	var original: int = w.get_node("Inventory").scrap
	d.deployed = true
	d.position = item.position+Vector3(2,0,0)
	assert_true(salvage.recover_nearest(d))
	assert_eq(w.get_node("Inventory").scrap,original)
	assert_eq(d.cargo_kg,float(item.definition.mass))
	assert_true(session.save_current())
	assert_true(session.continue_game())
	bind_world()
	d = w.get_node("Fleet").drone("mule_01")
	salvage = w.get_node("Salvage")
	assert_eq(salvage.items["band_01_scrap_01"].state,"carried")
	d.position = Vector3(-2,0.02,-14)
	await wait_physics_frames(2)
	assert_true(w.get_node("FleetControl").request_transfer(false))
	w.get_node("FleetControl").advance_transfer(8)
	assert_eq(w.get_node("Inventory").scrap,original+Campaign.bands[0].scrap_amount)
	assert_eq(salvage.deliver(d),0)
	assert_true(session.save_current())
	assert_true(session.continue_game())
	bind_world()
	assert_eq(w.get_node("Salvage").items["band_01_scrap_01"].state,"delivered")
	assert_eq(w.get_node("Inventory").scrap,original+Campaign.bands[0].scrap_amount)
func test_older_content_versions_preserve_rewards_and_add_only_new_sites() -> void:
	var data := Schema.capture(w)
	data.version = 36
	data.erase("campaign_bands")
	data.salvage = data.salvage.filter(func(record): return not record.id.begins_with("band_"))
	data.salvage[0].state = "delivered"
	assert_eq(Schema.validate(data),"")
	Schema.restore(w,data)
	assert_eq(w.get_node("Salvage").items.scrap_01.state,"delivered")
	assert_eq(w.get_node("Salvage").items["band_01_scrap_01"].state,"available")
	assert_true(session.save_current())
	var upgraded := Schema.capture(w)
	assert_eq(upgraded.campaign_bands,Campaign.bands.size())
	upgraded.salvage.pop_back()
	assert_false(Schema.validate(upgraded).is_empty(),"Missing a known existing reward is invalid")
	upgraded = Schema.capture(w)
	upgraded.campaign_bands = 99
	assert_false(Schema.validate(upgraded).is_empty())
func test_authored_surface_route_is_drivable_with_actual_starter_controller() -> void:
	var d: Node = w.get_node("Fleet").drone("mule_01")
	var controller: Node = d.get_node("Controller")
	d.deployed = true
	Engine.time_scale = 8
	for band in Campaign.bands:
		# Geometry fixture starts at this earned leg; continuous motion thereafter.
		d.position = band.route[0]
		d.rotation.y = 0
		d.velocity = Vector3.ZERO
		var cursor := 1
		await wait_physics_frames(2)
		for _step in 1800:
			var gap: Vector3 = band.route[cursor]-d.position
			gap.y = 0
			if gap.length()<0.9:
				cursor += 1
				if cursor>=band.route.size(): break
				continue
			var heading := atan2(-gap.x,-gap.z)
			var turn := angle_difference(d.rotation.y,heading)
			controller.command = Vector2(-clampf(turn/0.25,-1,1),-1 if absf(turn)<0.18 else 0)
			await wait_physics_frames(1)
		controller.stop()
		assert_eq(cursor,band.route.size(),"Route for "+band.title+" blocked at "+str(d.position))
		assert_lt(d.position.distance_to(w.get_node("Trace").nests[band.index].position),15.0)
	Engine.time_scale = 1
func test_additive_authored_band_migration_retains_earlier_delivered_rewards() -> void:
	for count in range(1,Campaign.bands.size()):
		var data := Schema.capture(w)
		data.campaign_bands = count
		var known := {}
		for definition in w.get_node("Salvage").definitions(count): known[definition.id] = true
		data.salvage = data.salvage.filter(func(record): return known.has(record.id))
		for record in data.salvage:
			if record.id=="band_01_scrap_01": record.state = "delivered"
		assert_eq(Schema.validate(data),"")
		Schema.restore(w,data)
		assert_eq(w.get_node("Salvage").items["band_01_scrap_01"].state,"delivered")
		var new_id: String = Campaign.bands[count].salvage()[0].id
		assert_eq(w.get_node("Salvage").items[new_id].state,"available")
		assert_eq(Schema.validate(Schema.capture(w)),"")
func test_field_perimeter_can_anchor_in_owned_lining_but_rejects_crates_and_bodies() -> void:
	w.get_node("Territory").sites[1].held = true
	w.get_node("Territory").sites[1].pylon = true
	w.get_node("Excavation").restore({"segments":[{"kind":"tunnel","source":0,"target":1,"width":6.0,"depth":6.0,"height":3.2}],"rooms":{},"jobs":{},"next_serial":1})
	w.get_node("Rail").sync()
	await wait_physics_frames(2)
	assert_true(w.get_node("Defense").footprint_clear(1),"Keep a commissioned rail mouth while founding its perimeter")
	var box: Node = load("res://scripts/world/surface_kit.gd").box(w.get_node("Surface"),"UnownedObstruction",Vector3.ONE,Vector3(18,0.75,-125))
	await wait_physics_frames(2)
	assert_false(w.get_node("Defense").footprint_clear(1))
	box.queue_free()
