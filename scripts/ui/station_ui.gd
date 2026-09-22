extends CanvasLayer

var active_station: OutpostInteractable
var panel: PanelContainer
var title: Label
var body: Label
var power_button: Button
var prompt: Label
var crosshair: Label


func _ready() -> void:
	layer = 10
	var theme := Theme.new()
	theme.default_font_size = 24
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.theme = theme
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.025,0.045,0.039,1)
	background.border_color = Color(0.35,0.5,0.4)
	background.set_border_width_all(4)
	panel.add_theme_stylebox_override("panel",background)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side,24)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",16)
	margin.add_child(rows)
	title = Label.new()
	title.add_theme_font_size_override("font_size",30)
	title.modulate = Color(0.65,0.88,0.66)
	rows.add_child(title)
	body = Label.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size",22)
	rows.add_child(body)
	power_button = Button.new()
	power_button.pressed.connect(_toggle_power)
	rows.add_child(power_button)
	var exit_button := Button.new()
	exit_button.text = "LEAVE PANEL  [ESC]"
	exit_button.pressed.connect(close)
	rows.add_child(exit_button)
	panel.hide()
	prompt = Label.new()
	prompt.position = Vector2(16,432)
	prompt.size = Vector2(608,40)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size",22)
	add_child(prompt)
	crosshair = Label.new()
	crosshair.position = Vector2(314,220)
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size",20)
	add_child(crosshair)
	InputContext.context_changed.connect(_context_changed)


func show_target(target: OutpostInteractable) -> void:
	prompt.text = "[E] " + target.display_name if target != null else ""


func open(station: OutpostInteractable) -> void:
	active_station = station
	InputContext.set_context(InputContext.Context.TERMINAL)
	panel.show()
	_refresh()
	power_button.grab_focus()


func close() -> void:
	panel.hide()
	active_station = null
	InputContext.set_context(InputContext.Context.WALK)


func _context_changed(context: int) -> void:
	crosshair.visible = context == InputContext.Context.WALK
	prompt.visible = crosshair.visible
	if context != InputContext.Context.TERMINAL:
		panel.hide()
		active_station = null


func _toggle_power() -> void:
	if active_station != null:
		active_station.toggle_power()
		_refresh()


func _refresh() -> void:
	title.text = active_station.display_name.to_upper()
	var descriptions := {
		&"command": "REMOTE OPERATIONS\n\nCoordinate machines from the bunker.\nFleet connections: offline.",
		&"workshop": "FABRICATION / REPAIR\n\nConfigure hull sockets and service parts.\nCargo arrives through the airlock.",
		&"life_support": "OXYGEN / HEAT / POWER\n\nKeep the bunker supplied.\nControls remain local during radio loss."
	}
	body.text = descriptions.get(active_station.station_id, "LOCAL CONTROL") if active_station.powered else "PANEL SUPPLY OFF\n\nRestore panel power to view instruments."
	power_button.text = "PANEL POWER: " + ("ON" if active_station.powered else "OFF")
