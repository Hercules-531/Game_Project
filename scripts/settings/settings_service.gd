extends Node

signal changed
const Store = preload("res://scripts/settings/settings_store.gd")
var store := Store.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	store = Store.new(preload("res://scripts/persistence/runtime_profile.gd").settings_path(OS.get_cmdline_user_args()))
	store.load_settings()
	store.apply()


func apply_and_save() -> bool:
	store.apply()
	changed.emit()
	return store.save_settings()
