extends CanvasLayer

var panel: PanelContainer
var readings: Label
var status: Label
var alarm: Label
var buttons: Dictionary = {}
@onready var life: Node = get_parent().get_node("LifeSupport")


func _ready() -> void:
	layer = 12
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.032,0.029)
	style.border_color = Color(0.27,0.39,0.32)
	style.set_border_width_all(4)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side,24)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",12)
	margin.add_child(rows)
	var heading := Label.new()
	heading.text = "BUNKER / LIFE SUPPORT"
	heading.add_theme_font_size_override("font_size",30)
	heading.modulate = Color(0.7,0.85,0.65)
	rows.add_child(heading)
	readings = Label.new()
	readings.add_theme_font_size_override("font_size",22)
	rows.add_child(readings)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size",18)
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(status)
	for circuit in ["generator_on","oxygen_on","heater_on"]:
		var button := Button.new()
		button.custom_minimum_size.y = 36
		button.add_theme_font_size_override("font_size",20)
		button.pressed.connect(func(): life.set_circuit(circuit,not life.get(circuit)))
		rows.add_child(button)
		buttons[circuit] = button
	var back := Button.new()
	back.text = "LEAVE PANEL [ESC]"
	back.custom_minimum_size.y = 36
	back.add_theme_font_size_override("font_size",20)
	back.pressed.connect(func(): InputContext.set_context(InputContext.Context.WALK))
	rows.add_child(back)
	alarm = Label.new()
	alarm.position = Vector2(16,12)
	alarm.size = Vector2(608,60)
	alarm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	alarm.add_theme_font_size_override("font_size",18)
	alarm.modulate = Color(1.0,0.65,0.35)
	add_child(alarm)
	life.changed.connect(_refresh)
	InputContext.context_changed.connect(_context_changed)
	panel.hide()
	_refresh()


func open() -> void:
	InputContext.set_context(InputContext.Context.TERMINAL)
	panel.show()
	_refresh()
	buttons.generator_on.grab_focus()


func _context_changed(context: int) -> void:
	if context != InputContext.Context.TERMINAL:
		panel.hide()
	_refresh()


func _refresh() -> void:
	readings.text = "OXYGEN  %05.1f%%     CABIN  %04.1f°C\nBATTERY  %.2f / %.1f kWh     LOAD  %.1f kW\nFUEL  %.1f min     RATIONS  %.2f" % [life.oxygen,life.temperature,life.battery,life.balance.battery_capacity,life.load_kw(),life.fuel,life.rations]
	var warning: String = life.warning()
	status.text = warning if not warning.is_empty() else "SYSTEMS NOMINAL / LOCAL CONTROL"
	status.modulate = Color(1.0,0.65,0.35) if not warning.is_empty() else Color(0.7,0.85,0.65)
	var captions := {"generator_on":"GENERATOR","oxygen_on":"OXYGEN RECYCLER","heater_on":"CABIN HEATER"}
	for circuit in buttons:
		buttons[circuit].text = captions[circuit] + ("  [ON]" if life.get(circuit) else "  [OFF]")
	alarm.text = warning
	alarm.visible = not panel.visible and InputContext.active != InputContext.Context.MENU and not warning.is_empty()
