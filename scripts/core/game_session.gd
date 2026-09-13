extends Node
## Application flow owns the world; pausing never duplicates or resets it.

const GAME = preload("res://scenes/main.tscn")
var world: Node
@onready var menu: CanvasLayer = $Menu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu.new_game_requested.connect(new_game)
	menu.resume_requested.connect(resume)
	menu.main_menu_requested.connect(return_to_menu)
	menu.quit_requested.connect(func():get_tree().quit())
	InputContext.context_changed.connect(_context_changed)
	return_to_menu()
	if "--verify-export" in OS.get_cmdline_user_args():
		new_game()


func new_game() -> void:
	_discard_world()
	world = GAME.instantiate()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	menu.hide_menu()


func resume() -> void:
	if world == null:
		return
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	menu.hide_menu()


func return_to_menu() -> void:
	_discard_world()
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.MENU)
	menu.show_main()


func _discard_world() -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = null


func _context_changed(context: int) -> void:
	if not is_instance_valid(world):
		return
	get_tree().paused = context == InputContext.Context.MENU
	if get_tree().paused:
		menu.show_pause()
	else:
		menu.hide_menu()


func _exit_tree() -> void:
	get_tree().paused = false
