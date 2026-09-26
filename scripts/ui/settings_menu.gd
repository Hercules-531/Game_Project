extends CanvasLayer

signal closed
const ACTION_NAMES := {"move_forward":"FORWARD","move_back":"BACK",
	"move_left":"LEFT","move_right":"RIGHT","interact":"USE"}
var panel: PanelContainer
var status: Label
var key_buttons: Dictionary = {}
var sliders: Dictionary = {}
var readouts: Dictionary = {}
var pending_action: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font_size = 18
	panel.theme = theme
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
	heading.text = "SETTINGS"
	heading.add_theme_font_size_override("font_size",32)
	heading.modulate = Color(0.7,0.85,0.65)
	rows.add_child(heading)
	for bus in ["master","effects","ambience"]:
		_slider(rows,bus,bus.capitalize(),0.0,1.0,0.01)
	_slider(rows,"sensitivity","Mouse sensitivity",0.0005,0.006,0.0001)
	var instruction := Label.new()
	instruction.text = "SELECT A CONTROL, THEN PRESS A KEY"
	instruction.add_theme_font_size_override("font_size",16)
	rows.add_child(instruction)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	rows.add_child(grid)
	for action in ACTION_NAMES:
		var button := Button.new()
		button.custom_minimum_size = Vector2(185,32)
		button.pressed.connect(func():_begin_rebind(action))
		grid.add_child(button)
		key_buttons[action] = button
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size",16)
	rows.add_child(status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",12)
	rows.add_child(buttons)
	for caption in ["RESTORE DEFAULTS","BACK [ESC]"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size.y = 40
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_defaults if caption == "RESTORE DEFAULTS" else close)
		buttons.add_child(button)
	panel.hide()


func _slider(parent: Node, key: String, caption: String, minimum: float,
		maximum: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 170
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.custom_minimum_size.y = 28
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size.x = 68
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)
	sliders[key] = slider
	readouts[key] = readout
	slider.value_changed.connect(func(value: float):
		if key == "sensitivity":
			UserSettings.store.sensitivity = value
		else:
			UserSettings.store.volumes[key] = value
		_save()
		_refresh()
	)


func open() -> void:
	pending_action = ""
	_refresh()
	status.text = "Duplicate keys swap assignments. Escape always goes back."
	panel.show()
	sliders.master.grab_focus()


func close() -> void:
	pending_action = ""
	panel.hide()
	closed.emit()


func _begin_rebind(action: String) -> void:
	pending_action = action
	status.text = "Press a key for %s. Escape cancels." % ACTION_NAMES[action]


func _input(event: InputEvent) -> void:
	if not panel.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		if pending_action.is_empty():
			close()
		else:
			pending_action = ""
			status.text = "Binding unchanged."
		get_viewport().set_input_as_handled()
	elif not pending_action.is_empty():
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if UserSettings.store.rebind(pending_action,key):
			pending_action = ""
			_save()
			_refresh()
		get_viewport().set_input_as_handled()


func _save() -> void:
	status.text = "Settings saved." if UserSettings.apply_and_save() else "Changes applied, but settings could not be saved."


func _defaults() -> void:
	pending_action = ""
	UserSettings.store.reset_defaults()
	_save()
	_refresh()


func _refresh() -> void:
	for action in key_buttons:
		key_buttons[action].text = "%s [%s]" % [ACTION_NAMES[action],OS.get_keycode_string(UserSettings.store.keys[action])]
	for key in sliders:
		var value: float = UserSettings.store.sensitivity if key == "sensitivity" else UserSettings.store.volumes[key]
		sliders[key].set_value_no_signal(value)
		readouts[key].text = "%.1fx" % (value / 0.0025) if key == "sensitivity" else "%d%%" % roundi(value * 100)
