extends Node

## Autoload singleton ("Music") — background music with a short crossfade.
##
##     Music.play(&"menu")   # switch track (does nothing if already playing it)
##     Music.stop()
##
## Tracks loop until another one is requested. Routed through the "Music"
## audio bus so Settings can control music separately from SFX.

const BUS_NAME := &"Music"
const FADE_SEC := 1.2
const SILENT_DB := -40.0

const TRACKS := {
	&"menu": {"path": "res://Assets/Music/(main menu) The Lobotomy.mp3", "volume_db": -6.0},
	&"ingame": {"path": "res://Assets/Music/(ingame) Art Of A Dead Man ( Dark, Suspenseful, Tension, Music, Choir, Gothic ).mp3", "volume_db": -10.0},
	# One ending track for all four endings for now.
	&"ending": {"path": "res://Assets/Music/(ending 1) MELANCHOLIA Music Box Sad, creepy song.mp3", "volume_db": -6.0},
}

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current: StringName = &""
## The running crossfade. Killed before a new one starts, otherwise its
## delayed stop() can land on the player that was just reused for the new
## track (switching scenes faster than FADE_SEC silenced the music).
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_NAME if AudioServer.get_bus_index(BUS_NAME) != -1 else &"Master"
		player.finished.connect(player.play) # loop, whatever the import setting
		add_child(player)
		_players.append(player)


func play(track: StringName) -> void:
	if track == _current:
		return
	var info: Dictionary = TRACKS.get(track, {})
	var path: String = info.get("path", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("Music: no file for track '%s'" % track)
		return
	_current = track
	_kill_fade()
	var old := _players[_active]
	_active = 1 - _active
	var new := _players[_active]
	new.stop() # may still be fading out from the previous switch
	new.stream = load(path)
	new.volume_db = SILENT_DB
	new.play()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(new, "volume_db", float(info.get("volume_db", 0.0)), FADE_SEC)
	if old.playing:
		_fade.tween_property(old, "volume_db", SILENT_DB, FADE_SEC)
		_fade.chain().tween_callback(old.stop)


func stop() -> void:
	_current = &""
	_kill_fade()
	_players[1 - _active].stop()
	var player := _players[_active]
	if not player.playing:
		return
	_fade = create_tween()
	_fade.tween_property(player, "volume_db", SILENT_DB, FADE_SEC)
	_fade.tween_callback(player.stop)


func _kill_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
