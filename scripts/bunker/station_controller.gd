extends Node

const Interaction = preload("res://scripts/interaction/interactable.gd")
@onready var bunker: Node3D = get_parent().get_node("Bunker")
@onready var ui: CanvasLayer = get_parent().get_node("StationUI")


func _ready() -> void:
	_bind("CommandCRT","Command desk",&"terminal",&"command")
	_bind("TelemetryCRT","Command desk",&"terminal",&"command")
	_bind("MapCRT","Command desk",&"terminal",&"command")
	_bind("WorkshopBench","Workshop",&"terminal",&"workshop")
	_bind("LifeBreaker","Life support",&"terminal",&"life_support")
	_bind("PowerBreaker","Power panel",&"terminal",&"life_support")
	_bind("CommandSwitch","Command lights",&"switch",&"command")
	_bind("WorkshopSwitch","Workshop lights",&"switch",&"workshop")
	_bind("Airlock/InnerDoor","Cycle inner airlock",&"door",&"inner")
	bunker._prop("switch","AirlockControlOutside",Vector3(-1.03,1.35,-5.895),-90)
	bunker._prop("switch","AirlockControlInside",Vector3(-1.03,1.35,-6.105),90)
	_bind("AirlockControlOutside","Cycle inner airlock",&"door",&"inner")
	_bind("AirlockControlInside","Cycle inner airlock",&"door",&"inner")
	get_parent().get_node("Operator/Interactor").target_changed.connect(ui.show_target)
	for crt in ["CommandCRT","TelemetryCRT","MapCRT"]:
		var screen := Label3D.new()
		screen.name = "ScreenStatus"
		screen.position = Vector3(0,0.3,0.18)
		screen.pixel_size = 0.0012
		screen.font_size = 32
		screen.text = "OUTPOST 14\nLINK OFFLINE"
		screen.modulate = Color(0.35,0.85,0.55)
		bunker.get_node(crt).add_child(screen)
	get_parent().get_node("LifeSupport").changed.connect(_refresh_grid)


func _bind(path: String, title: String, kind: StringName, station_id: StringName) -> void:
	var target := bunker.get_node(path)
	var interaction := Interaction.new()
	interaction.name = "Interaction"
	interaction.display_name = title
	interaction.kind = kind
	interaction.station_id = station_id
	target.add_child(interaction)
	interaction.used.connect(_use)
	interaction.power_changed.connect(func(_powered: bool):_apply_power(interaction))


func _apply_power(target: OutpostInteractable) -> void:
	var grid_live: bool = get_parent().get_node("LifeSupport").supplied_fraction > 0.0
	var screen := target.get_parent().get_node_or_null("ScreenStatus")
	if screen != null:
		screen.visible = target.powered and grid_live
	if target.kind == &"switch":
		var light := bunker.get_node("CommandLight" if target.station_id == &"command" else "WorkshopLight")
		light.visible = target.powered and grid_live
		var lever := target.get_parent().get_node_or_null("lightSwitch_001") as Node3D
		if lever != null:
			lever.rotation.z = -0.3 if target.powered else 0.3


func _refresh_grid() -> void:
	for path in ["CommandCRT","TelemetryCRT","MapCRT","CommandSwitch","WorkshopSwitch"]:
		_apply_power(bunker.get_node(path + "/Interaction"))


func _use(target: OutpostInteractable) -> void:
	match target.kind:
		&"terminal":
			if target.station_id == &"life_support":
				get_parent().get_node("LifeSupportPanel").open()
			else:
				ui.open(target)
		&"switch":
			target.toggle_power()
		&"door":
			var airlock := bunker.get_node("Airlock")
			if airlock.opened_side == &"inner":
				airlock.request_close()
			else:
				airlock.request_open(&"inner")
