extends CanvasLayer
var panel: PanelContainer
var machine: OptionButton
var targets: OptionButton
var band: OptionButton
var readings: Label
var refresh_clock := 0.0
@onready var defense: Node = get_parent().get_node("Defense")
func _ready() -> void:
	layer = 15
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
	title.text = "14 / PERIMETER DEFENSE"
	title.add_theme_font_size_override("font_size",24)
	rows.add_child(title)
	machine = OptionButton.new()
	rows.add_child(machine)
	targets = OptionButton.new()
	rows.add_child(targets)
	band = OptionButton.new()
	for i in 6:
		band.add_item("HOME" if i==0 else "BAND %d" % (i+1))
		band.set_item_metadata(i,i)
	rows.add_child(band)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(scroll)
	readings = Label.new()
	readings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(readings)
	_buttons(rows,[["FIRE AT CONTACT",func(): defense.fire(_id(),_target())],["LOAD 20 ROUNDS / 10 SCRAP",func(): defense.reload_ammo(_id())]])
	_buttons(rows,[["LOAD TRAP / 6 SCRAP",func(): defense.load_trap(_id())],["LAY CARRIED TRAP",func(): defense.lay_trap(_id())],["TOGGLE DECOY",func(): defense.toggle_decoy(_id())]])
	_buttons(rows,[["ENERGIZE FENCE",func(): defense.set_fence(band.selected,true)],["CUT FENCE POWER",func(): defense.set_fence(band.selected,false)],["REPAIR PERIMETER",func(): defense.repair_perimeter(_id(),band.selected)]])
	_buttons(rows,[["BUILD / FIELD NETWORK",func(): panel.hide(); get_parent().get_node("TerritoryPanel").open()],["BACK TO FLEET",func(): panel.hide(); get_parent().get_node("FleetPanel").open()]])
	InputContext.context_changed.connect(func(context: int):
		if context!=InputContext.Context.TERMINAL: panel.hide())
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
func _id() -> String: return str(machine.get_item_metadata(machine.selected)) if machine.selected>=0 else ""
func _target() -> String: return str(targets.get_item_metadata(targets.selected)) if targets.selected>=0 else ""
func open() -> void:
	get_parent().get_node("FleetControl").piloting = false
	get_parent().get_node("FleetControl").stop_all()
	InputContext.set_context(InputContext.Context.TERMINAL)
	machine.clear()
	for d in get_parent().get_node("Fleet").get_children():
		machine.add_item(d.identity+" / "+d.hull_id.to_upper())
		machine.set_item_metadata(machine.item_count-1,d.identity)
	panel.show()
	_refresh()
func _process(delta: float) -> void:
	if not panel.visible: return
	refresh_clock -= delta
	if refresh_clock<=0:
		refresh_clock = 0.25
		_refresh()
func _refresh() -> void:
	var chosen := _target()
	targets.clear()
	for contact in defense.contacts(_id()):
		targets.add_item("OBSERVED CONTACT / E%.1f N%.1f" % [contact.at.x,-contact.at.z])
		targets.set_item_metadata(targets.item_count-1,contact.id)
		if contact.id==chosen: targets.select(targets.item_count-1)
	var count := targets.item_count
	targets.disabled = count==0
	if count==0:
		targets.add_item("NO OBSERVED CONTACT")
		targets.set_item_metadata(0,"")
	var d: Node = get_parent().get_node("Fleet").drone(_id())
	var linked: bool = d!=null and get_parent().get_node("Radio").quality(d)>0
	readings.text = "ROUNDS / %s    CARRIED TRAPS / %s\nCONTACTS / %d\n" % [str(defense.ammo.get(_id(),0)) if linked else "NO LINK",str(defense.kits.get(_id(),0)) if linked else "NO LINK",count]
	var record: Dictionary = defense.perimeters.get(str(band.selected),{})
	var field_link: bool = band.selected==0 or get_parent().get_node("Territory").online(band.selected)
	readings.text += "FENCE / " + ("NO LIVE TELEMETRY" if not field_link else ("ABSENT" if record.is_empty() else ("ENERGIZED" if defense.fence_live(band.selected) else ("REQUESTED / NO SUPPLY" if record.on else "POWER OFF")))) + "\n"
	if not record.is_empty() and field_link:
		for i in 5: readings.text += "SECTION %d / %.0f OF 200\n" % [i+1,record.health[i]]
	readings.text += "\nHome reloads only. Fire requires current sensor observation.\n" + defense.status
