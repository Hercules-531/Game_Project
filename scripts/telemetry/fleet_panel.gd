extends CanvasLayer

var panel: PanelContainer
var selector: OptionButton
var instruments: Label
var feed: Control
var message: Label
var pilot: CheckButton
var tier_zero: Control
var ccd_display: TextureRect
var charging: CheckButton
var telemetry: Dictionary = {}
@onready var control: Node = get_parent().get_node("FleetControl")


func _ready() -> void:
	layer = 12
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font_size = 18
	panel.theme = theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.036,0.029)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side,16)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	var heading := Label.new()
	heading.text = "14 / REMOTE OPERATIONS"
	heading.add_theme_font_size_override("font_size",26)
	heading.modulate = Color(0.65,0.88,0.66)
	rows.add_child(heading)
	var toolbar := HBoxContainer.new()
	rows.add_child(toolbar)
	selector = OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.item_selected.connect(func(index: int): control.select(selector.get_item_metadata(index)))
	toolbar.add_child(selector)
	_button(toolbar,"DEPLOY",func(): control.request_transfer(true); _refresh())
	_button(toolbar,"DOCK",func(): control.request_transfer(false); _refresh())
	_button(toolbar,"RECOVER CASE",func():
		control.request_action("camera")
		_refresh())
	_button(toolbar,"SALVAGE",func(): control.request_action("salvage"))
	charging = CheckButton.new()
	charging.text = "CHARGE AT HOME"
	charging.button_pressed = true
	charging.toggled.connect(func(value: bool): get_parent().get_node("DronePower").charge_on = value)
	rows.add_child(charging)
	instruments = Label.new()
	instruments.add_theme_font_size_override("font_size",16)
	rows.add_child(instruments)
	feed = PanelContainer.new()
	feed.custom_minimum_size = Vector2(0,185)
	feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(feed)
	var blind := Label.new()
	blind.name = "NoOptics"
	blind.text = "NO OPTICAL SENSOR\nUse instruments."
	blind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blind.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feed.add_child(blind)
	blind.hide()
	tier_zero = preload("res://scripts/sensors/tier_zero_feed.gd").new()
	tier_zero.control = control
	feed.add_child(tier_zero)
	ccd_display = TextureRect.new()
	ccd_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ccd_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var degradation := ShaderMaterial.new()
	degradation.shader = preload("res://shaders/ccd_feed.gdshader")
	ccd_display.material = degradation
	feed.add_child(ccd_display)
	var optical_label := Label.new()
	optical_label.position = Vector2(6,6)
	optical_label.text = "CCD / 15 FPS"
	optical_label.add_theme_font_size_override("font_size",14)
	optical_label.modulate = Color(0.65,0.85,0.68)
	ccd_display.add_child(optical_label)
	ccd_display.hide()
	var driving := HBoxContainer.new()
	rows.add_child(driving)
	_button(driving,"RESCUE",func(): get_parent().get_node("RecoveryPanel").open())
	pilot = CheckButton.new()
	pilot.text = "PILOT / WASD"
	pilot.toggled.connect(func(value: bool): control.piloting = value)
	driving.add_child(pilot)
	_button(driving,"PING",func(): tier_zero.ping())
	for item in [["LEFT",Vector2(-1,0)],["FWD",Vector2(0,-1)],["BACK",Vector2(0,1)],["RIGHT",Vector2(1,0)]]:
		var button := Button.new()
		button.text = item[0]
		var direction: Vector2 = item[1]
		button.button_down.connect(func(): control.held = direction)
		button.button_up.connect(func(): control.held = Vector2.ZERO)
		driving.add_child(button)
	message = Label.new()
	message.add_theme_font_size_override("font_size",16)
	rows.add_child(message)
	_button(rows,"LEAVE DESK  [ESC]",close)
	control.changed.connect(_refresh)
	InputContext.context_changed.connect(func(context: int):
		if context != InputContext.Context.TERMINAL:
			panel.hide())
	panel.hide()


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func open() -> void:
	InputContext.set_context(InputContext.Context.TERMINAL)
	control.panel_open = true
	panel.show()
	selector.clear()
	for machine in control.fleet.get_children():
		selector.add_item(machine.identity.to_upper())
		selector.set_item_metadata(selector.item_count - 1,machine.identity)
		if machine.identity == control.selected_id:
			selector.select(selector.item_count - 1)
	_refresh()


func close() -> void:
	control.stop_all()
	panel.hide()
	InputContext.set_context(InputContext.Context.WALK)


func _process(_delta: float) -> void:
	if panel.visible:
		_refresh()


func _refresh() -> void:
	var machine: Node = control.selected()
	if machine == null:
		instruments.text = "NO MACHINE"
		return
	instruments.text = "%s  |  CELL %.2f / %.2f kWh  |  N %.1fm  E %.1fm\nHEADING %03d  |  PAYLOAD %.0fkg FREE  |  %.2fkW" % ["FIELD" if machine.deployed else "WORKSHOP",machine.battery,machine.hull().battery_kwh,-machine.position.z - 10,machine.position.x,posmod(int(rad_to_deg(machine.rotation.y)),360),machine.payload_remaining(),get_parent().get_node("DronePower").draw_kw(machine)]
	message.text = control.status if control.transfer.is_empty() else "SEALED TRANSFER  %.1fs" % control.transfer.remaining
	pilot.set_pressed_no_signal(control.piloting)
	charging.set_pressed_no_signal(get_parent().get_node("DronePower").charge_on)
	var signal_quality: float = get_parent().get_node("Radio").quality(machine)
	if signal_quality > 0.0:
		telemetry[machine.identity] = instruments.text
		instruments.text += "  |  LINK %d%%" % int(signal_quality * 100)
		if not machine.faults.is_empty():
			message.text = "FAULT / " + ", ".join(machine.faults.keys())
	else:
		instruments.text = "LINK LOST / LAST TELEMETRY\n" + telemetry.get(machine.identity,"No telemetry received.").get_slice("\n",0)
	var optical: bool = preload("res://scripts/sensors/sensor_router.gd").tier(machine) > 0
	var live: bool = machine.battery > 0.0 and signal_quality > 0.0
	if optical and machine.module_efficiency("ccd") <= 0.0:
		live = false
	tier_zero.visible = not optical and live
	ccd_display.visible = optical and live
	feed.get_node("NoOptics").visible = not live
	feed.get_node("NoOptics").text = "CELL EMPTY / MACHINE STRANDED" if machine.deployed else "CHARGING REQUIRED"
	if signal_quality <= 0.0:
		feed.get_node("NoOptics").text = "LINK LOST / SENSOR DATA UNAVAILABLE"
	elif optical and machine.module_efficiency("ccd") <= 0.0:
		feed.get_node("NoOptics").text = "CCD FAULT / NO NEW FRAMES"
	if optical:
		var sensor: Node = machine.get_node("CCD")
		ccd_display.texture = sensor.viewport.get_texture() if sensor.viewport != null else null
		ccd_display.material.set_shader_parameter("frame_tick",float(sensor.frame_count))
		ccd_display.material.set_shader_parameter("interference",1.0 - signal_quality)
		ccd_display.material.set_shader_parameter("lens_efficiency",maxf(0.1,machine.module_efficiency("ccd")))
