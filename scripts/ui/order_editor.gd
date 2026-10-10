extends CanvasLayer
const Rule = preload("res://scripts/autonomy/rule_block.gd")
var panel: PanelContainer
var blocks: ItemList
var kind: OptionButton
var east: SpinBox
var north: SpinBox
var feedback: Label
var draft: Array = []
@onready var runner: Node = get_parent().get_node("Orders")
@onready var control: Node = get_parent().get_node("FleetControl")

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
	for side in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_" + side,16)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	var title := Label.new()
	title.text = "14 / STANDING ORDER BLOCKS"
	title.add_theme_font_size_override("font_size",25)
	rows.add_child(title)
	var priority := Label.new()
	priority.text = "Priority: manual / failsafe → low cell → silent → load → route"
	priority.add_theme_font_size_override("font_size",15)
	rows.add_child(priority)
	blocks = ItemList.new()
	blocks.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blocks.custom_minimum_size.y = 140
	rows.add_child(blocks)
	var tools := HBoxContainer.new()
	rows.add_child(tools)
	kind = OptionButton.new()
	for text in ["GO TO WAYPOINT","CELL <20%: RETURN","HOSTILE PING: SILENT","SALVAGE: LOAD/WINCH"]: kind.add_item(text)
	kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(kind)
	button(tools,"ADD",add_block)
	button(tools,"REMOVE",func():
		var selected := blocks.get_selected_items()
		if not selected.is_empty(): draft.remove_at(selected[0]); refresh())
	var coordinates := HBoxContainer.new()
	rows.add_child(coordinates)
	for entry in [["EAST",-58.0,58.0],["NORTH",0.0,598.0]]:
		var label := Label.new()
		label.text = entry[0] + " (m)"
		coordinates.add_child(label)
		var field := SpinBox.new()
		field.min_value = entry[1]
		field.max_value = entry[2]
		field.step = 0.5
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		coordinates.add_child(field)
		if entry[0] == "EAST": east = field
		else: north = field
	var edits := HBoxContainer.new()
	rows.add_child(edits)
	button(edits,"MOVE UP",func(): move_block(-1))
	button(edits,"MOVE DOWN",func(): move_block(1))
	button(edits,"TRANSMIT / RUN",transmit)
	button(edits,"STOP",func(): runner.stop(control.selected_id); refresh())
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size",16)
	rows.add_child(feedback)
	button(rows,"BACK TO OPERATIONS",func(): panel.hide(); get_parent().get_node("FleetPanel").open())
	InputContext.context_changed.connect(func(context: int):
		if context != InputContext.Context.TERMINAL: panel.hide())
	panel.hide()

func button(parent: Node, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	parent.add_child(b)
func open() -> void:
	control.piloting = false
	control.stop_all()
	InputContext.set_context(InputContext.Context.TERMINAL)
	draft = runner.programs.get(control.selected_id,{}).get("rules",[]).duplicate(true)
	panel.show()
	refresh()
func add_block() -> void:
	if draft.size() >= 32: return
	var rule := {"kind":Rule.KINDS[kind.selected]}
	if rule.kind == "waypoint": rule["x"] = east.value; rule["north"] = north.value
	draft.append(rule)
	refresh()
func move_block(direction: int) -> void:
	var selected := blocks.get_selected_items()
	if selected.is_empty(): return
	var index: int = selected[0]
	var next := index + direction
	if next < 0 or next >= draft.size(): return
	var rule: Dictionary = draft[index]
	draft[index] = draft[next]
	draft[next] = rule
	refresh()
	blocks.select(next)
func transmit() -> void:
	runner.submit(control.selected_id,draft)
	refresh()
func refresh() -> void:
	blocks.clear()
	for index in draft.size(): blocks.add_item("%02d  /  %s" % [index + 1,Rule.describe(draft[index])])
	feedback.text = "%s / %s\n%s" % [control.selected_id,runner.programs.get(control.selected_id,{}).get("mode","NO PROGRAM"),runner.status]
func _process(_delta: float) -> void:
	if panel.visible: feedback.text = "%s / %s\n%s" % [control.selected_id,runner.programs.get(control.selected_id,{}).get("mode","NO PROGRAM"),runner.status]
