extends Node

## Autoload singleton ("OutcomeRecord") — the persistent Record of Outcomes:
## which of the four endings have ever been reached, and on what date. Unlike
## GameScore (which only tracks the current run's Accuracy/Paranoia tally and
## resets every playthrough), this survives between play sessions by saving
## to disk, since the Records screen is meant to be "reached from the title
## screen, never locked" and show history across every run.

const SAVE_PATH := "user://outcome_record.save"

## ending_id (String) -> the date it was first filed ("YYYY.MM.DD"), GDD-style.
var _filed: Dictionary = {}


func _ready() -> void:
	_load()


func is_filed(ending_id: StringName) -> bool:
	return _filed.has(String(ending_id))


func get_filed_date(ending_id: StringName) -> String:
	return _filed.get(String(ending_id), "")


func get_filed_count() -> int:
	return _filed.size()


## Records an ending as reached. Keeps the original date if it was already
## filed once before (the archive doesn't forget, and doesn't overwrite).
func file_ending(ending_id: StringName) -> void:
	var key := String(ending_id)
	if _filed.has(key):
		return
	var now := Time.get_date_dict_from_system()
	_filed[key] = "%04d.%02d.%02d" % [now.year, now.month, now.day]
	_save()


## Debug/testing helper — wipes every filed ending so the Records screen can
## be re-tested from a clean slate. Not wired to any UI button on purpose.
func reset_all() -> void:
	_filed.clear()
	_save()


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("OutcomeRecord: could not open save file for writing.")
		return
	file.store_string(JSON.stringify(_filed))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_filed = parsed
