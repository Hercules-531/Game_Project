extends Node
class_name OutpostInteractable

signal used(target: OutpostInteractable)
signal power_changed(powered: bool)

var display_name: String = "Control"
var kind: StringName = &"terminal"
var station_id: StringName = &""
var powered: bool = true
var enabled: bool = true


func use() -> void:
	if enabled:
		used.emit(self)


func toggle_power() -> void:
	powered = not powered
	power_changed.emit(powered)
