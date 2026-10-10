extends CanvasLayer
var panel: PanelContainer
var machine: OptionButton
var site: OptionButton
var product: OptionButton
var readings: Label
@onready var territory: Node = get_parent().get_node("Territory")
func _ready() -> void:
	layer = 14
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
	title.text = "14 / NORTHWARD FIELD NETWORK"
	title.add_theme_font_size_override("font_size",24)
	rows.add_child(title)
	machine = OptionButton.new()
	rows.add_child(machine)
	site = OptionButton.new()
	for i in 6:
		site.add_item("HOME / PERIMETER" if i==0 else "BAND %d / PAD E8 N%d" % [i+1,25+100*i])
		site.set_item_metadata(i,i)
	rows.add_child(site)
	product = OptionButton.new()
	product.add_item("PYLON / 600kg / 80 SCRAP / 180s")
	product.set_item_metadata(0,"pylon")
	product.add_item("FOB / 1400kg / 150 SCRAP / 300s")
	product.set_item_metadata(1,"fob")
	product.add_item("PERIMETER / 800kg / 60 SCRAP / 240s")
	product.set_item_metadata(2,"perimeter")
	rows.add_child(product)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(scroll)
	readings = Label.new()
	readings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(readings)
	_buttons(rows,[["ANCHOR DISH SCOUT",func(): territory.anchor(_id(),_band())],["RELEASE SCOUT",func(): territory.release_relay(_id())],["LOAD PREFAB AT HOME",func(): territory.load_prefab(_id(),product.get_item_metadata(product.selected))]])
	_buttons(rows,[["CONSTRUCT AT PAD",func(): territory.construct(_id(),_band())],["CONNECT PYLON CABLE",func(): territory.attach_power(_id(),_band())],["RELEASE CABLE",func(): territory.release_power(_id())]])
	_buttons(rows,[["BACK TO FLEET",func(): panel.hide(); get_parent().get_node("FleetPanel").open()]])
	InputContext.context_changed.connect(func(context: int):
		if context != InputContext.Context.TERMINAL: panel.hide())
	panel.hide()
func _buttons(parent: Node, entries: Array) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	for entry in entries:
		var button := Button.new()
		button.text = entry[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(entry[1])
		row.add_child(button)
func _id() -> String:
	return machine.get_item_metadata(machine.selected) if machine.selected >= 0 else ""
func _band() -> int: return site.get_item_metadata(site.selected)
func open() -> void:
	get_parent().get_node("FleetControl").piloting = false
	get_parent().get_node("FleetControl").stop_all()
	InputContext.set_context(InputContext.Context.TERMINAL)
	machine.clear()
	for drone in get_parent().get_node("Fleet").get_children():
		machine.add_item(drone.identity + " / " + drone.hull_id.to_upper())
		machine.set_item_metadata(machine.item_count-1,drone.identity)
	panel.show()
	_refresh()
func _process(_delta: float) -> void:
	if panel.visible: _refresh()
func _refresh() -> void:
	var band := _band()
	var record: Dictionary = territory.sites[band]
	var remaining: float = territory.job.get("remaining",0.0)
	readings.text = "FRONTIER / BAND %d    NEXT / %s\nSELECTED / %s / %s\n" % [territory.frontier()+1,str(territory.frontier()+2) if territory.frontier()<5 else "COMPLETE","HELD" if record.held else "UNCLAIMED","LINKED" if territory.online(band) else "OFFLINE"]
	readings.text += "PYLON / %s / %.2f OF 12kWh / %s\nFOB / %s\n" % ["BUILT" if record.pylon else "ABSENT",record.battery,"CONDUIT CONNECTED" if territory.wired(band) else "NO GRID FEED","BUILT" if record.fob else "ABSENT"]
	readings.text += "PREFAB / %s\nJOB / %s\n\n%s" % [str(territory.cargo.get(_id(),"NONE")).to_upper(),"%.0fs POWERED WORK REMAINS" % remaining if not territory.job.is_empty() else "READY",territory.status]
