extends CanvasLayer
var panel: PanelContainer
var readings: Label
var credits: Button
var back: Button
@onready var tracker: Node = get_parent().get_node("Restoration")
func _ready() -> void:
	layer = 16
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font_size = 16
	panel.theme = theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.036,0.029)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	var title := Label.new()
	title.text = "14 / RESTORATION"
	title.add_theme_font_size_override("font_size",26)
	title.modulate = Color(0.65,0.88,0.66)
	rows.add_child(title)
	readings = Label.new()
	readings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(readings)
	credits = Button.new()
	credits.text = "VIEW CREDITS"
	credits.pressed.connect(func(): get_parent().get_parent().show_credits())
	rows.add_child(credits)
	back = Button.new()
	back.text = "BACK TO OPERATIONS"
	back.pressed.connect(func(): panel.hide(); get_parent().get_node("FleetPanel").open())
	rows.add_child(back)
	tracker.changed.connect(_refresh)
	InputContext.context_changed.connect(func(context: int):
		if context!=InputContext.Context.TERMINAL: panel.hide())
	panel.hide()
func open() -> void:
	var control: Node = get_parent().get_node("FleetControl")
	control.piloting = false
	control.stop_all()
	InputContext.set_context(InputContext.Context.TERMINAL)
	panel.show()
	_refresh()
func _refresh() -> void:
	var state: Dictionary = tracker.checklist()
	readings.text = "RESTORATION COMPLETE\n\n" if tracker.completed else "SECURE THE NORTHWARD STRIP\n\n"
	for row in state.bands:
		readings.text += "BAND %d   HELD %s   NEST %s   FENCE %s\n" % [row.band+1,_mark(row.held),_mark(row.quiet),_mark(row.fence)]
	readings.text += "RESIDUAL PRESSURE: %s\nTarget: below %.1f living signatures / 100m.\n\nEvery band needs a quiet marquee nest and an intact\npaid perimeter. Surviving patrols remain dangerous." % ["BELOW TARGET" if state.pressure_clear else "ABOVE TARGET",tracker.DENSITY_LIMIT]
	credits.visible = tracker.completed
func _mark(value: bool) -> String: return "[+]" if value else "[ ]"
