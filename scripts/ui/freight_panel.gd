extends CanvasLayer
var panel: PanelContainer
var source: OptionButton
var target: OptionButton
var kind: OptionButton
var module: OptionButton
var minimum: SpinBox
var batch: SpinBox
var rules: ItemList
var report: Label
var hubs: OptionButton
var workers: OptionButton
var auto_feed: CheckButton
var auto_unload: CheckButton
var depot_report: Label
var clock := 0.0
@onready var rail: Node = get_parent().get_node("Rail")
func _ready() -> void:
	layer = 19
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.036,0.029)
	panel.add_theme_stylebox_override("panel",style)
	var theme := Theme.new()
	theme.default_font_size = 15
	panel.theme = theme
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	_label(rows,"14 / AUTOMATIC UNDERGROUND FREIGHT")
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(tabs)
	var supply := VBoxContainer.new()
	supply.name = "SUPPLY RULES"
	tabs.add_child(supply)
	rules = ItemList.new()
	rules.custom_minimum_size.y = 70
	supply.add_child(rules)
	var route := HBoxContainer.new()
	supply.add_child(route)
	source = _choice(route)
	target = _choice(route)
	var goods := HBoxContainer.new()
	supply.add_child(goods)
	kind = _choice(goods)
	for entry in [["SCRAP","scrap"],["RATIONS","rations"],["FUEL","fuel"],["SPARE PART","part"],["CHARGED PACKS","charged"],["EMPTY PACKS","empty"]]:
		kind.add_item(entry[0]); kind.set_item_metadata(kind.item_count-1,entry[1])
	module = _choice(goods)
	for definition in rail.Inventory.CATALOG.modules:
		module.add_item(definition.display_name)
		module.set_item_metadata(module.item_count-1,definition.id)
	kind.item_selected.connect(func(_index: int): module.disabled = _kind()!="part")
	module.disabled = true
	var amounts := HBoxContainer.new()
	supply.add_child(amounts)
	_label(amounts,"KEEP AT LEAST")
	minimum = _number(amounts,1000000,10)
	_label(amounts,"BATCH LIMIT")
	batch = _number(amounts,200,10)
	_button(supply,"ADD REPLENISHMENT RULE",func():
		rail.freight.add_rule(source.selected,target.selected,_kind(),int(minimum.value),int(batch.value),str(module.get_item_metadata(module.selected)) if _kind()=="part" else "")
		_refresh())
	_button(supply,"ENABLE / DISABLE SELECTED RULE",func():
		if not rules.get_selected_items().is_empty(): rail.freight.toggle_rule(int(rules.get_item_metadata(rules.get_selected_items()[0])))
		_refresh())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	supply.add_child(scroll)
	report = _label(scroll,"")
	var services := VBoxContainer.new()
	services.name = "FIELD DEPOT"
	tabs.add_child(services)
	hubs = _choice(services)
	workers = _choice(services)
	hubs.item_selected.connect(func(_index: int): _refresh())
	depot_report = _label(services,"")
	depot_report.size_flags_vertical = Control.SIZE_EXPAND_FILL
	auto_feed = CheckButton.new()
	auto_feed.text = "AUTOMATIC PACK → PYLON / 90% EFFICIENCY"
	auto_feed.toggled.connect(func(value: bool):
		if hubs.selected>0: rail.auto_feed[str(hubs.selected)] = value)
	services.add_child(auto_feed)
	auto_unload = CheckButton.new()
	auto_unload.text = "AUTOMATIC RESOURCE / STRIPPED-PART UNLOAD"
	auto_unload.toggled.connect(func(value: bool):
		if hubs.selected>0: rail.auto_unload[str(hubs.selected)] = value)
	services.add_child(auto_unload)
	_button(services,"UNLOAD SELECTED HULL AT ITS LOCAL FOB",func():
		if workers.selected>=0: rail.unload_drone(str(workers.get_item_metadata(workers.selected)))
		_refresh())
	_button(services,"OPEN FIT / REPAIR USING HULL'S LOCAL STOCK",func():
		var ui: Node = get_parent().get_node("WorkshopPanel")
		panel.hide()
		get_parent().get_node("RailPanel").panel.hide()
		get_parent().get_node("FleetPanel").panel.hide()
		ui.open()
		for i in ui.machine_choice.item_count:
			if ui.machine_choice.get_item_metadata(i)==workers.get_item_metadata(workers.selected): ui.machine_choice.select(i)
		ui.machine_choice.item_selected.emit(ui.machine_choice.selected))
	_button(rows,"BACK TO RAIL POWER",func(): panel.hide(); get_parent().get_node("RailPanel").open())
	InputContext.context_changed.connect(func(context: int):
		if context!=InputContext.Context.TERMINAL: panel.hide())
	panel.hide()
func _label(parent: Node, caption: String) -> Label:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label
func _choice(parent: Node) -> OptionButton:
	var box := OptionButton.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box
func _number(parent: Node, maximum: int, value: int) -> SpinBox:
	var number := SpinBox.new()
	number.min_value = 1
	number.max_value = maximum
	number.value = value
	parent.add_child(number)
	return number
func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)
	return button
func _kind() -> String: return str(kind.get_item_metadata(kind.selected))
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
func _fill_hubs(box: OptionButton) -> void:
	if box.item_count==rail.hub_count(): return
	var selected := box.selected
	box.clear()
	for i in rail.hub_count(): box.add_item("HOME" if i==0 else "DEPOT %d" % i)
	if selected>=0 and selected<box.item_count: box.select(selected)
func _refresh() -> void:
	for box in [source,target,hubs]: _fill_hubs(box)
	var serial: int = int(rules.get_item_metadata(rules.get_selected_items()[0])) if not rules.get_selected_items().is_empty() else -1
	rules.clear()
	for rule in rail.freight.rules:
		rules.add_item("%s #%d / %d → %d / %s / MIN %d / BATCH %d" % ["ON" if rule.enabled else "OFF",rule.serial,rule.source,rule.target,rule.module if rule.kind=="part" else rule.kind.to_upper(),rule.minimum,rule.batch])
		rules.set_item_metadata(rules.item_count-1,rule.serial)
		if int(rule.serial)==serial: rules.select(rules.item_count-1)
	report.text = "CAR / %s\nPOSITION / %.1fm / PAID MOTION / %.3fs\n" % ["COMMISSIONED" if rail.car_built else "BUILD AT RAIL POWER PANEL",rail.freight.coordinate,rail.freight.credit]
	var job: Dictionary = rail.freight.job
	report.text += "IDLE / WAITING FOR SUPPLY OR DEMAND" if job.is_empty() else "RULE %d / %s / %s\n%s" % [job.serial,job.phase.to_upper(),job.kind.to_upper(),"CARGO HELD UNTIL DESTINATION HAS SPACE" if job.phase=="delivery" and absf(rail.freight.coordinate-rail.freight.target_coordinate())<0.001 else "PHYSICAL TRANSIT / FINITE GRID POWER"]
	var old: Variant = workers.get_item_metadata(workers.selected) if workers.selected>=0 else null
	workers.clear()
	for drone in get_parent().get_node("Fleet").get_children():
		workers.add_item(drone.identity)
		workers.set_item_metadata(workers.item_count-1,drone.identity)
		if drone.identity==old: workers.select(workers.item_count-1)
	var depot: Node = rail.stock(hubs.selected)
	depot_report.text = "NO EXCAVATED DEPOT" if depot==null else "STOCK / %d SCRAP / %.1f RATIONS / %.1f FUEL\n%d PARTS / %d PACKS\n\nLocal unload and servicing require a founded FOB,\na healthy wired route and a hull within 8m.\nArtifacts and research retain their home recovery path." % [depot.scrap,depot.rations,depot.fuel,depot.parts.size(),depot.cells.size()]
	auto_feed.disabled = hubs.selected<=0
	auto_feed.set_pressed_no_signal(rail.auto_feed.get(str(hubs.selected),false))
	auto_unload.disabled = hubs.selected<=0
	auto_unload.set_pressed_no_signal(rail.auto_unload.get(str(hubs.selected),false))
