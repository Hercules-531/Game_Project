extends CanvasLayer
var panel: PanelContainer
var readings: Label
@onready var sectors: Node = get_parent().get_node("Trace")

func _ready() -> void:
	layer = 13
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
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side,16)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	var title := Label.new()
	title.text = "14 / EMISSIONS AND SURVEYS"
	title.add_theme_font_size_override("font_size",24)
	rows.add_child(title)
	readings = Label.new()
	readings.add_theme_font_size_override("font_size",14)
	readings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(readings)
	var hint := Label.new()
	hint.text = "Silent movement cuts vibration; shield a utility socket for radio.\nNest clocks keep advancing in quiet sectors. Survey with optics."
	hint.add_theme_font_size_override("font_size",14)
	rows.add_child(hint)
	var back := Button.new()
	back.text = "BACK TO OPERATIONS"
	back.pressed.connect(func(): panel.hide(); get_parent().get_node("FleetPanel").open())
	rows.add_child(back)
	InputContext.context_changed.connect(func(context: int):
		if context != InputContext.Context.TERMINAL: panel.hide())
	panel.hide()

func open() -> void:
	get_parent().get_node("FleetControl").piloting = false
	get_parent().get_node("FleetControl").stop_all()
	InputContext.set_context(InputContext.Context.TERMINAL)
	panel.show()
	_refresh()

func _process(_delta: float) -> void:
	if panel.visible: _refresh()

func _refresh() -> void:
	readings.text = "OWN EMISSIONS / sector trace estimate\n"
	for index in 6:
		readings.text += "BAND %d / N%d–%dm / TRACE %.1f\n" % [index + 1,index * 100,(index + 1) * 100,sectors.trace[index]]
		var nest: Node = sectors.nests[index]
		if nest.intel.is_empty():
			readings.text += "No linked optical survey.\n"
		else:
			readings.text += "Survey: %s / growth %d / seen %d / %ds ago\n" % [nest.intel.state.to_upper(),nest.intel.growth,nest.intel.patrols,int(sectors.clock - nest.surveyed_at)]
	readings.text = readings.text.strip_edges()
