extends CanvasLayer
var panel: PanelContainer
var destinations: OptionButton
var report: Label
var hud: Label
var hub := 0
var clock := 0.0
@onready var passenger: Node = get_parent().get_node("Passenger")
func _ready() -> void:
	layer = 20
	hud = Label.new()
	hud.position = Vector2(12,42)
	hud.add_theme_font_size_override("font_size",16)
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
	title.text = "14 / UNDERGROUND PASSENGER"
	rows.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 70
	rows.add_child(scroll)
	report = Label.new()
	report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(report)
	destinations = OptionButton.new()
	rows.add_child(destinations)
	for entry in [["CALL CAR TO THIS PLATFORM",func(): passenger.call_car(hub)],
		["BOARD STOPPED CAR",func(): passenger.board()],
		["TRAVEL TO SELECTED HUB",func(): passenger.travel(destinations.selected)],
		["DISEMBARK AT CLEAR PLATFORM",func(): passenger.disembark()],
		["CANCEL EMPTY PASSENGER CALL",func(): passenger.cancel_call()],
		["CLOSE / FIRST PERSON",func(): InputContext.set_context(InputContext.Context.WALK)]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(func():
			entry[1].call()
			if InputContext.active==InputContext.Context.WALK: panel.hide()
			_refresh())
		rows.add_child(button)
	InputContext.context_changed.connect(func(context: int):
		if context!=InputContext.Context.TERMINAL: panel.hide())
	panel.hide()
func open(at_hub: int) -> void:
	if not passenger.aboard and not passenger.near_station(at_hub): return
	hub = at_hub
	InputContext.set_context(InputContext.Context.TERMINAL)
	panel.show()
	_refresh()
func _process(delta: float) -> void:
	hud.text = "SEALED ACCESS / CLIMBING / [E] REVERSE" if passenger.climb>=0 else ("UNDERGROUND RAIL / %s / [E] RIDE CONTROLS" % passenger.phase.to_upper() if passenger.aboard else "")
	clock -= delta
	if panel.visible and clock<=0:
		clock = 0.2
		_refresh()
func _refresh() -> void:
	if destinations.item_count!=passenger.rail.hub_count():
		destinations.clear()
		for i in passenger.rail.hub_count(): destinations.add_item("HOME" if i==0 else "DEPOT %d" % i)
	for i in destinations.item_count: destinations.set_item_disabled(i,not passenger.rail.connected(i))
	report.text = "PLATFORM / %s\nCAR / %s\nPOSITION / %.1fm\n\n%s\n\nWired rail uses finite grid power.\nUnderground travel spends no suit O2, filters or jumper." % ["HOME" if hub==0 else "DEPOT %d" % hub,passenger.phase.to_upper(),passenger.rail.freight.coordinate,passenger.status]
