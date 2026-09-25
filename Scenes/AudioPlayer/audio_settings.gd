extends Node

## Autoload singleton ("AudioSettings") — the player's volume choices.
##
## Volumes are stored as 0.0–1.0 (what the sliders show as 0–100%) and applied
## to the "Music" and "SFX" audio buses, so every sound on that bus follows the
## slider. Saved to user://settings.cfg and re-applied every time the game
## starts, before anything plays.

const SAVE_PATH := "user://settings.cfg"
const SECTION := "audio"
const BUSES: Array[StringName] = [&"Music", &"SFX"]

var _volumes := {&"Music": 1.0, &"SFX": 1.0}


func _ready() -> void:
	_load()
	for bus in BUSES:
		_apply(bus)


## 0.0 = silent, 1.0 = full volume.
func get_volume(bus: StringName) -> float:
	return _volumes.get(bus, 1.0)


func set_volume(bus: StringName, volume: float) -> void:
	_volumes[bus] = clampf(volume, 0.0, 1.0)
	_apply(bus)


func save() -> void:
	var config := ConfigFile.new()
	for bus in BUSES:
		config.set_value(SECTION, String(bus), _volumes[bus])
	if config.save(SAVE_PATH) != OK:
		push_warning("AudioSettings: could not save %s" % SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return # first launch: keep the defaults
	for bus in BUSES:
		_volumes[bus] = clampf(float(config.get_value(SECTION, String(bus), 1.0)), 0.0, 1.0)


func _apply(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	var volume: float = _volumes[bus]
	# Sliders are linear (50% should sound like half), buses work in decibels.
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, volume <= 0.0)
