extends CanvasLayer
var panel: PanelContainer
var workers: OptionButton
var kind: OptionButton
var source: OptionButton
var width: SpinBox
var depth: SpinBox
var height: SpinBox
var readings: Label
var assign_button: Button
var refresh_clock := 0.0
@onready var planner: Node = get_parent().get_node("Excavation")
func _ready() -> void:
	layer = 17
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
	title.text = "14 / DELEGATED EXCAVATION"
	title.add_theme_font_size_override("font_size",24)
	rows.add_child(title)
	workers = OptionButton.new()
	workers.item_selected.connect(_select_worker)
	rows.add_child(workers)
	var route := HBoxContainer.new()
	rows.add_child(route)
	kind = OptionButton.new()
	kind.add_item("STRAIGHT TUNNEL")
	kind.add_item("ROOM FOOTPRINT")
	route.add_child(kind)
	source = OptionButton.new()
	for i in 6:
		source.add_item("HOME" if i==0 else "BAND %d" % (i+1))
		source.set_item_metadata(i,i)
	route.add_child(source)
	var sizes := HBoxContainer.new()
	rows.add_child(sizes)
	width = _size(sizes,"WIDTH",4,20,2,6)
	depth = _size(sizes,"DEPTH",4,20,2,6)
	height = _size(sizes,"HEIGHT",2.4,3.2,0.2,3.2)
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(middle)
	var map := preload("res://scripts/ui/excavation_map.gd").new()
	map.planner = planner
	map.panel = self
	map.custom_minimum_size.x = 180
	middle.add_child(map)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(scroll)
	readings = Label.new()
	readings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(readings)
	for entry in [["ASSIGN PAID JOB",_request],["CANCEL SELECTED HULL'S JOB",func(): planner.cancel(_worker())],["BACK TO FLEET",func(): panel.hide(); get_parent().get_node("FleetPanel").open()]]:
		var button := Button.new()
		button.text = entry[0]
		if entry[0]=="ASSIGN PAID JOB": assign_button = button
		button.pressed.connect(entry[1])
		rows.add_child(button)
	InputContext.context_changed.connect(func(context: int):
		if context!=InputContext.Context.TERMINAL: panel.hide())
	kind.item_selected.connect(func(_index: int): _refresh())
	source.item_selected.connect(func(_index: int): _refresh())
	for dimension in [width,depth,height]:
		dimension.value_changed.connect(func(_value: float): _refresh())
	panel.hide()
func _size(parent: Node, caption: String, minimum: float, maximum: float, step: float, value: float) -> SpinBox:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var label := Label.new()
	label.text = caption
	column.add_child(label)
	var box := SpinBox.new()
	box.min_value = minimum
	box.max_value = maximum
	box.step = step
	box.value = value
	column.add_child(box)
	return box
func _worker() -> String: return str(workers.get_item_metadata(workers.selected)) if workers.selected>=0 else ""
func _select_worker(_index: int) -> void:
	for job in planner.jobs.values():
		if job.worker!=_worker(): continue
		kind.select(0 if job.plan.kind=="tunnel" else 1)
		source.select(int(job.plan.source))
		width.max_value = 10 if job.plan.kind=="tunnel" else 20
		width.value = job.plan.width
		depth.value = job.plan.depth
		height.value = job.plan.height
		break
	_refresh()
func plan() -> Dictionary:
	var start := source.selected
	return {"kind":"tunnel" if kind.selected==0 else "room","source":start,"target":start+1 if kind.selected==0 else start,"width":minf(10,width.value) if kind.selected==0 else width.value,"depth":6.0 if kind.selected==0 else depth.value,"height":height.value}
func _request() -> void:
	var p := plan()
	planner.request(_worker(),p.kind,p.source,p.target,p.width,p.depth,p.height)
	_refresh()
func open() -> void:
	get_parent().get_node("FleetControl").piloting = false
	get_parent().get_node("FleetControl").stop_all()
	InputContext.set_context(InputContext.Context.TERMINAL)
	workers.clear()
	for d in get_parent().get_node("Fleet").get_children():
		workers.add_item(d.identity+" / "+d.hull_id.to_upper())
		workers.set_item_metadata(workers.item_count-1,d.identity)
		if d.identity==get_parent().get_node("FleetControl").selected_id: workers.select(workers.item_count-1)
	panel.show()
	_select_worker(workers.selected)
func _process(delta: float) -> void:
	if not panel.visible: return
	refresh_clock -= delta
	if refresh_clock<=0:
		refresh_clock = 0.25
		_refresh()
func _refresh() -> void:
	width.max_value = 10 if kind.selected==0 else 20
	source.set_item_disabled(5,kind.selected==0)
	if kind.selected==0 and source.selected==5: source.select(4)
	var p := plan()
	var quote: Dictionary = planner.preview(p)
	var assigned: bool = planner.busy(_worker())
	assign_button.disabled = assigned or quote.is_empty()
	assign_button.text = "HULL ALREADY ASSIGNED" if assigned else "ASSIGN PAID JOB"
	kind.disabled = assigned
	source.disabled = assigned
	width.editable = not assigned
	depth.editable = kind.selected!=0 and not assigned
	height.editable = not assigned
	readings.text = "ROUTE / %s\n" % (("HOME" if p.source==0 else "BAND %d" % (p.source+1))+" TO BAND %d" % (p.target+1) if p.kind=="tunnel" else "ROOM AT "+("HOME" if p.source==0 else "BAND %d" % (p.source+1)))
	readings.text += "STAGING / E%.0f N%.0f\n" % [planner.territory.pad(p.source).x-4,-planner.territory.pad(p.source).z+4]
	if assigned:
		for job in planner.jobs.values():
			if job.worker==_worker():
				var worker: Node = get_parent().get_node("Fleet").drone(_worker())
				var linked: bool = worker!=null and get_parent().get_node("Radio").quality(worker)>0
				readings.text += "PAID / %d SCRAP\n" % job.scrap
				readings.text += "REMAINING / %.1fs\n" % job.remaining if linked else "NO LIVE WORK REPORT\n"
				readings.text += "WORKING\n" if planner.controls(_worker()) else "HELD / CHECK SUPPLY, LINK AND STAGING\n"
	else:
		if not quote.is_empty():
			readings.text += "QUOTE / %d SCRAP / %.0fs\nNEW VOLUME / %.1fm³\n" % [quote.scrap,quote.seconds,quote.volume]
		elif not planner.held(int(p.source)) or not planner.held(int(p.target)):
			readings.text += "Hold the destination on the surface first.\n"
		elif not planner.Plan.reachable(int(p.source),planner.segments):
			readings.text += "Connect the preceding underground hub first.\n"
		elif not planner.Plan.expansion(p,planner.segments,planner.rooms):
			readings.text += "Existing excavation cannot be shrunk.\n"
		else:
			readings.text += "Marked volume is already excavated.\n"
	readings.text += "\n"+planner.status+"\n\nASSIGNMENTS\n"
	for job in planner.jobs.values(): readings.text += "%s / %s / %.0fs\n" % [job.worker,job.plan.kind.to_upper(),job.remaining]
