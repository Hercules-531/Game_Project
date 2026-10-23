extends CanvasLayer
signal resume_requested
signal menu_requested
signal settings_requested
signal retry_requested
var panel: PanelContainer
var status: Label
var retry: Button
var back: Button
var automatic_presentations := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 35
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
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",10)
	margin.add_child(rows)
	var title := Label.new()
	title.text = "RESTORATION COMPLETE"
	title.add_theme_font_size_override("font_size",30)
	title.modulate = Color(0.7,0.85,0.65)
	rows.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(scroll)
	var text := Label.new()
	text.text = "PROJECT OUTPOST / BUNKER 14\nA game by Hercules-531\n\nSix bands secured. Marquee colonies quiet.\nPerimeters holding. Residual pressure below target.\n\nEngine: Godot  |  Camera: Phantom Camera\nTesting: GUT  |  Operational sound: native synthesis\nSurface art: PSX modular house interior pack,\nTorment Textures, SBS Horror Texture Pack."
	text.add_theme_font_size_override("font_size",16)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(text)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size",14)
	rows.add_child(status)
	retry = _button(rows,"RETRY COMPLETION SAVE",func(): retry_requested.emit())
	_button(rows,"RESUME OPERATIONS",func(): resume_requested.emit())
	_button(rows,"SETTINGS",func(): settings_requested.emit())
	back = _button(rows,"RETURN TO MAIN MENU",func(): menu_requested.emit())
	panel.hide()
func _button(parent: Node, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(action)
	parent.add_child(button)
	return button
func open(saved: bool = true) -> void:
	panel.show()
	retry.visible = not saved
	status.text = "Restoration saved. Continue retains this achievement." if saved else "Completion is not saved yet. Retry before leaving."
	back.grab_focus()
