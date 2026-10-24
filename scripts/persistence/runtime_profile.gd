extends RefCounted
const DEFAULT_SAVE := "user://outpost/save.json"
const DEFAULT_SETTINGS := "user://outpost/settings.json"
const PLAYTEST_SAVE := "user://playtest/save.json"
const PLAYTEST_SETTINGS := "user://playtest/settings.json"
static func save_path(current: String, args: PackedStringArray) -> String:
	return PLAYTEST_SAVE if "--playtest" in args and current==DEFAULT_SAVE else current
static func settings_path(args: PackedStringArray) -> String:
	return PLAYTEST_SETTINGS if "--playtest" in args else DEFAULT_SETTINGS
