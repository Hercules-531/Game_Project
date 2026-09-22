extends RefCounted
## Validated JSON, checksum, staged write and last-good backup. Never executes data.

const Schema = preload("res://scripts/persistence/save_schema.gd")
var path: String


func _init(save_path: String = "user://outpost/save.json") -> void:
	path = save_path


func _read_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"ok":false,"error":"No saved game.","kind":"missing"}
	var file := FileAccess.open(file_path,FileAccess.READ)
	if file == null or file.get_length() > 8 * 1024 * 1024:
		return {"ok":false,"error":"Save cannot be read.","kind":"corrupt"}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {"ok":false,"error":"Save is damaged.","kind":"corrupt"}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or envelope.get("format") != "outpost-save":
		return {"ok":false,"error":"Save is damaged.","kind":"corrupt"}
	var payload: Variant = envelope.get("payload")
	if not payload is String or payload.sha256_text() != envelope.get("sha256"):
		return {"ok":false,"error":"Save checksum failed.","kind":"corrupt"}
	if parser.parse(payload) != OK:
		return {"ok":false,"error":"Save payload is damaged.","kind":"corrupt"}
	var data: Variant = parser.data
	var error := Schema.validate(data)
	if not error.is_empty():
		return {"ok":false,"error":error,"kind":"unsupported" if error == "Unsupported save version." else "corrupt"}
	return {"ok":true,"data":data,"recovered":false}


func read_save() -> Dictionary:
	var result := _read_file(path)
	if result.ok or result.get("kind") == "unsupported":
		return result
	var backup := _read_file(path + ".bak")
	if backup.ok:
		backup.recovered = true
		return backup
	return result


func write_save(data: Dictionary) -> Dictionary:
	var error := Schema.validate(data)
	if not error.is_empty():
		return {"ok":false,"error":error}
	var previous := _read_file(path)
	if previous.get("kind") == "unsupported":
		return {"ok":false,"error":"A newer save exists. It has been left untouched."}
	var directory := ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return {"ok":false,"error":"Cannot create save folder."}
	var payload := JSON.stringify(data)
	var temp := path + ".tmp"
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file == null:
		return {"ok":false,"error":"Cannot write save."}
	file.store_string(JSON.stringify({"format":"outpost-save","payload":payload,"sha256":payload.sha256_text()}))
	file.flush()
	file.close()
	if not _read_file(temp).ok:
		return {"ok":false,"error":"Save verification failed; previous save retained."}
	# Rotate only validated main files; never replace a good backup with corruption.
	if previous.ok:
		if FileAccess.file_exists(path + ".bak"):
			if DirAccess.remove_absolute(path + ".bak") != OK:
				return {"ok":false,"error":"Cannot rotate save backup."}
		if DirAccess.rename_absolute(path,path + ".bak") != OK:
			return {"ok":false,"error":"Cannot preserve previous save."}
	elif FileAccess.file_exists(path):
		if DirAccess.remove_absolute(path) != OK:
			return {"ok":false,"error":"Cannot replace damaged save."}
	if DirAccess.rename_absolute(temp,path) != OK:
		return {"ok":false,"error":"Save commit failed; previous backup remains available."}
	return {"ok":true}
