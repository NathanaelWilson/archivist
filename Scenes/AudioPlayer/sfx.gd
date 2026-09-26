extends Node

## Autoload singleton ("SFX") — one place that plays every sound effect.
## Gameplay code just calls SFX.play(&"file_pickup"); see Assets/SFX/README.md
## for which id plays when. Ids with no file yet are simply silent.

const SFX_DIR := "res://Assets/SFX/"
const EXTENSIONS: PackedStringArray = ["ogg", "wav", "mp3"]
const BUS_NAME := &"SFX"
const POOL_SIZE := 8

## Every sound the game asks for. Value = per-sound settings:
##   volume_db  loudness offset for this sound (default 0)
##   pitch_var  random pitch spread, 0.08 = +-8% (default 0), so repeated
##              sounds (pickups, marker) don't feel copy-pasted
##   path       optional explicit file, for files that don't follow the id name
##   paths      several files = random variations (never the same twice in a
##              row; loops switch on every repeat). Missing files are skipped,
##              and a path without an extension accepts .ogg/.wav/.mp3
const SOUNDS := {
	# --- Desk: documents & trays (file_entity.gd, filing_tray.gd)
	&"file_pickup": {"pitch_var": 0.08},          # paper lifted off the desk
	&"file_return": {"pitch_var": 0.08},          # dropped outside a tray, slides back
	&"tray_hover": {"volume_db": -8.0},           # held file enters a tray
	&"cabinet_open": {"volume_db": -10, "pitch_var": 0.05, "path": "res://Assets/SFX/cabinet-open.mp3"}, # a cabinet drawer slides out (filing_cabinet.gd)
	&"file_archive": {},                          # filed into Public Archive
	&"file_truth": {},                            # filed into Department of Truth
	&"file_incinerate": {},                       # filed into Incinerator
	# --- Document viewer & redaction (document_viewer.gd)
	&"doc_open": {"pitch_var": 0.05},             # document opened full screen
	&"doc_close": {"pitch_var": 0.05},            # document closed
	&"marker_down": {"pitch_var": 0.1},           # marker touches paper
	# Looping scribble while drawing; alternates between the variations.
	&"marker_loop": {"volume_db": -4.0, "pitch_var": 0.06, "paths": [
		"res://Assets/SFX/highlighter",
		"res://Assets/SFX/highlighter-2",
	]},
	# --- In-game atmosphere (main.gd)
	&"ambience_crickets": {"volume_db": -12.0, "path": "res://Assets/SFX/night-cricket-ambience.mp3"}, # looped for the whole shift
	&"door_knock": {"volume_db": -4.0, "pitch_var": 0.04, "path": "res://Assets/SFX/door-knocking.mp3"}, # random, spaced out
	&"whisper": {"volume_db": -8.0, "pitch_var": 0.05, "path": "res://Assets/SFX/whisper.mp3"}, # random, rarer than knocks
	&"case_arrive": {"pitch_var": 0.06, "path": "res://Assets/SFX/paper-slide.mp3"}, # new case lands on the desk
	&"printer": {"path": "res://Assets/SFX/printer.mp3"}, # reserved: call when the printing machine is built
	# --- Shift & ending (shift_screen.gd, ending_screen.gd)
	&"shift_card": {"path": "res://Assets/SFX/bell-sound.mp3"}, # the "SHIFT N" card appears
	&"shift_begin": {},                           # BEGIN SHIFT pressed
	&"ending_reveal": {},                         # fallback stinger for any ending
	&"ending_loyalist": {},                       # optional per-ending stingers;
	&"ending_liability": {},                      # when missing, ending_reveal
	&"ending_paranoid": {},                       # plays instead
	&"ending_zealot": {},
	&"clock_out": {},                             # CLOCK OUT (punch clock)
	# --- Menu & Record of Outcomes (main_menu.gd, outcome_slot.gd)
	&"ui_hover": {"volume_db": -10.0, "pitch_var": 0.05},
	&"ui_click": {},
	&"page_flip": {"path": "res://Assets/SFX/FlippingPages.ogg"},
	&"slot_select": {"path": "res://Assets/SFX/click.mp3"}, # clicked a filed (unlocked) outcome
	&"slot_locked": {"volume_db": -4.0, "path": "res://Assets/SFX/error-sound.mp3"}, # clicked a not-yet-filed outcome
}

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _loops := {} # id -> AudioStreamPlayer, for sounds started with start_loop()
var _streams := {} # id -> Array of AudioStream (cached lookups; empty = no file yet)
var _last_variant := {} # id -> index of the variation played last time


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # keep playing while the tree is paused
	for i in POOL_SIZE:
		_pool.append(_make_player())


## Plays a one-shot sound. Returns false when the sound has no file yet, so
## callers can fall back to another id: if not SFX.play(a): SFX.play(b)
func play(id: StringName) -> bool:
	if not has_sound(id):
		return false
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	_apply(player, id)
	player.play()
	return true


## Starts a sound that repeats until stop_loop(id) (e.g. the marker scribble).
## Calling it again while already looping does nothing. Every repeat picks a
## new variation and pitch, whatever the file's "loop" import option says.
func start_loop(id: StringName) -> void:
	if _loops.has(id) or not has_sound(id):
		return
	var player := _make_player()
	_apply(player, id)
	player.finished.connect(func():
		_apply(player, id)
		player.play()
	)
	_loops[id] = player
	player.play()


func stop_loop(id: StringName) -> void:
	var player: AudioStreamPlayer = _loops.get(id)
	if player == null:
		return
	_loops.erase(id)
	player.stop()
	player.queue_free()


func has_sound(id: StringName) -> bool:
	return not _get_streams(id).is_empty()


func _make_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = BUS_NAME if AudioServer.get_bus_index(BUS_NAME) != -1 else &"Master"
	add_child(player)
	return player


func _apply(player: AudioStreamPlayer, id: StringName) -> void:
	var settings: Dictionary = SOUNDS.get(id, {})
	var pitch_var: float = settings.get("pitch_var", 0.0)
	player.stream = _pick_variant(id)
	player.volume_db = settings.get("volume_db", 0.0)
	player.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)


## A random variation, never the same one twice in a row.
func _pick_variant(id: StringName) -> AudioStream:
	var streams := _get_streams(id)
	var index := randi() % streams.size()
	if streams.size() > 1 and index == _last_variant.get(id, -1):
		index = (index + 1 + randi() % (streams.size() - 1)) % streams.size()
	_last_variant[id] = index
	return streams[index]


func _get_streams(id: StringName) -> Array:
	if _streams.has(id):
		return _streams[id]
	if not SOUNDS.has(id):
		push_warning("SFX: unknown sound id '%s' — add it to SOUNDS in sfx.gd" % id)
	var settings: Dictionary = SOUNDS.get(id, {})
	var found: Array = []
	if settings.has("paths"):
		for path in settings["paths"]: # every variation that exists
			var stream := _load_audio(path)
			if stream != null:
				found.append(stream)
	else:
		var candidates: PackedStringArray = []
		if settings.has("path"):
			candidates.append(settings["path"])
		candidates.append(SFX_DIR + String(id)) # file named after the id
		for path in candidates:
			var stream := _load_audio(path)
			if stream != null:
				found.append(stream)
				break
	_streams[id] = found
	return found


## Loads a path as given, or — when it has no extension — the first of
## .ogg/.wav/.mp3 that exists. Returns null when nothing is there.
func _load_audio(path: String) -> AudioStream:
	var candidates: PackedStringArray = [path]
	if path.get_extension().is_empty():
		candidates.clear()
		for ext in EXTENSIONS:
			candidates.append("%s.%s" % [path, ext])
	for candidate in candidates:
		if ResourceLoader.exists(candidate):
			var stream := load(candidate) as AudioStream
			if stream != null:
				return stream
	return null
