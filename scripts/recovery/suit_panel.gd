extends CanvasLayer
var panel: PanelContainer
var readings: Label
@onready var sortie: Node = get_parent().get_node("HumanSortie")
func _ready() -> void:
	layer = 13
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font_size = 18
	panel.theme = theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.036,0.029)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","top","right","bottom"]:
		margin.add_theme_constant_override("margin_" + side,20)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	var title := Label.new()
	title.text = "14 / EMERGENCY RECOVERY"
	title.add_theme_font_size_override("font_size",26)
	rows.add_child(title)
	readings = Label.new()
	readings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(readings)
	for entry in [["SUIT UP / 5 SCRAP + 2% O2 + 0.30 kWh",sortie.suit_up],["STOW SUIT / RESUME OPERATIONS",sortie.finish]]:
		var button := Button.new()
		button.text = entry[0]
		var action: Callable = entry[1]
		button.pressed.connect(func(): action.call(); _refresh())
		rows.add_child(button)
	var close := Button.new()
	close.text = "LEAVE LOCKER"
	close.pressed.connect(func(): panel.hide(); InputContext.set_context(InputContext.Context.WALK))
	rows.add_child(close)
	var hud := CanvasLayer.new()
	hud.layer = 14
	add_child(hud)
	var visor := preload("res://scripts/player/suit_visor.gd").new()
	visor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visor.sortie = sortie
	hud.add_child(visor)
	InputContext.context_changed.connect(func(context: int):
		if context != InputContext.Context.TERMINAL: panel.hide())
	panel.hide()
func open() -> void:
	InputContext.set_context(InputContext.Context.TERMINAL)
	panel.show()
	_refresh()
func _process(_delta: float) -> void:
	if panel.visible: _refresh()
func _refresh() -> void:
	readings.text = "%s\n\nOXYGEN %03ds / FILTER %03ds / JUMPER %.2f kWh\n\nFleet unavailable: %s\n\n%s" % ["SUIT ACTIVE" if sortie.active else "SUIT STOWED",sortie.oxygen,sortie.filter,sortie.jumper,"YES" if sortie.fleet_unavailable() else "NO",sortie.status]
