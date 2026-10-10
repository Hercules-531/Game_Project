extends Node
## Application flow owns the world; pausing never duplicates or resets it.

const GAME = preload("res://scenes/main.tscn")
const SaveService = preload("res://scripts/persistence/save_service.gd")
const SaveSchema = preload("res://scripts/persistence/save_schema.gd")
@export var save_path: String = "user://outpost/save.json"
var saves: RefCounted
var world: Node
@onready var menu: CanvasLayer = $Menu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	saves = SaveService.new(save_path)
	menu.new_game_requested.connect(new_game)
	menu.resume_requested.connect(resume)
	menu.main_menu_requested.connect(return_to_menu)
	menu.quit_requested.connect(_quit)
	menu.continue_requested.connect(continue_game)
	menu.save_requested.connect(save_current)
	menu.settings_requested.connect(open_settings)
	$Settings.closed.connect(_close_settings)
	InputContext.context_changed.connect(_context_changed)
	return_to_menu()
	if "--verify-export" in OS.get_cmdline_user_args():
		new_game()


func new_game() -> void:
	_discard_world()
	world = GAME.instantiate()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.get_node("LifeSupport").died.connect(_life_support_failed)
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	menu.hide_menu()


func open_settings() -> void:
	menu.hide_menu()
	$Settings.open()


func _close_settings() -> void:
	if _operator_dead():
		_show_death()
	elif is_instance_valid(world):
		menu.show_pause()
	else:
		menu.show_main()
		_refresh_continue()


func resume() -> void:
	if world == null or _operator_dead():
		return
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	menu.hide_menu()


func return_to_menu() -> void:
	if is_instance_valid(world) and not _operator_dead() and not save_current():
		return
	_discard_world()
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.MENU)
	menu.show_main()
	_refresh_continue()


func _refresh_continue() -> void:
	var result: Dictionary = saves.read_save()
	menu.continue_button.disabled = not result.ok
	if not result.ok and result.get("kind") != "missing":
		menu.subtitle.text = result.error


func save_current() -> bool:
	if not is_instance_valid(world):
		return false
	if _operator_dead():
		menu.subtitle.text = "Life support failed. Last save retained."
		return false
	if world.get_node("Bunker/Airlock").busy:
		menu.subtitle.text = "Finish the airlock cycle before saving."
		return false
	var result: Dictionary = saves.write_save(SaveSchema.capture(world))
	menu.subtitle.text = "GAME SAVED" if result.ok else result.error
	return result.ok


func continue_game() -> bool:
	var result: Dictionary = saves.read_save()
	if not result.ok:
		menu.subtitle.text = result.error
		return false
	new_game()
	SaveSchema.restore(world,result.data)
	if result.recovered:
		InputContext.set_context(InputContext.Context.MENU)
		menu.subtitle.text = "Recovered the previous valid save."
	return true


func _quit() -> void:
	if is_instance_valid(world) and not _operator_dead() and not save_current():
		var message: String = menu.subtitle.text
		InputContext.set_context(InputContext.Context.MENU)
		menu.subtitle.text = message
		return
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


func _discard_world() -> void:
	InputContext.menu_locked = false
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = null


func _context_changed(context: int) -> void:
	if not is_instance_valid(world):
		return
	get_tree().paused = context == InputContext.Context.MENU
	if get_tree().paused:
		if _operator_dead():
			_show_death()
		else:
			menu.show_pause()
	else:
		menu.hide_menu()


func _operator_dead() -> bool:
	return is_instance_valid(world) and world.get_node("LifeSupport").dead


func _life_support_failed() -> void:
	InputContext.menu_locked = true
	InputContext.set_context(InputContext.Context.MENU)
	_show_death()


func _show_death() -> void:
	var result: Dictionary = saves.read_save()
	menu.show_death(world.get_node("LifeSupport").critical_reason(),result.ok)


func _exit_tree() -> void:
	InputContext.menu_locked = false
	get_tree().paused = false
	get_tree().auto_accept_quit = true
