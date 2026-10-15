extends CanvasLayer
var panel: PanelContainer
var choice: OptionButton
var socket: OptionButton
var readings: Label
@onready var artifacts: Node = get_parent().get_node("Artifacts")
func _ready() -> void:
	layer = 16
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.036,0.029)
	panel.add_theme_stylebox_override("panel",style)
	var theme := Theme.new()
	theme.default_font_size = 16
	panel.theme = theme
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	var title := Label.new()
	title.text = "14 / UNIVERSAL ARTIFACT SOCKETS"
	title.add_theme_font_size_override("font_size",24)
	rows.add_child(title)
	choice = OptionButton.new()
	for id in artifacts.DEFINITIONS:
		choice.add_item(artifacts.DEFINITIONS[id].name)
		choice.set_item_metadata(choice.item_count-1,id)
	rows.add_child(choice)
	socket = OptionButton.new()
	rows.add_child(socket)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(scroll)
	readings = Label.new()
	readings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(readings)
	for entry in [["FIT SELECTED DEVICE",func(): artifacts.fit(_id(),_socket())],["REMOVE FROM SOCKET",func(): artifacts.remove(_socket())],["BACK TO WORKSHOP",func(): panel.hide(); get_parent().get_node("WorkshopPanel").open()]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		rows.add_child(button)
	InputContext.context_changed.connect(func(context: int):
		if context!=InputContext.Context.TERMINAL: panel.hide())
	panel.hide()
func _id() -> String: return choice.get_item_metadata(choice.selected)
func _socket() -> String: return socket.get_item_metadata(socket.selected)
func open() -> void:
	get_parent().get_node("FleetControl").piloting = false
	get_parent().get_node("FleetControl").stop_all()
	InputContext.set_context(InputContext.Context.TERMINAL)
	socket.clear()
	socket.add_item("BUNKER / BREAKER PANEL")
	socket.set_item_metadata(0,"bunker")
	for d in get_parent().get_node("Fleet").get_children():
		socket.add_item(d.identity+" / "+d.hull_id.to_upper())
		socket.set_item_metadata(socket.item_count-1,d.identity)
	panel.show()
	_refresh()
func _process(_delta: float) -> void:
	if panel.visible: _refresh()
func _refresh() -> void:
	var record: Dictionary = artifacts.devices[_id()]
	var fitted: String = artifacts.fitted(_socket())
	var d: Node = get_parent().get_node("Fleet").drone(_socket())
	var context := "breaker" if _socket()=="bunker" else ("heavy" if d!=null and d.hull().external_power else "small")
	var effects := {
		"thermal":{"small":"Cold drain immunity; silent running.","heavy":"10m heat ring; local permafrost thaw.","breaker":"Heating electricity cost reduced 30%."},
		"neural":{"small":"Crisp first-person manual feed / 60 FPS.","heavy":"Direct piloting of the heavy frame.","breaker":"Fleet automation evaluates three times as fast."},
		"photonic":{"small":"Continuous 0.05kW cell trickle.","heavy":"Offsets 20% of external power draw.","breaker":"Continuous 0.25kW auxiliary grid power."}}
	var effect_label := "ACTIVE EFFECT" if record.state=="fitted" and record.socket==_socket() else "EFFECT IF FITTED"
	readings.text = "DEVICE / %s\nSELECTED SOCKET / %s\n\n%s / %s\n\n" % [record.state.to_upper(),artifacts.DEFINITIONS[fitted].name if not fitted.is_empty() else "EMPTY",effect_label,effects[_id()][context]]
	readings.text += "One universal socket per hull and breaker panel.\nDevices must be recovered and unloaded first.\nFitting and removal require home workshop / gantry.\n\n"+artifacts.status
