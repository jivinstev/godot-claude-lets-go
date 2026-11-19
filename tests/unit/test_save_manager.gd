extends GutTest

const PATH := "user://test_save.json"
var _orig := ""


func before_each() -> void:
	_orig = SaveManager.save_path
	SaveManager.save_path = PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.clear()


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	SaveManager.save_path = _orig
	SaveManager.load_game()


func test_round_trip() -> void:
	SaveManager.set_value("progress", "best", 12.5)
	SaveManager.set_value("settings", "name", "Ada")
	assert_true(SaveManager.save())
	SaveManager.clear()
	SaveManager.load_game()
	assert_eq(SaveManager.get_value("progress", "best"), 12.5)
	assert_eq(SaveManager.get_value("settings", "name"), "Ada")


func test_no_temp_file_left_behind() -> void:
	SaveManager.set_value("a", "b", 1)
	SaveManager.save()
	assert_false(FileAccess.file_exists(PATH + ".tmp"), "the temp file is renamed into place")


func test_missing_value_returns_default() -> void:
	assert_eq(SaveManager.get_value("nope", "nothing", 7), 7)


func test_corrupt_file_loads_empty_instead_of_crashing() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	SaveManager.load_game()
	assert_eq(SaveManager.get_value("progress", "best", -1), -1)


func test_malformed_section_is_dropped_alone() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "data": {"good": {"k": 1}, "bad": 5}}))
	f.close()
	SaveManager.load_game()
	assert_eq(int(SaveManager.get_value("good", "k", 0)), 1)
	assert_false(SaveManager.has_value("bad", "k"))
