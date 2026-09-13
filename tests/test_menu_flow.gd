extends GutTest

var session: Node


func before_each() -> void:
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child_autofree(session)
	await wait_process_frames(3)


func after_each() -> void:
	get_tree().paused = false


func test_new_game_pause_resume_and_return_to_menu() -> void:
	assert_null(session.world)
	session.new_game()
	await wait_physics_frames(5)
	var world: Node = session.world
	InputContext.set_context(InputContext.Context.MENU)
	var ticks: int = world.physics_ticks
	# GUT itself must keep advancing while the gameplay subtree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(0.15,true).timeout
	assert_eq(world.physics_ticks,ticks,"Pause freezes actual simulation")
	assert_true(session.menu.panel.visible)
	session.resume()
	await wait_physics_frames(5)
	assert_gt(world.physics_ticks,ticks)
	assert_eq(session.world,world,"Resume retains the same world")
	session.return_to_menu()
	await wait_process_frames(2)
	assert_null(session.world)
	assert_false(get_tree().paused)
	assert_eq(InputContext.active,InputContext.Context.MENU)


func test_terminal_context_does_not_pause_world() -> void:
	session.new_game()
	var world: Node = session.world
	InputContext.set_context(InputContext.Context.TERMINAL)
	var ticks: int = world.physics_ticks
	await wait_physics_frames(5)
	assert_gt(world.physics_ticks,ticks)
	assert_false(session.menu.panel.visible)
