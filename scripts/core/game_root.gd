extends Node
## Application loop host. The bootstrap diagnostic view remains optional.

var process_frames: int = 0
var physics_ticks: int = 0
var elapsed_seconds: float = 0.0

@onready var diagnostics: Label = get_node_or_null("Bootstrap/Margin/Rows/Counters")


func _ready() -> void:
	preload("res://scripts/render/material_policy.gd").apply_tree(self)
	if "--verify-export" in OS.get_cmdline_user_args():
		_verify_export.call_deferred()


func _verify_export() -> void:
	await get_tree().create_timer(0.5).timeout
	var valid := process_frames > 0 and physics_ticks > 0 and elapsed_seconds > 0.0
	valid = valid and not has_node("/root/_mcp_game_helper")
	valid = valid and has_node("/root/PhantomCameraManager")
	var profile = preload("res://scripts/persistence/runtime_profile.gd")
	var args := OS.get_cmdline_user_args()
	valid = valid and get_parent().save_path==profile.save_path(profile.DEFAULT_SAVE,args)
	valid = valid and get_node("/root/UserSettings").store.path==profile.settings_path(args)
	if valid:
		print("OUTPOST_EXPORT_VERIFIED: process=%d physics=%d profile=%s" % [process_frames, physics_ticks,"playtest" if "--playtest" in args else "default"])
		get_parent().finish_runtime(0)
	else:
		push_error("Export verification failed: simulation or runtime dependencies")
		get_parent().finish_runtime(1)


func _process(delta: float) -> void:
	process_frames += 1
	elapsed_seconds += delta
	if is_instance_valid(diagnostics):
		diagnostics.text = "Process frames: %d\nPhysics ticks: %d\nElapsed: %.2f seconds" % [
			process_frames, physics_ticks, elapsed_seconds
		]


func _physics_process(_delta: float) -> void:
	physics_ticks += 1
