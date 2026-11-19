extends Node
## Persistence: one JSON file in user://, organised as sections of key → value.
##
##   SaveManager.set_value("settings", "music_volume", 0.8)
##   SaveManager.get_value("progress", "best_time", 0.0)
##   SaveManager.save()
##
## Three properties, each learned from a lost save somewhere:
##   1. ATOMIC WRITE — write a temp file, then rename it over the real one, so a crash or a
##      killed app mid-save cannot leave a truncated file.
##   2. TOLERANT LOAD — a missing, empty or corrupt file loads as an empty save with a warning,
##      never a crash. A section that is not a dictionary is dropped on its own.
##   3. VERSIONED — `version` is stored. When you change the shape of saved data, bump
##      SAVE_VERSION and add a step to `_migrate()`, so old saves upgrade instead of resetting.
##
## Values must be JSON-friendly (bool, int, float, String, Array, Dictionary). JSON has no int
## type, so an int comes back as a float: read with int(get_value(...)).

signal saved
signal loaded

const SAVE_VERSION := 1

## Overridable so tests never touch a player's real save.
var save_path := "user://save.json"

var _data: Dictionary = {}


func _ready() -> void:
	load_game()


func get_value(section: String, key: String, default: Variant = null) -> Variant:
	var s: Variant = _data.get(section)
	if typeof(s) != TYPE_DICTIONARY:
		return default
	return (s as Dictionary).get(key, default)


func set_value(section: String, key: String, value: Variant) -> void:
	if typeof(_data.get(section)) != TYPE_DICTIONARY:
		_data[section] = {}
	_data[section][key] = value


func has_value(section: String, key: String) -> bool:
	var s: Variant = _data.get(section)
	return typeof(s) == TYPE_DICTIONARY and (s as Dictionary).has(key)


## Forget everything in memory (does not touch disk until save()).
func clear() -> void:
	_data = {}


func save() -> bool:
	var payload := {"version": SAVE_VERSION, "data": _data}
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_path := ProjectSettings.globalize_path(save_path)
	# rename() replaces atomically on macOS/Linux/Android. If a platform refuses to rename over an
	# existing file, fall back to remove-then-rename (a tiny window, but never a truncated file).
	if DirAccess.rename_absolute(abs_tmp, abs_path) != OK:
		DirAccess.remove_absolute(abs_path)
		if DirAccess.rename_absolute(abs_tmp, abs_path) != OK:
			push_error("SaveManager: could not move %s into place" % tmp)
			return false
	saved.emit()
	return true


func load_game() -> void:
	_data = {}
	if FileAccess.file_exists(save_path):
		var text := FileAccess.get_file_as_string(save_path)
		# JSON.new().parse() rather than JSON.parse_string(): the latter logs an engine error on
		# bad input, and a corrupt save is an expected case here, not an error.
		var json := JSON.new()
		var parsed: Variant = json.data if json.parse(text) == OK else null
		if typeof(parsed) != TYPE_DICTIONARY:
			push_warning("SaveManager: %s is unreadable — starting from an empty save" % save_path)
		else:
			var version := int((parsed as Dictionary).get("version", 0))
			var raw: Variant = (parsed as Dictionary).get("data", {})
			if typeof(raw) == TYPE_DICTIONARY:
				for section in (raw as Dictionary).keys():
					if typeof(raw[section]) == TYPE_DICTIONARY:
						_data[str(section)] = raw[section]
					else:
						push_warning("SaveManager: dropping malformed section '%s'" % section)
			_migrate(version)
	loaded.emit()


## Upgrade data saved by an older build. Add one `if from < N:` block per version bump.
func _migrate(from: int) -> void:
	if from >= SAVE_VERSION:
		return
	# Example, when SAVE_VERSION becomes 2:
	#   if from < 2:
	#       set_value("progress", "stars", get_value("progress", "coins", 0))
