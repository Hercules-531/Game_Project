extends CanvasLayer
var panel: PanelContainer
var seals: OptionButton
var workers: OptionButton
var readings: Label
var hud: Label
var clock := 0.0
@onready var breaches: Node = get_parent().get_node("Breaches")
func _ready() -> void:
	layer = 22
	hud = Label.new()
	hud.position = Vector2(12,66)
	hud.add_theme_font_size_override("font_size",16)
	hud.modulate = Color(1,0.5,0.2)
	add_child(hud)
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
	title.text = "14 / ENTRANCE HARDENING"
	title.add_theme_font_size_override("font_size",24)
	rows.add_child(title)
	seals = OptionButton.new()
	for id in breaches.IDS: seals.add_item(id.replace("_"," ").to_upper())
	seals.item_selected.connect(func(_index: int): _refresh())
	rows.add_child(seals)
	workers = OptionButton.new()
	rows.add_child(workers)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(scroll)
	readings = Label.new()
	readings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(readings)
	for entry in [["ADD PLATING TIER / 24 SCRAP / 0.02 kWh",true],["SERVICE / RESEAL / 0.02 kWh",false]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(func():
			if workers.selected>=0: breaches.service(_id(),str(workers.get_item_metadata(workers.selected)),entry[1])
			_refresh())
		rows.add_child(button)
	var back := Button.new()
	back.text = "BACK TO FLEET"
	back.pressed.connect(func(): panel.hide(); get_parent().get_node("FleetPanel").open())
	rows.add_child(back)
	InputContext.context_changed.connect(func(context: int):
		if context!=InputContext.Context.TERMINAL: panel.hide())
	panel.hide()
func _id() -> String: return breaches.IDS[seals.selected]
func open() -> void:
	get_parent().get_node("FleetControl").piloting = false
	get_parent().get_node("FleetControl").stop_all()
	InputContext.set_context(InputContext.Context.TERMINAL)
	panel.show()
	_refresh()
func _process(delta: float) -> void:
	hud.text = "UNPROTECTED SURFACE / GET INSIDE / %.1fs" % maxf(0,5-breaches.exposure) if breaches.exposure>0 else ""
	if hud.text.is_empty():
		for id in breaches.entrances:
			if breaches.entrances[id].forced: hud.text = "SEAL FORCED / "+id.replace("_"," ").to_upper(); break
	if not panel.visible: return
	clock -= delta
	if clock<=0: clock = 0.2; _refresh()
func _refresh() -> void:
	var previous: Variant = workers.get_item_metadata(workers.selected) if workers.selected>=0 else null
	workers.clear()
	for d in get_parent().get_node("Fleet").get_children():
		workers.add_item(d.identity+" / "+d.hull_id.to_upper())
		workers.set_item_metadata(workers.item_count-1,d.identity)
		if d.identity==previous: workers.select(workers.item_count-1)
	var record: Dictionary = breaches.entrances[_id()]
	readings.text = "OWNED SEAL / %s\nCONDITION / %.2f%%\nPLATING / %d OF 3\nSTATE / %s\n" % [_id().to_upper(),record.condition,record.tier,"FORCED OPEN" if record.forced else "INTACT"]
	readings.text += "CONTACT-CYCLE RISK / %.2f%%\nREPAIR MATERIALS / %d SCRAP\nHOME STOCK / %d SCRAP\n\n" % [breaches.probability(_id())*100,breaches.repair_cost(_id()),get_parent().get_node("Inventory").scrap]
	readings.text += "Risk applies at high trace while an existing mutant\nphysically attacks the seal. Clear an occupied\naperture before resealing.\n\nUse a powered torch hull at the source bay/cradle.\nDefense research permits plating.\n\n"+breaches.status
