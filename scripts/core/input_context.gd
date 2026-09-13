extends Node
## Owns the input boundary between walking, physical terminals and menus.

signal context_changed(context: int)

enum Context { WALK, TERMINAL, MENU }
var active: Context = Context.MENU


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_context(next: Context) -> void:
	active = next
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if active == Context.WALK else Input.MOUSE_MODE_VISIBLE
	context_changed.emit(active)


func allows_movement() -> bool:
	return active == Context.WALK


func allows_look() -> bool:
	return active == Context.WALK


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_pointer"):
		set_context(Context.MENU if active == Context.WALK else Context.WALK)
		get_viewport().set_input_as_handled()
