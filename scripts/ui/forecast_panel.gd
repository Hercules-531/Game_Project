extends CanvasLayer
var panel: PanelContainer
var readings: Label
@onready var weather: Node = get_parent().get_node("Weather")
func _ready() -> void:
	layer = 13
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
	for side in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_" + side,20)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	var title := Label.new()
	title.text = "14 / SURFACE FORECAST"
	title.add_theme_font_size_override("font_size",26)
	rows.add_child(title)
	readings = Label.new()
	readings.add_theme_font_size_override("font_size",16)
	readings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(readings)
	var solar_controls := HBoxContainer.new()
	rows.add_child(solar_controls)
	var construct := Button.new()
	construct.text = "BUILD COLLECTOR / 24 SCRAP / 60s"
	construct.pressed.connect(func(): get_parent().get_node("Solar").construct(); _refresh())
	solar_controls.add_child(construct)
	var toggle := Button.new()
	toggle.text = "TOGGLE COLLECTOR"
	toggle.pressed.connect(func(): get_parent().get_node("Solar").toggle(); _refresh())
	solar_controls.add_child(toggle)
	var close := Button.new()
	close.text = "BACK TO OPERATIONS"
	close.pressed.connect(func(): panel.hide(); get_parent().get_node("FleetPanel").open())
	rows.add_child(close)
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
	var definition: Dictionary = weather.CATALOG.conditions[weather.current]
	readings.text = "ACTIVE / %s\nWindow remaining: %02d:%02d\n\n%s\n%s\n\n" % [definition.name,int(weather.remaining) / 60,int(weather.remaining) % 60,definition.hazard,definition.exploit]
	var delay: float = weather.remaining
	for event in weather.forecast:
		readings.text += "IN %02d:%02d  /  %s\n" % [int(delay) / 60,int(delay) % 60,weather.CATALOG.conditions[event.id].name]
		delay += event.duration
	readings.text += "\nGEOTHERMAL / LOCAL POCKETS\nZero cold drain; watch for volatile vents and unstable ground."
	var solar: Node = get_parent().get_node("Solar")
	readings.text += "\n\nCOLLECTOR / %.2fkW%s" % [solar.output_kw()," / BUILDING %ds" % ceili(solar.remaining) if solar.remaining > 0 else ((" / ON" if solar.enabled else " / OFF") if solar.installed else " / NOT BUILT")]
