extends RefCounted

const DEFAULT_KEYS := {"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,
	"move_right":KEY_D,"interact":KEY_E}
const BUSES := {"master":"Master","effects":"Effects","ambience":"Ambience"}
var path: String
var keys: Dictionary = DEFAULT_KEYS.duplicate()
var volumes := {"master":1.0,"effects":1.0,"ambience":1.0}
var sensitivity: float = 0.0025


func _init(file_path: String = "user://outpost/settings.json") -> void:
	path = file_path


func load_settings() -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return false
	var data: Variant = parser.data
	if not data is Dictionary or data.get("version") != 1:
		return false
	if not data.get("keys") is Dictionary or not data.get("volumes") is Dictionary:
		return false
	var seen: Array[int] = []
	for action in DEFAULT_KEYS:
		var key: Variant = data["keys"].get(action)
		if not _number(key) or float(key) != int(key) or not valid_key(int(key)) or int(key) in seen:
			return false
		seen.append(int(key))
	for bus in BUSES:
		if not _number(data.volumes.get(bus)) or data.volumes[bus] < 0 or data.volumes[bus] > 1:
			return false
	if not _number(data.get("sensitivity")) or data.sensitivity < 0.0005 or data.sensitivity > 0.006:
		return false
	for action in DEFAULT_KEYS:
		keys[action] = int(data["keys"][action])
	volumes = data.volumes.duplicate()
	sensitivity = data.sensitivity
	return true


func save_settings() -> bool:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) != OK:
		return false
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version":1,"keys":keys,"volumes":volumes,"sensitivity":sensitivity}))
	file.flush()
	file.close()
	return true


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func valid_key(key: int) -> bool:
	return key != KEY_ESCAPE and key > 0 and key < KEY_SPECIAL + 256 and not OS.get_keycode_string(key).is_empty()


func rebind(action: String, key: int) -> bool:
	if not keys.has(action) or not valid_key(key):
		return false
	var previous: int = keys[action]
	for other in keys:
		if other != action and keys[other] == key:
			keys[other] = previous
	keys[action] = key
	return true


func reset_defaults() -> void:
	keys = DEFAULT_KEYS.duplicate()
	volumes = {"master":1.0,"effects":1.0,"ambience":1.0}
	sensitivity = 0.0025


func apply() -> void:
	for action in keys:
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action,event)
	for bus in BUSES:
		var index := AudioServer.get_bus_index(BUSES[bus])
		if index >= 0:
			var volume: float = volumes[bus]
			AudioServer.set_bus_mute(index,volume <= 0.0)
			AudioServer.set_bus_volume_db(index,linear_to_db(maxf(volume,0.0001)))
