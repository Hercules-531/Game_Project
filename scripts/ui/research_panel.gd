extends CanvasLayer
var panel: PanelContainer
var choice: OptionButton
var readings: Label
@onready var research: Node = get_parent().get_node("Research")
func _ready() -> void:
	layer = 13
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font_size = 17
	panel.theme = theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.036,0.029)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side,16)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	var title := Label.new()
	title.text = "14 / RECOVERED KNOWLEDGE"
	title.add_theme_font_size_override("font_size",25)
	rows.add_child(title)
	choice = OptionButton.new()
	for id in research.TREE.topics:
		choice.add_item(research.TREE.topics[id].name)
		choice.set_item_metadata(choice.item_count - 1,id)
	rows.add_child(choice)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(scroll)
	readings = Label.new()
	readings.add_theme_font_size_override("font_size",16)
	readings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	readings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(readings)
	var start := Button.new()
	start.text = "RESEARCH SELECTED TOPIC"
	start.pressed.connect(func(): research.start(choice.get_item_metadata(choice.selected)); _refresh())
	rows.add_child(start)
	var back := Button.new()
	back.text = "BACK TO WORKSHOP"
	back.pressed.connect(func(): panel.hide(); get_parent().get_node("WorkshopPanel").open())
	rows.add_child(back)
	InputContext.context_changed.connect(func(context: int):
		if context != InputContext.Context.TERMINAL: panel.hide())
	panel.hide()
func open() -> void:
	get_parent().get_node("FleetControl").piloting = false
	get_parent().get_node("FleetControl").stop_all()
	InputContext.set_context(InputContext.Context.TERMINAL)
	panel.show()
	_refresh()
func _process(_delta: float) -> void:
	if panel.visible: _refresh()
func _refresh() -> void:
	var id: String = choice.get_item_metadata(choice.selected)
	var topic: Dictionary = research.TREE.topics[id]
	readings.text = "ARCHIVE / %s\nSTATUS / %s\nCOST / %d SCRAP / %ds / 0.35kW\n" % [research.archives[id].state.to_upper(),"COMPLETE" if research.has_technology(id) else "NOT RESEARCHED",topic.scrap,int(topic.seconds)]
	for prerequisite in topic.prerequisites: readings.text += "REQUIRES / " + research.TREE.topics[prerequisite].name + "\n"
	var capabilities := PackedStringArray()
	for recipe in topic.recipes: capabilities.append(str(recipe).replace("_", " ").capitalize())
	readings.text += "\nCAPABILITY / " + (", ".join(capabilities) if not capabilities.is_empty() else topic.name)
	readings.text += "\n\n" + ("QUEUE READY" if research.job.is_empty() else "RESEARCH / %s / %ds PAID WORK REMAINS" % [research.TREE.topics[research.job.topic].name,ceili(research.job.remaining)])
	readings.text += "\nSCRAP / %d\n\n%s" % [get_parent().get_node("Inventory").scrap,research.status]
