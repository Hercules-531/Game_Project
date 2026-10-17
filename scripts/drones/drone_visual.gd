extends Node3D
## Custom low-poly equipment; every surface uses verified PSX pack textures.

const Policy = preload("res://scripts/render/material_policy.gd")
const METAL = preload("res://Textures/PSX modular house interior pack/geometry/cornerPillarMetal_albedo.png")
const RADIO = preload("res://Textures/PSX modular house interior pack/props/radio_albedo.png")
var metal: ShaderMaterial
var dark: ShaderMaterial
var housing: ShaderMaterial
var sensor: ShaderMaterial
var geometry: Node3D


func _ready() -> void:
	metal = Policy.make_surface(Color(0.85,0.88,0.81),METAL)
	dark = Policy.make_surface(Color(0.3,0.36,0.32),METAL)
	housing = Policy.make_surface(Color(0.9,0.82,0.56),METAL)
	sensor = Policy.make_surface(Color(0.25,0.45,0.35),RADIO)
	get_parent().configuration_changed.connect(rebuild)
	rebuild()


func _box(label: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(label,mesh,at,material)


func _mesh(label: String, shape: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = shape
	instance.position = at
	instance.material_override = material
	geometry.add_child(instance)
	return instance


func _strut(label: String, a: Vector3, b: Vector3, width: float) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = width
	cylinder.bottom_radius = width
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 6
	var part := _mesh(label,cylinder,(a + b) * 0.5,metal)
	part.basis = Basis(Quaternion(Vector3.UP,(b - a).normalized()))


func rebuild() -> void:
	if geometry != null:
		remove_child(geometry)
		geometry.queue_free()
	geometry = Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry)
	var drone: Node = get_parent()
	if drone.hull_id == "mule":
		_box("Body",Vector3(0.84,0.3,1.05),Vector3(0,0.62,0),housing)
		_box("Spine",Vector3(0.3,0.12,0.96),Vector3(0,0.83,0.04),metal)
		for x in [-1.0,1.0]:
			for z in [-0.36,0.36]:
				_strut("Hip",Vector3(x * 0.38,0.62,z),Vector3(x * 0.59,0.35,z + 0.12),0.065)
				_strut("Shin",Vector3(x * 0.59,0.35,z + 0.12),Vector3(x * 0.66,0.1,z),0.045)
				_box("Foot",Vector3(0.24,0.1,0.28),Vector3(x * 0.66,0.05,z),dark)
	elif drone.hull_id == "biped":
		_box("Torso",Vector3(0.55,0.45,0.4),Vector3(0,1.32,0),housing)
		_box("Head",Vector3(0.3,0.22,0.28),Vector3(0,1.66,-0.02),metal)
		_box("Hip",Vector3(0.45,0.18,0.35),Vector3(0,0.94,0),dark)
		for x in [-0.21,0.21]:
			_strut("UpperLeg",Vector3(x,0.94,0),Vector3(x,0.5,0.11),0.08)
			_strut("LowerLeg",Vector3(x,0.5,0.11),Vector3(x,0.1,-0.02),0.055)
			_box("BipedFoot",Vector3(0.23,0.12,0.42),Vector3(x,0.06,-0.06),dark)
			_strut("Shoulder",Vector3(x,1.43,0),Vector3(x*1.5,1.1,-0.1),0.045)
	elif drone.hull_id == "goliath":
		_box("IndustrialBody",Vector3(2.0,0.7,2.8),Vector3(0,1.5,0),housing)
		_box("ArmorSpine",Vector3(0.7,0.2,2.5),Vector3(0,1.95,0),metal)
		for x in [-1.0,1.0]:
			for z in [-1.1,1.1]:
				_strut("HydraulicHip",Vector3(x*0.85,1.5,z),Vector3(x*1.35,0.75,z+0.2),0.15)
				_strut("IndustrialShin",Vector3(x*1.35,0.75,z+0.2),Vector3(x*1.42,0.16,z),0.1)
				_box("LoadFoot",Vector3(0.5,0.25,0.6),Vector3(x*1.42,0.125,z),dark)
		_box("PowerPort",Vector3(0.4,0.35,0.4),Vector3(0,1.45,1.55),sensor)
	elif drone.hull_id == "tender":
		_box("BankBody",Vector3(1.2,0.75,1.95),Vector3(0,0.9,0),housing)
		for z in [-0.65,0.0,0.65]:
			_box("CellBank",Vector3(1.05,0.15,0.5),Vector3(0,1.37,z),metal)
		for x in [-0.72,0.72]:
			_box("TenderTrack",Vector3(0.3,0.5,2.1),Vector3(x,0.27,0),dark)
	elif drone.hull_id == "tracked":
		_box("Wedge",Vector3(1.05,0.4,1.35),Vector3(0,0.55,0),housing)
		_box("SlopeNose",Vector3(1.05,0.2,0.4),Vector3(0,0.35,-0.7),metal)
		for x in [-0.63,0.63]:
			_box("Track",Vector3(0.3,0.42,1.6),Vector3(x,0.24,0),dark)
			for z in [-0.65,-0.35,0.0,0.35,0.65]:
				_box("Tread",Vector3(0.34,0.06,0.1),Vector3(x,0.46,z),metal)
	else:
		_box("Body",Vector3(0.72,0.28,0.74),Vector3(0,0.65,0),housing)
		for x in [-1.0,1.0]:
			_strut("Outrigger",Vector3(x * 0.3,0.6,0),Vector3(x * 0.58,0.6,0),0.04)
			var duct := CylinderMesh.new()
			duct.top_radius = 0.28
			duct.bottom_radius = 0.34
			duct.height = 0.16
			duct.radial_segments = 8
			_mesh("LiftDuct",duct,Vector3(x * 0.59,0.61,0),dark)
			_box("LandingSkid",Vector3(0.08,0.08,0.6),Vector3(x * 0.25,0.08,0),metal)
			_strut("SkidArm",Vector3(x * 0.25,0.48,0),Vector3(x * 0.25,0.12,0),0.035)
	for socket in drone.modules:
		var id: String = drone.modules[socket]
		var at := Vector3(0,0.9,0)
		if drone.hull_id == "goliath": at = Vector3(0,2.1,0)
		elif drone.hull_id == "tender": at = Vector3(0,1.55,0)
		if socket == "sensor_a":
			at = Vector3(-0.19,0.69,-0.59)
		elif socket == "sensor_b":
			at = Vector3(0.19,0.69,-0.59)
		elif socket == "tool":
			at = Vector3(0,0.43,-0.63)
		if drone.hull_id == "goliath":
			if socket.begins_with("sensor"): at = Vector3(-0.45 if socket=="sensor_a" else 0.45,1.65,-1.55)
			elif socket == "tool": at = Vector3(0,1.15,-1.7)
		elif drone.hull_id == "biped":
			at = Vector3(0,1.55,0.17)
			if socket.begins_with("sensor"): at = Vector3(-0.1 if socket=="sensor_a" else 0.1,1.6,-0.2)
			elif socket == "tool": at = Vector3(0,1.05,-0.26)
		match id:
			"sentry_mount":
				_box("TurretBase",Vector3(0.42,0.2,0.4),at,metal)
				_strut("GunBarrel",at+Vector3(0,0.1,0),at+Vector3(0,0.1,-0.6),0.045)
			"trap_layer":
				_box("TrapMagazine",Vector3(0.55,0.25,0.6),at,dark)
				_box("TrapFeed",Vector3(0.4,0.1,0.65),at+Vector3(0,0.12,0),metal)
			"floodlight":
				_box("FloodHousing",Vector3(0.55,0.24,0.25),at,metal)
				_box("FloodGlass",Vector3(0.48,0.17,0.04),at+Vector3(0,0,-0.14),sensor)
				var beam := SpotLight3D.new()
				beam.name = "FloodBeam"
				beam.position = at+Vector3(0,0,-0.17)
				beam.spot_range = 18
				beam.spot_angle = 45
				beam.light_energy = 3
				beam.shadow_enabled = true
				geometry.add_child(beam)
			"noise_decoy":
				_box("DecoySpeaker",Vector3(0.4,0.3,0.3),at,sensor)
				for x in [-0.13,0.0,0.13]: _box("SpeakerGrille",Vector3(0.03,0.24,0.04),at+Vector3(x,0,-0.16),dark)
			"high_gain_dish":
				_strut("RelayMast",at,at+Vector3(0,0.7,0),0.03)
				var dish := CylinderMesh.new()
				dish.top_radius = 0.08
				dish.bottom_radius = 0.4
				dish.height = 0.16
				dish.radial_segments = 8
				var dish_view := _mesh("RelayDish",dish,at+Vector3(0,0.65,-0.1),metal)
				dish_view.rotation.x = deg_to_rad(-65)
			"sonar":
				_box("SonarEmitter",Vector3(0.24,0.18,0.12),at,metal)
			"thermal":
				_box("IRSensor",Vector3(0.16,0.16,0.12),at,sensor)
			"ccd":
				_box("CameraHousing",Vector3(0.24,0.18,0.24),at,metal)
				_box("CameraLens",Vector3(0.12,0.12,0.03),at + Vector3(0,0,-0.13),dark)
			"multispectrum":
				_box("SpectralHousing",Vector3(0.4,0.25,0.3),at,metal)
				for x in [-0.11,0.11]: _box("SpectralLens",Vector3(0.13,0.13,0.05),at+Vector3(x,0,-0.18),sensor)
			"winch":
				_box("WinchSpool",Vector3(0.44,0.19,0.22),at,dark)
				_strut("TowHook",at + Vector3(0,0,-0.1),at + Vector3(0,0,-0.3),0.025)
			"cargo_rack":
				_box("CargoDeck",Vector3(0.6,0.06,0.57),at,metal)
				for x in [-0.28,0.28]:
					_box("CargoRail",Vector3(0.035,0.16,0.56),at + Vector3(x,0.1,0),dark)
			"retrace":
				_box("RetraceModule",Vector3(0.22,0.16,0.25),at,sensor)
			"jumper":
				_box("JumperCell",Vector3(0.35,0.22,0.4),at,housing)
				_strut("JumperLead",at,at + Vector3(0.2,0,-0.3),0.02)
			"torch":
				_box("TorchPack",Vector3(0.22,0.24,0.3),at,housing)
				_strut("CuttingNozzle",at,at + Vector3(0,0,-0.35),0.035)
			"heavy_winch":
				_box("HeavySpool",Vector3(0.65,0.3,0.38),at,dark)
				_strut("HeavyHook",at,at + Vector3(0,0,-0.45),0.06)
			"tread_scraper":
				for x in [-0.64,0.64]:
					_box("TreadScraper",Vector3(0.34,0.16,0.08),Vector3(x,0.32,0.82),metal)
			"sealed_housing","signal_shield":
				_box("CircuitCover",Vector3(0.52,0.12,0.62),at,metal)
			"power_coupler":
				_box("PowerCoupler",Vector3(0.5,0.25,0.45),at,sensor)
			"solar_panel":
				_box("FieldCollector",Vector3(1.4,0.08,1.2),at+Vector3(0,0.1,0.3),metal)
			"prefab_winch":
				_box("StructureSpool",Vector3(1.0,0.65,0.7),at,dark)
				_strut("StructureHook",at,at+Vector3(0,0,-0.7),0.1)
			"drill":
				_strut("DrillArm",at,at+Vector3(0,0,-0.85),0.16)
				_box("DrillHead",Vector3(0.6,0.6,0.35),at+Vector3(0,0,-0.95),dark)
