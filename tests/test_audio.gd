extends GutTest
const Synth = preload("res://scripts/audio/audio_synth.gd")
const Store = preload("res://scripts/settings/settings_store.gd")
var session: Node
var w: Node
var rig: Node
func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/audio_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	_bind_world()
func _bind_world() -> void:
	w = session.world
	for n in w.get_children(): n.set_physics_process(false)
	for actor in w.get_node("Threats").actors.values(): actor.set_physics_process(false)
	rig = w.get_node("Audio")
	w.get_node("Weather").current = "sunlight"
func after_each() -> void:
	get_tree().paused = false
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func _remote() -> Node:
	var drone: Node = w.get_node("Fleet").drone("mule_01")
	drone.deployed = true
	drone.position = Vector3(0,0.02,-18)
	w.get_node("FleetControl").panel_open = true
	InputContext.set_context(InputContext.Context.TERMINAL)
	rig.update_listener()
	return drone
func _count(cue: String) -> int:
	return rig.recent.filter(func(item): return item.cue==cue).size()
func test_native_pcm_has_headroom_fades_and_distinct_cached_cues() -> void:
	var fingerprints := {}
	for cue in Synth.DURATIONS:
		var stream: AudioStreamWAV = Synth.stream(cue)
		assert_same(stream,Synth.stream(cue))
		assert_eq(stream.mix_rate,22050)
		assert_false(stream.stereo)
		assert_eq(stream.data.decode_s16(0),0)
		var peak := 0
		for i in range(0,stream.data.size(),2): peak = maxi(peak,absi(stream.data.decode_s16(i)))
		assert_gt(peak,100)
		assert_lt(peak,27000)
		assert_lt(absi(stream.data.decode_s16(stream.data.size()-2)),100)
		fingerprints[hash(stream.data)] = true
	assert_eq(fingerprints.size(),Synth.DURATIONS.size())
func test_machine_loops_match_real_silent_power_and_thermal_emissions() -> void:
	var drone := _remote()
	drone.velocity = Vector3(0,0,-1)
	rig.advance(0.1)
	assert_true(rig.loops.has(drone.identity))
	var loud: float = rig.loops[drone.identity].get_meta("reach")
	drone.silent_running = true
	rig.advance(0.1)
	assert_almost_eq(float(rig.loops[drone.identity].get_meta("reach")),loud*0.25,0.00001)
	drone.battery = 0
	rig.advance(0.1)
	assert_false(rig.loops.has(drone.identity))
	assert_eq(rig.remote_id,"")
	drone.battery = 1
	drone.deployed = false
	var artifacts: Node = w.get_node("Artifacts")
	artifacts.devices.thermal = {"state":"delivered","carrier":"","socket":""}
	assert_true(artifacts.fit("thermal",drone.identity))
	drone.deployed = true
	rig.advance(0.1)
	assert_eq(w.get_node("Emissions").sound_reach(drone),0.0)
	assert_false(rig.loops.has(drone.identity))
func test_listener_uses_linked_eye_and_returns_to_bunker_on_blackout() -> void:
	var drone := _remote()
	assert_eq(rig.remote_id,drone.identity)
	assert_true(rig.listener.global_transform.is_equal_approx(drone.get_node("CCD").eye_transform()))
	drone.rotation.y = PI/2
	rig.update_listener()
	assert_true(rig.listener.global_basis.is_equal_approx(drone.global_basis))
	w.get_node("Radio").range_multiplier = 0
	rig.update_listener()
	assert_eq(rig.remote_id,"")
	assert_true(rig.listener.global_position.is_equal_approx(w.get_node("Operator/Head/Camera").global_position))
func test_sonar_only_successful_fresh_linked_ping_produces_chirp_and_returns() -> void:
	var drone := _remote()
	await wait_physics_frames(2)
	var sonar: Node = drone.get_node("Sonar")
	assert_true(sonar.ping())
	assert_eq(_count("sonar"),1)
	assert_gt(rig.pending.size(),0)
	assert_false(sonar.ping())
	assert_eq(_count("sonar"),1)
	rig.advance(1)
	assert_eq(_count("echo"),1)
	sonar.clock += 3
	drone.silent_running = true
	assert_false(sonar.ping())
	assert_eq(_count("sonar"),1)
	drone.silent_running = false
	assert_true(sonar.ping())
	w.get_node("FleetControl").panel_open = false
	rig.advance(1)
	assert_eq(_count("echo"),1,"Leaving the feed discards its pending returns")
func test_spatial_sound_is_bounded_and_cover_uses_existing_acoustic_fraction() -> void:
	rig.update_listener()
	rig.play_at("impact",Vector3(0,0.1,4),20,"near")
	assert_eq(rig.voices.size(),1)
	assert_eq(rig.voices[0].bus,&"Effects")
	assert_eq(rig.voices[0].max_distance,20.0)
	rig.play_at("impact",Vector3(300,0,0),20,"remote")
	assert_eq(rig.voices.size(),1)
	# Command/workshop wall intersects this ray; visual/sensing geometry is shared.
	rig.play_at("impact",Vector3(-4,0.5,1),30,"covered")
	assert_eq(rig.voices.size(),2)
	assert_true(rig.voices[1].get_meta("covered"))
	assert_almost_eq(rig.voices[1].max_distance,10.5,0.0001)
	assert_lt(rig.voices[1].volume_db,rig.voices[0].volume_db)
func test_weather_supply_and_life_suit_urgency_follow_actual_state() -> void:
	rig.advance(0.1)
	var quiet: float = rig.weather_voice.volume_db
	assert_true(rig.vent_voice.playing)
	w.get_node("LifeSupport").oxygen_on = false
	w.get_node("Weather").current = "rain"
	rig.advance(0.1)
	assert_false(rig.vent_voice.playing)
	assert_same(rig.weather_voice.stream,Synth.stream("rain"))
	assert_gt(rig.weather_voice.volume_db,quiet)
	w.get_node("LifeSupport").oxygen = 20
	rig.advance(0.1)
	assert_eq(_count("alarm"),1)
	w.get_node("LifeSupport").oxygen = 0
	rig.advance(4)
	assert_eq(_count("critical"),1)
	var human: Node = w.get_node("HumanSortie")
	w.get_node("LifeSupport").oxygen = 100
	human.active = true
	human.oxygen = 30
	human.filter = 300
	rig.advance(0.1)
	assert_eq(_count("breath"),1)
	assert_eq(_count("critical"),2)
	assert_almost_eq(float(rig.clocks.suit_alarm),0.75,0.00001)
	human.active = false
	rig.advance(0.1)
	assert_false(rig.breath_voice.playing)
func test_volume_pause_and_reload_do_not_replay_saved_pulses() -> void:
	var store := Store.new("user://tests/unused_audio_settings.json")
	var before := {}
	for bus in Store.BUSES.values():
		var index := AudioServer.get_bus_index(bus)
		before[bus] = [AudioServer.get_bus_volume_db(index),AudioServer.is_bus_mute(index)]
	store.volumes = {"master":1.0,"effects":0.0,"ambience":0.25}
	store.apply()
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")))
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience")),linear_to_db(0.25),0.001)
	for bus in before:
		var index := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_volume_db(index,before[bus][0])
		AudioServer.set_bus_mute(index,before[bus][1])
	w.get_node("Emissions").pulse("drill",Vector3(0,0,4),180,"fixture")
	var count: int = rig.recent.size()
	get_tree().paused = true
	rig.advance(10)
	assert_eq(rig.recent.size(),count)
	get_tree().paused = false
	assert_true(session.save_current())
	assert_true(session.continue_game())
	_bind_world()
	assert_eq(rig.recent.size(),0)
	assert_eq(rig.voices.size(),0)
