extends CanvasLayer

const CATALOG = preload("res://resources/drones/opening_fleet.tres")
const BOOK = preload("res://resources/balance/recipes.tres")
var panel: PanelContainer
var summary: Label
var status: Label
var machine_choice: OptionButton
var socket_choice: OptionButton
var part_choice: OptionButton
var recipe_choice: OptionButton
var hull_choice: OptionButton
var module_info: Label
var queue_info: Label
var supply_info: Label
var service_button: Button
@onready var world: Node = get_parent()
@onready var inventory: Node = world.get_node("Inventory")
@onready var controller: Node = world.get_node("Workshop")
@onready var queue: Node = world.get_node("Fabrication")


func _ready() -> void:
	layer = 11
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.032,0.029)
	style.border_color = Color(0.27,0.39,0.32)
	style.set_border_width_all(4)
	panel.add_theme_stylebox_override("panel",style)
	var theme := Theme.new()
	theme.default_font_size = 18
	panel.theme = theme
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side,24)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",10)
	margin.add_child(rows)
	var heading := _label(rows,"WORKSHOP / FABRICATION",28)
	heading.modulate = Color(0.7,0.85,0.65)
	summary = _label(rows,"",18)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(tabs)
	var fitting := VBoxContainer.new()
	fitting.name = "FITTING"
	fitting.add_theme_constant_override("separation",8)
	tabs.add_child(fitting)
	tabs.set_tab_title(0,"FIT / REPAIR")
	machine_choice = _choice(fitting)
	socket_choice = _choice(fitting)
	part_choice = _choice(fitting)
	module_info = _label(fitting,"",18)
	module_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var actions := HBoxContainer.new()
	fitting.add_child(actions)
	_button(actions,"FIT PART",func(): _result(controller.fit(_machine(),_socket(),int(_selected(part_choice,0))),"Part fitted."))
	_button(actions,"REMOVE",func(): _result(controller.remove(_machine(),_socket()),"Part returned to stock."))
	service_button = _button(actions,"SERVICE",func(): _result(controller.repair(_machine(),_socket()),"Part serviced."))
	var fabrication := VBoxContainer.new()
	fabrication.name = "FABRICATE"
	fabrication.add_theme_constant_override("separation",8)
	tabs.add_child(fabrication)
	recipe_choice = _choice(fabrication)
	_button(fabrication,"START FABRICATION",func(): _result(queue.start(str(_selected(recipe_choice,""))),"Fabrication started."))
	queue_info = _label(fabrication,"",18)
	queue_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hull_choice = _choice(fabrication)
	_button(fabrication,"ASSEMBLE STOCK HULL",func(): _result(controller.assemble(str(_selected(hull_choice,""))),"Hull assembled in a clear bay."))
	var supplies := VBoxContainer.new()
	supplies.name = "SUPPLIES"
	supplies.add_theme_constant_override("separation",12)
	tabs.add_child(supplies)
	supply_info = _label(supplies,"",20)
	supply_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_button(supplies,"LOAD FUEL / UP TO 10 MIN",func(): _result(controller.resupply("fuel"),"Fuel transferred to generator."))
	_button(supplies,"LOAD RATIONS / UP TO 1 UNIT",func(): _result(controller.resupply("rations"),"Rations transferred to life support."))
	var research_tab := VBoxContainer.new()
	research_tab.name = "RESEARCH"
	tabs.add_child(research_tab)
	_label(research_tab,"Recover manuals and blueprints with field cargo.\nUnload, then pay scrap and powered time to study them.",18)
	_button(research_tab,"OPEN RESEARCH",func(): get_parent().get_node("ResearchPanel").open())
	var artifact_tab := VBoxContainer.new()
	artifact_tab.name = "ARTIFACTS"
	tabs.add_child(artifact_tab)
	_label(artifact_tab,"Recover anomalous devices and fit a universal socket.\nThe effect changes with the hull or bunker panel.",18)
	_button(artifact_tab,"OPEN ARTIFACT SOCKETS",func(): get_parent().get_node("ArtifactPanel").open())
	status = _label(rows,"",16)
	_button(rows,"LEAVE WORKSHOP [ESC]",func(): InputContext.set_context(InputContext.Context.WALK))
	inventory.changed.connect(_refresh)
	controller.changed.connect(_refresh)
	queue.changed.connect(_refresh)
	world.get_node("Research").changed.connect(_refresh)
	InputContext.context_changed.connect(func(context: int):
		if context != InputContext.Context.TERMINAL:
			panel.hide()
	)
	panel.hide()
	_refresh()


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _choice(parent: Node) -> OptionButton:
	var choice := OptionButton.new()
	choice.custom_minimum_size.y = 32
	choice.item_selected.connect(func(_index: int): _refresh())
	parent.add_child(choice)
	return choice


func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 34
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _selected(choice: OptionButton, fallback: Variant) -> Variant:
	return choice.get_item_metadata(choice.selected) if choice.selected >= 0 else fallback


func _machine() -> String:
	return str(_selected(machine_choice,""))


func _socket() -> String:
	return str(_selected(socket_choice,""))


func _fill(choice: OptionButton, entries: Array) -> void:
	var previous: Variant = _selected(choice,null)
	choice.clear()
	for entry in entries:
		choice.add_item(entry[0])
		choice.set_item_metadata(choice.item_count - 1,entry[1])
		if entry[1] == previous:
			choice.select(choice.item_count - 1)
	choice.disabled = entries.is_empty()


func _result(ok: bool, message: String) -> void:
	status.text = message if ok else "Unavailable: check socket, stock, scrap, active job or clear bay."
	_refresh()


func open() -> void:
	InputContext.set_context(InputContext.Context.TERMINAL)
	panel.show()
	status.text = "Fit parts to assign roles. Keep condition above 80% for best performance."
	_refresh()
	machine_choice.grab_focus()


func _refresh() -> void:
	summary.text = "SCRAP  %d    STOCK PARTS  %d    MACHINES  %d" % [inventory.scrap,inventory.parts.size(),world.get_node("Fleet").get_child_count()]
	var machines := []
	for machine in world.get_node("Fleet").get_children():
		machines.append([machine.identity + " / " + machine.hull_id.to_upper(),machine.identity])
	_fill(machine_choice,machines)
	var machine: Node = world.get_node("Fleet").drone(_machine())
	var sockets := []
	if machine != null:
		for socket in machine.hull().sockets:
			sockets.append([socket.to_upper() + " / " + machine.hull().sockets[socket].category,socket])
		for component in machine.components:
			sockets.append(["CHASSIS / " + component.to_upper(),component])
	_fill(socket_choice,sockets)
	var parts := []
	var stock: Node = controller.service_stock(machine)
	for item in (stock.parts if stock!=null else []):
		parts.append(["#%d %s / %d%%" % [item.serial,CATALOG.module(item.id).display_name,int(item.condition)],item.serial])
	_fill(part_choice,parts)
	if stock!=null and stock!=inventory:
		summary.text = "DEPOT / SCRAP %d / PARTS %d | HOME FAB / %d SCRAP" % [stock.scrap,stock.parts.size(),inventory.scrap]
	module_info.text = "NO MACHINE IN BAY"
	if machine != null:
		var socket := _socket()
		var fitted: String = machine.modules.get(socket,"")
		module_info.text = (CATALOG.module(fitted).display_name + " / %d%%" % int(machine.condition[socket]) if not fitted.is_empty() else "SOCKET EMPTY") + "\nPAYLOAD FREE  %.1f kg / %.1f kg    DRAW  %.2f kW" % [machine.payload_remaining(),machine.hull().payload_kg,machine.draw_kw()]
		if machine.components.has(socket):
			module_info.text = "%s / %d%%\nEFFICIENCY %.0f%%" % [socket.to_upper(),int(machine.components[socket]),machine.component_efficiency(socket) * 100.0]
	service_button.text = "SERVICE / %d SCRAP" % controller.repair_cost(_machine(),_socket())
	var recipes := []
	for id in BOOK.recipes:
		var research: Node = world.get_node_or_null("Research")
		if research != null and not research.permits_recipe(id): continue
		var recipe: Dictionary = BOOK.recipes[id]
		recipes.append(["%s / %d SCRAP / %ds" % [id.to_upper(),recipe.scrap,int(recipe.seconds)],id])
	_fill(recipe_choice,recipes)
	queue_info.text = "FABRICATOR READY" if queue.job.is_empty() else "%s\nREADY IN %ds" % [queue.job.recipe.to_upper(),ceili(queue.job.remaining)]
	var hulls := []
	for id in inventory.hulls:
		if inventory.hulls[id] > 0:
			hulls.append(["%s FRAME / STOCK %d" % [id.to_upper(),inventory.hulls[id]],id])
	_fill(hull_choice,hulls)
	supply_info.text = "STORAGE\nFUEL  %.1f min\nRATIONS  %.2f\n\nTransfers consume stock and respect bunker capacity." % [inventory.fuel,inventory.rations]
