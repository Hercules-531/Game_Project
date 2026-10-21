extends CanvasLayer
var panel: PanelContainer
var edges: OptionButton
var kinds: OptionButton
var workers: OptionButton
var readings: Label
var assign: Button
var cancel: Button
var clock := 0.0
@onready var rail: Node = get_parent().get_node("Rail")
@onready var infrastructure: Node = rail.infrastructure
func _ready() -> void:
	layer = 21
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
	title.text = "14 / INFRASTRUCTURE SERVICE"
	title.add_theme_font_size_override("font_size",24)
	rows.add_child(title)
	var route := HBoxContainer.new()
	rows.add_child(route)
	edges = _choice(route)
	kinds = _choice(route)
	kinds.add_item("RAIL")
	kinds.add_item("CONDUIT")
	workers = _choice(rows)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	readings = Label.new()
	readings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(readings)
	assign = _button(rows,"ASSIGN PAID MAINTENANCE",func():
		if workers.selected>=0: infrastructure.request(_kind(),edges.selected,str(workers.get_item_metadata(workers.selected)))
		_refresh())
	cancel = _button(rows,"CANCEL / NO MATERIAL REFUND",func(): infrastructure.cancel(_kind(),edges.selected); _refresh())
	_button(rows,"ISOLATE / RECONNECT CONDUIT",func(): infrastructure.toggle_isolation(edges.selected); _refresh())
	_button(rows,"BACK TO RAIL POWER",func(): panel.hide(); get_parent().get_node("RailPanel").open())
	InputContext.context_changed.connect(func(context: int):
		if context!=InputContext.Context.TERMINAL: panel.hide())
	panel.hide()
func _choice(parent: Node) -> OptionButton:
	var choice := OptionButton.new()
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.item_selected.connect(func(_index: int): _refresh())
	parent.add_child(choice)
	return choice
func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)
	return button
func _kind() -> String: return "rail" if kinds.selected==0 else "wire"
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
		clock = 0.2
		_refresh()
func _refresh() -> void:
	if edges.item_count!=rail.dig.segments.size():
		var selected := edges.selected
		edges.clear()
		for edge in rail.dig.segments.size(): edges.add_item("LINE %d / %s → DEPOT %d" % [edge,"HOME" if edge==0 else "DEPOT %d" % edge,edge+1])
		if selected>=0 and selected<edges.item_count: edges.select(selected)
	var id: Variant = workers.get_item_metadata(workers.selected) if workers.selected>=0 else null
	workers.clear()
	for d in get_parent().get_node("Fleet").get_children():
		workers.add_item(d.identity+" / "+d.hull_id.to_upper())
		workers.set_item_metadata(workers.item_count-1,d.identity)
		if d.identity==id: workers.select(workers.item_count-1)
	var edge := edges.selected
	assign.disabled = edge<0
	cancel.disabled = edge<0
	if edge<0:
		readings.text = "No completed rail segment."
		return
	var linked: bool = rail.wired(edge)
	var key := _kind()+str(edge)
	var job: Dictionary = infrastructure.jobs.get(key,{})
	readings.text = "SOURCE PORT / %s\n" % ("HOME" if edge==0 else "DEPOT %d" % edge)
	readings.text += "BREAKER / %s\n" % ("ISOLATED" if infrastructure.isolations[str(edge)] else "CONNECTED")
	if linked:
		var value: float = infrastructure.condition(_kind(),edge)
		var fault: float = infrastructure.faults(_kind()).get(str(edge),0.0)
		var quote: Dictionary = infrastructure.Job.quote(value,fault>0,infrastructure.length(edge))
		readings.text += "CONDITION / %.2f%%\nCYCLE FAULT RISK / %.0f%%\nFAULT / %.1fs\n" % [value,infrastructure.Part.malfunction_chance(value)*100,fault]
		readings.text += "LOCAL STOCK / %d SCRAP\nQUOTE / %d SCRAP / %.1fs\n" % [rail.stock(edge).scrap,quote.scrap,quote.seconds]
		if not job.is_empty(): readings.text += "PAID / %s / %.1fs LEFT / %s\n" % [job.worker,job.remaining,"WORKING" if infrastructure.controls(job.worker) else "HELD"]
		assign.disabled = quote.scrap<=0 or not job.is_empty()
	else:
		readings.text += "NO WIRED REPORT. Restore the upstream conduit.\n"
		assign.disabled = true
	cancel.disabled = job.is_empty()
	readings.text += "\nPOWER LOSSES / %.3f kW\nSHORT DRAW / %.3f kW\n\n" % [infrastructure.loss_kw,infrastructure.short_kw]
	readings.text += "Assign a powered torch hull at the source hub.\nField work needs a founded FOB within 8m.\nThe assignment isolates this component.\n\n"+infrastructure.status
