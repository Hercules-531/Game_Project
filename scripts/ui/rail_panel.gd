extends CanvasLayer
var panel: PanelContainer
var hubs: OptionButton
var packs: OptionButton
var readings: Label
var charging: CheckButton
var build_button: Button
var feed_button: Button
var clock := 0.0
@onready var rail: Node = get_parent().get_node("Rail")
func _ready() -> void:
	layer = 18
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
	title.text = "14 / RAIL & DEPOT POWER"
	title.add_theme_font_size_override("font_size",24)
	rows.add_child(title)
	hubs = OptionButton.new()
	hubs.item_selected.connect(func(_index: int): _refresh())
	rows.add_child(hubs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	readings = Label.new()
	readings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(readings)
	charging = CheckButton.new()
	charging.text = "HOME PACK CHARGING / MAX 1 kW"
	charging.toggled.connect(func(value: bool): rail.set_charging(value))
	rows.add_child(charging)
	packs = OptionButton.new()
	rows.add_child(packs)
	feed_button = _button(rows,"FEED SELECTED PACK TO LOCAL PYLON",func():
		if packs.selected>=0: rail.feed_pylon(hubs.selected,int(packs.get_item_metadata(packs.selected)))
		_refresh())
	build_button = _button(rows,"BUILD FREIGHT CAR / 40 SCRAP",func(): rail.construct_car(); _refresh())
	_button(rows,"FREIGHT RULES / FIELD SERVICES",func(): get_parent().get_node("FreightPanel").open())
	_button(rows,"PASSENGER RETROFIT / 25 SCRAP / 90s",func(): get_parent().get_node("Passenger").construct())
	_button(rows,"BACK TO FLEET",func(): panel.hide(); get_parent().get_node("FleetPanel").open())
	InputContext.context_changed.connect(func(context: int):
		if context!=InputContext.Context.TERMINAL: panel.hide())
	panel.hide()
func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)
	return button
func open() -> void:
	get_parent().get_node("FleetControl").piloting = false
	get_parent().get_node("FleetControl").stop_all()
	InputContext.set_context(InputContext.Context.TERMINAL)
	panel.show()
	_refresh()
func _process(delta: float) -> void:
	if not panel.visible: return
	clock -= delta
	if clock<=0:
		clock = 0.25
		_refresh()
func _refresh() -> void:
	var selection := hubs.selected
	if hubs.item_count!=rail.hub_count():
		hubs.clear()
		for i in rail.hub_count(): hubs.add_item("HOME" if i==0 else "DEPOT %d / BAND %d" % [i,i+1])
		if selection>=0 and selection<hubs.item_count: hubs.select(selection)
	var hub := hubs.selected
	var depot: Node = rail.stock(hub)
	readings.text = "No finished tunnel. Earn surface ground and excavate its route first." if depot==null else "WIRED / %s\nSTOCK / %d SCRAP / %.1f RATIONS / %.1f FUEL\nSPARES / %d\nPACKS / %d × 1 kWh / 10 kg EACH\n" % ["CONNECTED" if rail.connected(hub) else "LINE FAILED",depot.scrap,depot.rations,depot.fuel,depot.parts.size(),depot.cells.size()]
	readings.text += "\nGRID SERVICES / %.3f kW\n" % rail.life.rail_load_kw
	readings.text += "CAR / COMMISSIONED\n" if rail.car_built else ("CAR / %.1f POWERED SECONDS LEFT\n" % rail.car_remaining if rail.car_remaining>0 else "CAR / NOT BUILT\n")
	readings.text += "\n"+rail.status
	var passenger: Node = get_parent().get_node("Passenger")
	readings.text += "\nPASSENGER / " + ("SEALED HATCH IN LIFE SUPPORT" if passenger.installed else ("%.1fs ASSEMBLY LEFT" % passenger.remaining if passenger.remaining>0 else "RETROFIT REQUIRED"))
	var selected_serial: int = int(packs.get_item_metadata(packs.selected)) if packs.selected>=0 else -1
	packs.clear()
	if depot!=null:
		for pack in depot.cells:
			packs.add_item("PACK %d / %.3f kWh" % [pack.serial,pack.charge])
			packs.set_item_metadata(packs.item_count-1,pack.serial)
			if int(pack.serial)==selected_serial: packs.select(packs.item_count-1)
	if packs.item_count==0: packs.add_item("NO PORTABLE PACKS AT THIS HUB"); packs.set_item_metadata(0,-1)
	charging.set_pressed_no_signal(rail.charge_on)
	charging.disabled = rail.hub_count()==0
	build_button.disabled = rail.car_built or rail.car_remaining>0 or rail.hub_count()<2
	feed_button.disabled = hub<=0 or not rail.connected(hub) or int(packs.get_item_metadata(packs.selected))<0
