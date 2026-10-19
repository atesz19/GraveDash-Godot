extends Node
## SaveSystem — lightweight stub for key/value persistence (highscore, settings).
## Uses user://gravedash_save.cfg. Replace with JSON / encrypted store later if needed.

const SAVE_PATH := "user://gravedash_save.cfg"

var _data: Dictionary = {}
var _config := ConfigFile.new()


func _ready() -> void:
	load_save()


func get_value(key: String, default: Variant = null) -> Variant:
	return _data.get(key, default)


func set_value(key: String, value: Variant) -> void:
	_data[key] = value


func save() -> void:
	for key in _data.keys():
		_config.set_value("save", str(key), _data[key])
	var err := _config.save(SAVE_PATH)
	if err != OK:
		push_warning("SaveSystem: failed to save (%s)" % error_string(err))


func load_save() -> void:
	var err := _config.load(SAVE_PATH)
	if err != OK:
		_data = {}
		return
	_data = {}
	if _config.has_section("save"):
		for key in _config.get_section_keys("save"):
			_data[key] = _config.get_value("save", key)
