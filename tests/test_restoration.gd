extends GutTest
const Schema = preload("res://scripts/persistence/save_schema.gd")
var session: Node
var w: Node
var tracker: Node
func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/restoration_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	bind_world()
func bind_world() -> void:
	w = session.world
	for n in w.get_children(): n.set_physics_process(false)
	for a in w.get_node("Threats").actors.values(): a.set_physics_process(false)
	tracker = w.get_node("Restoration")
func after_each() -> void:
	InputContext.menu_locked = false
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func secure_fixture() -> void:
	for band in 6:
		w.get_node("Territory").sites[band].held = true
		w.get_node("Territory").sites[band].perimeter = true
		w.get_node("Defense").install_perimeter(band)
		w.get_node("Trace").nests[band].apply_damage(1000)
	for a in w.get_node("Threats").actors.values(): a.apply_damage(1000)
func test_each_band_requires_earned_ground_quiet_nest_and_all_fence_sections() -> void:
	assert_false(tracker.evaluate())
	secure_fixture()
	for band in 6:
		w.get_node("Territory").sites[band].held = false
		assert_false(tracker.evaluate())
		w.get_node("Territory").sites[band].held = true
		var nest: Node = w.get_node("Trace").nests[band]
		nest.state = "active"
		nest.integrity = 100
		assert_false(tracker.evaluate())
		nest.apply_damage(1000)
		for section in 5:
			w.get_node("Defense").perimeters[str(band)].health[section] = 0
			assert_false(tracker.evaluate())
			w.get_node("Defense").perimeters[str(band)].health[section] = 200.0
	assert_true(tracker.checklist().ready)
	assert_true(tracker.evaluate())
	assert_true(tracker.completed)
func test_residual_density_strict_boundary_counts_survivors_after_nest_clear() -> void:
	secure_fixture()
	for i in 3:
		var a: Node = w.get_node("Threats").spawn("residual_%d" % i,Vector3(25+i*2,0,-50),Vector3(25,0,-50))
		a.set_physics_process(false)
	assert_eq(tracker.checklist().density,0.5)
	assert_false(tracker.evaluate(),"At the threshold is not below it")
	w.get_node("Threats").actors.residual_0.apply_damage(1000)
	assert_almost_eq(float(tracker.checklist().density),2.0/6,0.00001)
	assert_true(tracker.evaluate(),"Dead bodies do not inflate surviving pressure")
func test_completion_is_latched_saved_and_credits_pause_exactly_once_across_reload() -> void:
	secure_fixture()
	assert_true(tracker.evaluate())
	assert_true(get_tree().paused)
	assert_true(session.ending_open)
	assert_true(session.get_node("Credits").panel.visible)
	assert_eq(session.get_node("Credits").automatic_presentations,1)
	assert_true(tracker.credits_seen)
	for _i in 3: assert_false(tracker.evaluate())
	assert_eq(session.get_node("Credits").automatic_presentations,1)
	session.resume()
	assert_true(get_tree().paused,"Ordinary Resume cannot bypass credits")
	session.open_settings()
	assert_false(session.get_node("Credits").panel.visible)
	session._close_settings()
	assert_true(session.get_node("Credits").panel.visible)
	session._resume_after_credits()
	assert_false(get_tree().paused)
	assert_true(session.continue_game())
	bind_world()
	assert_true(tracker.completed)
	assert_true(tracker.credits_seen)
	assert_false(session.ending_open)
	assert_false(tracker.evaluate())
	assert_eq(session.get_node("Credits").automatic_presentations,1)
	session.show_credits()
	assert_eq(session.get_node("Credits").automatic_presentations,1,"Manual replay is not another completion")
func test_pending_ending_loads_once_and_legacy_save_does_not_award_free_completion() -> void:
	secure_fixture()
	tracker.completed = true
	tracker.completed_at = w.elapsed_seconds
	assert_true(session.save_current())
	assert_true(session.continue_game())
	bind_world()
	assert_true(tracker.credits_seen)
	assert_eq(session.get_node("Credits").automatic_presentations,1)
	session._resume_after_credits()
	var legacy := Schema.capture(w)
	legacy.version = 35
	legacy.erase("restoration")
	assert_eq(Schema.validate(legacy),"")
	Schema.restore(w,legacy)
	assert_false(tracker.completed)
	assert_false(tracker.credits_seen)
	assert_eq(Schema.validate(Schema.capture(w)),"")
func test_save_failure_leaves_retryable_ending_without_claiming_persistence() -> void:
	secure_fixture()
	var valid_path: String = session.save_path
	session.save_path = "res://project.godot/invalid-save.json"
	assert_true(tracker.evaluate())
	assert_false(tracker.credits_seen)
	assert_true(session.get_node("Credits").retry.visible)
	session._resume_after_credits()
	assert_true(session.ending_open,"Unsaved completion stays retryable")
	session.save_path = valid_path
	session._persist_ending()
	assert_true(tracker.credits_seen)
	assert_false(session.get_node("Credits").retry.visible)
	assert_true(session.continue_game())
	bind_world()
	assert_true(tracker.completed)
	assert_eq(session.get_node("Credits").automatic_presentations,1)
func test_dead_operator_cannot_win_and_malformed_completion_records_are_rejected() -> void:
	secure_fixture()
	w.get_node("LifeSupport").dead = true
	assert_false(tracker.evaluate())
	w.get_node("LifeSupport").dead = false
	w.get_node("HumanSortie").dead = true
	assert_false(tracker.evaluate())
	w.get_node("HumanSortie").dead = false
	var data := Schema.capture(w)
	data.restoration.credits_seen = true
	assert_false(Schema.validate(data).is_empty())
	data.restoration = {"completed":true,"credits_seen":true,"completed_at":data.elapsed+100}
	assert_false(Schema.validate(data).is_empty())
	assert_false(tracker.validate({"completed":false,"credits_seen":false,"completed_at":0}))
func test_checklist_and_both_credits_states_fit_real_framebuffer() -> void:
	var panel: Node = w.get_node("RestorationPanel")
	panel.open()
	await wait_process_frames(3)
	assert_lte(panel.panel.get_combined_minimum_size().x,640.0)
	assert_lte(panel.back.global_position.y+panel.back.size.y,480.0)
	assert_true(panel.readings.text.contains("BAND 6"))
	assert_true(panel.readings.text.contains("BELOW TARGET"))
	for saved in [true,false]:
		session.get_node("Credits").open(saved)
		await wait_process_frames(3)
		assert_lte(session.get_node("Credits").panel.get_combined_minimum_size().x,640.0)
		assert_lte(session.get_node("Credits").back.global_position.y+session.get_node("Credits").back.size.y,480.0)
