extends CanvasLayer
var panel: PanelContainer
var receivers: OptionButton
var donors: OptionButton
var info: Label
@onready var tether: Node = get_parent().get_node("PowerTether")
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
	for side in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	var title := Label.new()
	title.text = "14 / POWER CONVOY"
	title.add_theme_font_size_override("font_size",26)
	rows.add_child(title)
	receivers = OptionButton.new()
	donors = OptionButton.new()
	rows.add_child(receivers)
	rows.add_child(donors)
	info = Label.new()
	info.add_theme_font_size_override("font_size",16)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(info)
	for item in [["CONNECT UMBILICAL",func(): tether.attach(_id(receivers),_id(donors))],["RELEASE CABLE",func(): tether.release(_id(receivers))],["BACK TO OPERATIONS",func(): panel.hide(); get_parent().get_node("FleetPanel").open()]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(item[1])
		rows.add_child(button)
	InputContext.context_changed.connect(func(context: int):
		if context != InputContext.Context.TERMINAL: panel.hide())
	panel.hide()
func _id(choice: OptionButton) -> String:
	return str(choice.get_item_metadata(choice.selected)) if choice.selected >= 0 else ""
func open() -> void:
	get_parent().get_node("FleetControl").piloting = false
	get_parent().get_node("FleetControl").stop_all()
	InputContext.set_context(InputContext.Context.TERMINAL)
	receivers.clear()
	donors.clear()
	for drone in get_parent().get_node("Fleet").get_children():
		var choice: OptionButton = receivers if drone.hull().external_power else (donors if drone.hull_id=="tender" else null)
		if choice != null:
			choice.add_item(drone.identity)
			choice.set_item_metadata(choice.item_count-1,drone.identity)
	panel.show()
func _process(_delta: float) -> void:
	if not panel.visible: return
	var bank: Node = get_parent().get_node("Fleet").drone(_id(donors))
	var linked: bool = bank != null and get_parent().get_node("Radio").quality(bank) > 0.0
	var reading: String = "%.2f / %.2f kWh" % [bank.battery,bank.hull().battery_kwh] if linked else "NO LIVE TELEMETRY"
	var report: String = tether.status if linked else "STATUS UNAVAILABLE / RADIO LOST"
	info.text = "Heavy hulls use standing orders. Keep the tender close.\nConnect within 4m; cable breaks beyond 6m.\n64kW port / 90% transfer efficiency.\n\nBANK / "+reading+"\n"+report+"\n\nFabricate at the workshop; service heavy hulls at the gantry."
