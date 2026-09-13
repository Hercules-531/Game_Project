extends CanvasLayer

signal new_game_requested
signal resume_requested
signal main_menu_requested
signal quit_requested

var panel: PanelContainer
var heading: Label
var subtitle: Label
var new_button: Button
var resume_button: Button
var menu_button: Button
var quit_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.032,0.029)
	style.border_color = Color(0.27,0.39,0.32)
	style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side,16)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",6)
	margin.add_child(rows)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size",26)
	heading.modulate = Color(0.7,0.85,0.65)
	rows.add_child(heading)
	subtitle = Label.new()
	subtitle.add_theme_font_size_override("font_size",9)
	subtitle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(subtitle)
	new_button = _button(rows,"NEW GAME",func():new_game_requested.emit())
	resume_button = _button(rows,"RESUME  [ESC]",func():resume_requested.emit())
	menu_button = _button(rows,"RETURN TO MAIN MENU",func():main_menu_requested.emit())
	quit_button = _button(rows,"QUIT",func():quit_requested.emit())


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size",11)
	button.custom_minimum_size.y = 25
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func show_main() -> void:
	panel.show()
	heading.text = "PROJECT OUTPOST"
	subtitle.text = "BUNKER 14 / REMOTE OPERATIONS\n\nSEND MACHINES. BRING THEM HOME."
	new_button.show()
	resume_button.hide()
	menu_button.hide()
	quit_button.show()
	new_button.grab_focus()


func show_pause() -> void:
	panel.show()
	heading.text = "PAUSED"
	subtitle.text = "BUNKER 14 / SIMULATION HELD"
	new_button.hide()
	resume_button.show()
	menu_button.show()
	quit_button.show()
	resume_button.grab_focus()


func hide_menu() -> void:
	panel.hide()
