extends Node
## Application flow owns the world; pausing never duplicates or resets it.

const GAME = preload("res://scenes/main.tscn")
const SaveService = preload("res://scripts/persistence/save_service.gd")
const SaveSchema = preload("res://scripts/persistence/save_schema.gd")
@export var save_path: String = "user://outpost/save.json":
	set(value):
		save_path = value
		if saves != null: saves = SaveService.new(value)
var saves: RefCounted
var world: Node
var ending_open := false
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
	$Credits.resume_requested.connect(_resume_after_credits)
	$Credits.menu_requested.connect(return_to_menu)
	$Credits.settings_requested.connect(open_settings)
	$Credits.retry_requested.connect(_persist_ending)
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
	world.get_node("HumanSortie").died.connect(func(_reason: String): _life_support_failed())
	world.get_node("Restoration").achieved.connect(_restoration_finished)
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	menu.hide_menu()


func open_settings() -> void:
	menu.hide_menu()
	$Credits.panel.hide()
	$Settings.open()


func _close_settings() -> void:
	if ending_open:
		$Credits.open(world.get_node("Restoration").credits_seen)
	elif _operator_dead():
		_show_death()
	elif is_instance_valid(world):
		menu.show_pause()
	else:
		menu.show_main()
		_refresh_continue()


func resume() -> void:
	if world == null or _operator_dead() or ending_open:
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
		var human: Node = world.get_node("HumanSortie")
		menu.subtitle.text = (human.reason if human.dead else "Life support failed.")+" Last save retained."
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
	var restoration: Node = world.get_node("Restoration")
	if restoration.completed and not restoration.credits_seen: _restoration_finished()
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
	ending_open = false
	$Credits.panel.hide()
	InputContext.menu_locked = false
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = null


func _context_changed(context: int) -> void:
	if not is_instance_valid(world):
		return
	get_tree().paused = context == InputContext.Context.MENU
	if ending_open:
		menu.hide_menu()
		return
	if get_tree().paused:
		if _operator_dead():
			_show_death()
		else:
			menu.show_pause()
	else:
		menu.hide_menu()


func _operator_dead() -> bool:
	return is_instance_valid(world) and (world.get_node("LifeSupport").dead or world.get_node("HumanSortie").dead)


func _life_support_failed() -> void:
	InputContext.menu_locked = true
	InputContext.set_context(InputContext.Context.MENU)
	_show_death()


func _show_death() -> void:
	var result: Dictionary = saves.read_save()
	var sortie: Node = world.get_node("HumanSortie")
	menu.show_death(sortie.reason if sortie.dead else world.get_node("LifeSupport").critical_reason(),result.ok)


func _persist_ending() -> void:
	var tracker: Node = world.get_node("Restoration")
	tracker.credits_seen = true
	var saved := save_current()
	if not saved: tracker.credits_seen = false
	$Credits.open(saved)


func _restoration_finished() -> void:
	$Credits.automatic_presentations += 1
	ending_open = true
	InputContext.menu_locked = true
	InputContext.set_context(InputContext.Context.MENU)
	_persist_ending()


func show_credits() -> void:
	if not is_instance_valid(world) or not world.get_node("Restoration").completed: return
	ending_open = true
	InputContext.menu_locked = true
	InputContext.set_context(InputContext.Context.MENU)
	$Credits.open(world.get_node("Restoration").credits_seen)


func _resume_after_credits() -> void:
	if not world.get_node("Restoration").credits_seen: return
	ending_open = false
	$Credits.panel.hide()
	InputContext.menu_locked = false
	resume()


func _exit_tree() -> void:
	InputContext.menu_locked = false
	get_tree().paused = false
	get_tree().auto_accept_quit = true
