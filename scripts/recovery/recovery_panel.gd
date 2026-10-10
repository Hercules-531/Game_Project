extends CanvasLayer
var panel: PanelContainer
var target: OptionButton
var information: Label
var status: Label
@onready var recovery: Node = get_parent().get_node("Recovery")
@onready var control: Node = get_parent().get_node("FleetControl")

func _ready() -> void:
	layer = 13
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font_size = 18
	panel.theme = theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.036,0.029,1.0)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","top","right","bottom"]:
		margin.add_theme_constant_override("margin_" + side,20)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	var title := Label.new()
	title.text = "14 / FIELD RECOVERY"
	title.add_theme_font_size_override("font_size",26)
	rows.add_child(title)
	information = Label.new()
	information.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	information.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(information)
	target = OptionButton.new()
	rows.add_child(target)
	for entry in [["HOTWIRE / FINITE JUMPER","hotwire"],["HEAVY TOW / CRAWL","tow"],["STRIP / LEAVE FRAME","strip"],["RELEASE TOW","release"]]:
		var button := Button.new()
		button.text = entry[0]
		var action: String = entry[1]
		button.pressed.connect(func(): _act(action))
		rows.add_child(button)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(status)
	var close := Button.new()
	close.text = "BACK TO OPERATIONS"
	close.pressed.connect(func(): panel.hide(); get_parent().get_node("FleetPanel").open())
	rows.add_child(close)
	InputContext.context_changed.connect(func(context: int):
		if context != InputContext.Context.TERMINAL:
			panel.hide())
	panel.hide()

func open() -> void:
	control.piloting = false
	control.stop_all()
	InputContext.set_context(InputContext.Context.TERMINAL)
	panel.show()
	target.clear()
	var donor: Node = control.selected()
	for id in recovery.nearby(donor):
		target.add_item(id.to_upper())
		target.set_item_metadata(target.item_count - 1,id)
	for drone in control.fleet.get_children():
		if donor != null and donor != drone and donor.position.distance_to(drone.position) <= 3.0:
			target.add_item(drone.identity.to_upper())
			target.set_item_metadata(target.item_count - 1,drone.identity)
	information.text = "Carrier: %s\nHotwire consumes the carrier's energy through a jumper.\nTow requires a tracked chassis and heavy winch.\nStrip requires a torch, 20kg capacity and 20 seconds.\nRecovered parts credit only after docking." % control.selected_id
	status.text = recovery.status

func _act(action: String) -> void:
	if target.item_count == 0:
		status.text = "No frame in reach."
		return
	var id: String = target.get_item_metadata(target.selected)
	var donor: Node = control.selected()
	if donor == null or get_parent().get_node("Radio").quality(donor) <= 0.0:
		recovery.status = "Recovery command rejected: link lost."
		return
	var body: Node = recovery.bodies.get(id,control.fleet.drone(id))
	var accepted := false
	match action:
		"hotwire": accepted = recovery.hotwire(donor,body)
		"tow": accepted = recovery.start_tow(donor,id)
		"strip": accepted = recovery.start_strip(donor,id)
		"release": recovery.release_tow(id); accepted = true
	if not accepted:
		recovery.status = "Equipment, power, distance or capacity requirement not met."
	status.text = recovery.status

func _process(_delta: float) -> void:
	if panel.visible:
		status.text = recovery.status

