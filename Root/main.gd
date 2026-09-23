extends Node2D

## The playable shift loop. Each ShiftData resource owns the ordered cases for
## one shift; the same CaseData can intentionally be reused across shifts.

const FILE_ENTITY_SCENE := preload("res://Scenes/file_entity.tscn")
const FILING_TRAY_SCENE := preload("res://Scenes/filing_tray.tscn")

## One scene per Record-of-Outcomes ending (Scenes/Endings/). Keyed by the
## same StringName ids GameScore.evaluate_ending() returns.
const ENDING_SCENES := {
	&"loyalist": preload("res://Scenes/Endings/ending_loyalist.tscn"),
	&"liability": preload("res://Scenes/Endings/ending_liability.tscn"),
	&"paranoid": preload("res://Scenes/Endings/ending_paranoid.tscn"),
	&"zealot": preload("res://Scenes/Endings/ending_zealot.tscn"),
}

const MAIN_MENU_SCENE_PATH := "res://Scenes/main_menu.tscn"


const CLIPBOARD_BOARDS := {
	&"A": preload("res://Scenes/clipboard_boards/a.tres"),
	&"A2": preload("res://Scenes/clipboard_boards/a2.tres"),
	&"B": preload("res://Scenes/clipboard_boards/b.tres"),
	&"B2": preload("res://Scenes/clipboard_boards/b2.tres"),
	&"C": preload("res://Scenes/clipboard_boards/c.tres"),
	&"C2": preload("res://Scenes/clipboard_boards/c2.tres"),
}

## Per shift: [board before swap, board after swap, case index when the swap
## fires]. Case index is shift-relative and matches _case_index, so a swap
## at index N means every case below N uses the first board and N onward
## uses the second. Fire points come from the GDD: Shift One swaps before
## case 4, Shift Two before case 8, Shift Three before case 11.
const BOARD_PLAN := [
	[&"A", &"A2", 3],
	[&"B", &"B2", 2],
	[&"C", &"C2", 1],
]


@export var shifts: Array[ShiftData] = []
## Random atmosphere sounds: each plays again after a random wait in its range.
@export var knock_min_sec := 35.0
@export var knock_max_sec := 75.0
@export var whisper_min_sec := 60.0
@export var whisper_max_sec := 120.0
## Two random atmosphere sounds never play closer together than this.
@export var ambient_min_gap_sec := 10.0

@onready var document_viewer: DocumentViewer = $DocumentViewer
@onready var shift_screen: ShiftScreen = $ShiftScreen
var active_file: FileEntity
var _shift_index := 0
var _case_index := 0
var _ambient_timers: Array[Timer] = []
var _last_ambient_msec := -100000


func _ready() -> void:
	GameScore.reset()
	Music.play(&"ingame")
	SFX.start_loop(&"ambience_crickets")
	_start_ambient(&"door_knock", knock_min_sec, knock_max_sec)
	_start_ambient(&"whisper", whisper_min_sec, whisper_max_sec)
	_spawn_trays()
	document_viewer.closed.connect(_on_document_closed)
	shift_screen.begin_requested.connect(_begin_current_shift)
	_show_current_shift()


func _show_current_shift() -> void:
	if _shift_index >= shifts.size():
		_present_ending()
		return
	shift_screen.present_shift(shifts[_shift_index], _shift_index + 1, shifts.size())
	
	
## Which clipboard board is live right now. Called lazily by the clipboard
## UI when the player lifts it. Returns null past the last shift.
func get_active_board() -> ClipboardBoard:
	if _shift_index >= BOARD_PLAN.size():
		return null
	var plan: Array = BOARD_PLAN[_shift_index]
	var board_id: StringName = plan[0] if _case_index < plan[2] else plan[1]
	return CLIPBOARD_BOARDS.get(board_id)


func _begin_current_shift() -> void:
	if _shift_index >= shifts.size():
		return
	shift_screen.dismiss()
	_case_index = 0
	_spawn_next_case()


func _spawn_next_case() -> void:
	var shift := shifts[_shift_index]
	if _case_index >= shift.cases.size():
		_finish_current_shift()
		return
	spawn_case(shift.cases[_case_index])


func spawn_case(case_data: CaseData) -> void:
	var file: FileEntity = FILE_ENTITY_SCENE.instantiate()
	file.case_data = case_data
	file.position = get_viewport_rect().size * Vector2(0.34, 0.52)
	add_child(file)
	file.filing_evaluated.connect(_on_file_filed.bind(case_data))
	file.open_requested.connect(_open_document.bind(file))
	SFX.play(&"case_arrive")


func _open_document(file: FileEntity) -> void:
	active_file = file
	file.set_interaction_enabled(false)
	document_viewer.open(file.case_data, file.ink_image)


func _on_document_closed(redaction_result: Dictionary, ink_image: Image) -> void:
	if is_instance_valid(active_file):
		active_file.ink_image = ink_image
		active_file.set_redaction_result(redaction_result)
		active_file.set_interaction_enabled(true)
	active_file = null


func _spawn_trays() -> void:
	var viewport_size := get_viewport_rect().size
	var tray_x := viewport_size.x * 0.82
	# ANY is a case-side marker, not a drawer, so it is not spawned here.
	for index in FilingTray.SPAWNED_TRAY_TYPES.size():
		var type: int = FilingTray.SPAWNED_TRAY_TYPES[index]
		var tray: FilingTray = FILING_TRAY_SCENE.instantiate()
		tray.tray_type = type
		tray.position = Vector2(tray_x, viewport_size.y * (0.25 + 0.25 * index))
		add_child(tray)


func _on_file_filed(tray_type: int, redaction_result: Dictionary, case_data: CaseData) -> void:
	var correct_tray: bool = FilingTray.is_wildcard(case_data.correct_tray) or tray_type == case_data.correct_tray
	var redaction_passed: bool = bool(redaction_result.get("is_valid", false))
	GameScore.register_case_result(case_data, tray_type, redaction_result)
	FilingLog.record_filing(case_data, tray_type, redaction_result)
	print("Filed ", case_data.id, " | tray correct: ", correct_tray, " | redaction correct: ", redaction_passed,
		" | ", redaction_result.get("reason", ""),
		" (coverage %.0f%%, overspill %.0f%%)" % [float(redaction_result.get("coverage", 0.0)) * 100.0, float(redaction_result.get("overspill", 0.0)) * 100.0],
		" | accuracy: ", GameScore.accuracy, " paranoia: ", GameScore.paranoia)
	_case_index += 1
	# The document finishes its filing tween before the next one is spawned.
	call_deferred("_spawn_next_case")




func _start_ambient(id: StringName, min_sec: float, max_sec: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_ambient_timeout.bind(timer, id, min_sec, max_sec))
	add_child(timer)
	_ambient_timers.append(timer)
	timer.start(randf_range(min_sec, max_sec))


func _on_ambient_timeout(timer: Timer, id: StringName, min_sec: float, max_sec: float) -> void:
	var since_last := (Time.get_ticks_msec() - _last_ambient_msec) / 1000.0
	if since_last < ambient_min_gap_sec:
		# Too close to the other sound: wait until the gap has passed.
		timer.start(ambient_min_gap_sec - since_last + randf_range(1.0, 4.0))
		return
	SFX.play(id)
	_last_ambient_msec = Time.get_ticks_msec()
	timer.start(randf_range(min_sec, max_sec))


## The crickets loop lives on the SFX autoload, so it has to be stopped here
## or it would keep playing into the main menu.
func _stop_atmosphere() -> void:
	SFX.stop_loop(&"ambience_crickets")
	for timer in _ambient_timers:
		if is_instance_valid(timer):
			timer.stop()


func _exit_tree() -> void:
	_stop_atmosphere()


func _finish_current_shift() -> void:
	_shift_index += 1
	_show_current_shift()


## Reads GameScore's tally, picks the matching Record-of-Outcomes ending
## scene, and shows it in place of the old generic "SHIFT COMPLETE" screen.
func _present_ending() -> void:
	shift_screen.dismiss()
	_stop_atmosphere()
	var ending_id := GameScore.evaluate_ending()
	OutcomeRecord.file_ending(ending_id)
	print("Run complete | accuracy: ", GameScore.accuracy, " paranoia: ", GameScore.paranoia, " -> ", ending_id)
	var ending_scene: PackedScene = ENDING_SCENES.get(ending_id)
	if ending_scene == null:
		push_warning("No ending scene registered for id: %s" % ending_id)
		return
	var ending: EndingScreen = ending_scene.instantiate()
	add_child(ending)
	ending.clocked_out.connect(func(): get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH))
	ending.present()
