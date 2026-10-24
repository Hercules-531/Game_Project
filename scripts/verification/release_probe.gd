extends Node
## Opt-in exported-build acceptance. All writes belong to an isolated test slot.
const Store = preload("res://scripts/settings/settings_store.gd")
const Synth = preload("res://scripts/audio/audio_synth.gd")
var session: Node
var checks: Array[String] = []
var failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--verify-release" in OS.get_cmdline_user_args(): _run_cli.call_deferred()

func expect(value: bool, label: String) -> bool:
	checks.append(label)
	if not value: failures.append(label)
	return value

func report() -> Dictionary:
	return {"ok":failures.is_empty(),"checks":checks,"failures":failures}

func frame() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame

func run(require_export: bool = true) -> Dictionary:
	checks.clear()
	failures.clear()
	Engine.time_scale = 1
	InputContext.menu_locked = false
	var settings: Node = get_node("/root/UserSettings")
	if not expect(settings.store.path.begins_with("user://tests/"),"isolated settings before writes"): return report()
	if require_export:
		expect(not OS.has_feature("editor"),"release template")
		expect(not has_node("/root/_mcp_game_helper"),"no development bridge")
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/release_probe/save.json"
	add_child(session)
	expect(session.world==null,"main menu before New Game")
	session.new_game()
	await frame()
	await frame()
	var w: Node = session.world
	expect(w.process_frames>0 and w.physics_ticks>0,"live New Game simulation")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		expect(image.get_width()==640 and image.get_height()==480,"640x480 actual framebuffer")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests/release_probe"))
		expect(image.save_png("user://tests/release_probe/exported-frame.png")==OK,"rendered export capture")
	InputContext.set_context(InputContext.Context.MENU)
	var elapsed: float = w.elapsed_seconds
	await get_tree().create_timer(0.05).timeout
	expect(w.elapsed_seconds==elapsed and get_tree().paused,"pause freezes simulation")
	session.open_settings()
	expect(session.get_node("Settings").panel.visible,"settings panel opens")
	expect(settings.store.rebind("move_forward",KEY_UP),"rebind accepted")
	settings.store.volumes.effects = 0.0
	settings.store.apply()
	expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")),"effects mute applied")
	settings.store.volumes.effects = 0.6
	settings.store.apply()
	expect(settings.store.save_settings(),"settings saved")
	var reloaded := Store.new(settings.store.path)
	expect(reloaded.load_settings() and reloaded.keys.move_forward==KEY_UP and absf(reloaded.volumes.effects-0.6)<0.000001,"settings persisted")
	expect(InputMap.action_get_events("move_forward")[0].physical_keycode==KEY_UP,"rebound physical input")
	session._close_settings()
	session.resume()
	expect(not get_tree().paused,"resume after settings")
	expect(Synth.stream("sonar").data.size()>0,"native PCM in export")
	var audio: Node = w.get_node("Audio")
	audio.play_at("impact",audio.listener.global_position,20,"release_probe")
	expect(audio.recent.any(func(cue): return cue.cue=="impact"),"audio cue reaches actual director")
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(0.08).timeout
		var bus := AudioServer.get_bus_index("Effects")
		expect(maxf(AudioServer.get_bus_peak_volume_left_db(bus,0),AudioServer.get_bus_peak_volume_right_db(bus,0))>-70.0,"live audio mixer output")
	# Persistent infrastructure is provisioned; live build/travel costs are
	# covered by M43. This pass checks the shipped resources and serialization.
	w.get_node("Inventory").scrap = 123
	var territory: Node = w.get_node("Territory")
	territory.sites[1].held = true
	territory.sites[1].pylon = true
	territory.sites[1].fob = true
	w.get_node("Excavation").restore({"segments":[{"kind":"tunnel","source":0,"target":1,"width":6.0,"depth":6.0,"height":3.2}],"rooms":{},"jobs":{},"next_serial":1})
	w.get_node("Rail").stock(1).scrap = 9
	var mule: Node = w.get_node("Fleet").drone("mule_01")
	var hover: Node = w.get_node("Fleet").drone("hover_01")
	mule.battery = 0.7
	mule.components.joints = 65.0
	expect(mule.install("utility","jumper"),"recovery module fitted")
	mule.deployed = true
	mule.position = Vector3(-2,0.02,-18)
	hover.deployed = true
	hover.position = Vector3(-2,0.02,-20.5)
	hover.battery = 0.0
	await frame()
	expect(w.get_node("Recovery").hotwire(mule,hover),"finite drone-to-drone rescue")
	expect(mule.battery<0.7 and hover.battery>0,"rescue energy conserved")
	var controller: Node = w.get_node("FleetControl")
	if not expect(controller.request_machine_transfer(hover,false),"rescued hull accepted by loader"): return report()
	Engine.time_scale = 8
	await get_tree().create_timer(9.0).timeout
	Engine.time_scale = 1
	expect(not hover.deployed and controller.transfer.is_empty(),"rescued hull returned to bay")
	expect(session.save_current(),"world saved")
	if not expect(session.continue_game(),"Continue reads isolated save"): return report()
	w = session.world
	expect(w.get_node("Inventory").scrap==123,"inventory retained")
	expect(w.get_node("Rail").stock(1).scrap==9 and w.get_node("Excavation").segments.size()==1,"infrastructure retained")
	expect(w.get_node("Fleet").drone("mule_01").components.joints<66 and not w.get_node("Fleet").drone("hover_01").deployed,"fleet recovery retained")
	# A supplied completion fixture checks the actual shipped ending/save flow.
	for band in 6:
		w.get_node("Territory").sites[band].held = true
		w.get_node("Territory").sites[band].perimeter = true
		w.get_node("Defense").install_perimeter(band)
		w.get_node("Trace").nests[band].apply_damage(1000)
	for actor in w.get_node("Threats").actors.values(): actor.apply_damage(1000)
	expect(w.get_node("Restoration").evaluate(),"restoration completion")
	expect(session.get_node("Credits").panel.visible and get_tree().paused,"credits visible and paused")
	expect(session.get_node("Credits").automatic_presentations==1,"credits presented once")
	session._resume_after_credits()
	if not expect(session.continue_game(),"completion reload"): return report()
	expect(session.world.get_node("Restoration").credits_seen and not session.ending_open,"saved ending does not auto replay")
	return report()

func _run_cli() -> void:
	var result: Dictionary = await run()
	print("OUTPOST_RELEASE_FLOW: ",JSON.stringify(result))
	if is_instance_valid(session):
		session._discard_world()
		get_tree().paused = false
		await frame()
		await frame()
		await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if result.ok else 1)
