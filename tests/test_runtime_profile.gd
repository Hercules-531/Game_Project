extends GutTest
const Profile = preload("res://scripts/persistence/runtime_profile.gd")
func test_default_playtest_and_explicit_test_slots_stay_separate() -> void:
	assert_eq(Profile.save_path(Profile.DEFAULT_SAVE,PackedStringArray()),Profile.DEFAULT_SAVE)
	assert_eq(Profile.save_path(Profile.DEFAULT_SAVE,PackedStringArray(["--playtest"])),Profile.PLAYTEST_SAVE)
	assert_eq(Profile.settings_path(PackedStringArray()),Profile.DEFAULT_SETTINGS)
	assert_eq(Profile.settings_path(PackedStringArray(["--playtest"])),Profile.PLAYTEST_SETTINGS)
	assert_ne(Profile.PLAYTEST_SAVE,Profile.DEFAULT_SAVE)
	assert_ne(Profile.PLAYTEST_SETTINGS,Profile.DEFAULT_SETTINGS)
	assert_eq(Profile.save_path("user://tests/explicit.json",PackedStringArray(["--playtest"])),"user://tests/explicit.json")
