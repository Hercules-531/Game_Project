extends Node
## Milestone 01 diagnostic host. Gameplay will replace the bootstrap view.

var process_frames: int = 0
var physics_ticks: int = 0
var elapsed_seconds: float = 0.0

@onready var diagnostics: Label = $Bootstrap/Margin/Rows/Counters


func _process(delta: float) -> void:
	process_frames += 1
	elapsed_seconds += delta
	diagnostics.text = "Process frames: %d\nPhysics ticks: %d\nElapsed: %.2f seconds" % [
		process_frames, physics_ticks, elapsed_seconds
	]


func _physics_process(_delta: float) -> void:
	physics_ticks += 1
