extends Node

## SaveManager — autoload. Wraps GameState (de)serialization to a JSON file
## in user://. Mirrors hacking-game's localStorage-based SaveManager.js.

const SAVE_PATH := "user://save.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save() -> bool:
	var data := {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"state": GameState.to_dict(),
		"phone": PhoneState.to_dict(),
		"stocks": StocksState.to_dict(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not open save file: %s" % SAVE_PATH)
		return false
	f.store_string(JSON.stringify(data, "  "))
	return true

func load_save() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	var parsed: Variant = JSON.parse_string(txt)
	if not parsed is Dictionary:
		push_error("Save file corrupt at %s" % SAVE_PATH)
		return false
	GameState.from_dict(parsed.get("state", {}))
	PhoneState.from_dict(parsed.get("phone", {}))
	StocksState.from_dict(parsed.get("stocks", {}))
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
