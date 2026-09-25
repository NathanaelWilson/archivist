extends Node2D

## The playable shift loop. Each ShiftData resource owns the ordered cases for
## one shift; the same CaseData can intentionally be reused across shifts.

const FILE_ENTITY_SCENE := preload("res://Scenes/file_entity.tscn")

## One scene per Record-of-Outcomes ending (Scenes/Endings/). Keyed by the
## same StringName ids GameScore.evaluate_ending() returns.
const ENDING_SCENES := {
	&"loyalist": preload("res://Scenes/Endings/ending_loyalist.tscn"),
	&"liability": preload("res://Scenes/Endings/ending_liability.tscn"),
	&"paranoid": preload("res://Scenes/Endings/ending_paranoid.tscn"),
	&"zealot": preload("res://Scenes/Endings/ending_zealot.tscn"),
}

const MAIN_MENU_SCENE_PATH := "res://Scenes/MainMenu/main_menu.tscn"


const CLIPBOARD_BOARDS := {
	&"A": preload("res://Scenes/DirectivesClipboard/clipboard_boards/a.tres"),
	&"A2": preload("res://Scenes/DirectivesClipboard/clipboard_boards/a2.tres"),
	&"B": preload("res://Scenes/DirectivesClipboard/clipboard_boards/b.tres"),
	&"B2": preload("res://Scenes/DirectivesClipboard/clipboard_boards/b2.tres"),
	&"C": preload("res://Scenes/DirectivesClipboard/clipboard_boards/c.tres"),
	&"C2": preload("res://Scenes/DirectivesClipboard/clipboard_boards/c2.tres"),
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

const SLIP_PRINTER_SCENE := preload("res://Scenes/Slips/slip_printer.tscn")

## Unscaled size of the desk file's paper (Scenes/file_entity.tscn). Kept here
## so the paper pulled out of the case tray matches the file it turns into.
const FILE_PAPER_SIZE := Vector2(171, 342)

@export var shifts: Array[ShiftData] = []
## Random atmosphere sounds: each plays again after a random wait in its range.
@export var knock_min_sec := 35.0
@export var knock_max_sec := 75.0
@export var whisper_min_sec := 60.0
@export var whisper_max_sec := 120.0
## Two random atmosphere sounds never play closer together than this.
@export var ambient_min_gap_sec := 10.0
## Files lying on the painted desk are drawn at this scale (1.0 would make the
## placeholder paper almost as tall as the screen).
@export var desk_file_scale := 0.4

@onready var document_viewer: DocumentViewer = $DocumentViewer
@onready var shift_screen: ShiftScreen = $ShiftScreen
@onready var clipboard_panel: ClipboardPanel = $ClipboardPanel
@onready var eyelids: EyelidOverlay = $EyelidOverlay
@onready var case_container: CaseContainer = $Desk/CaseContainer
@onready var desk_clipboard: DeskProp = $Desk/Clipboard
var active_file: FileEntity
var _printer: SlipPrinter
var _shift_index := 0
var _case_index := 0
var _ambient_timers: Array[Timer] = []
## False while the eyes are opening or closing — the desk is visible but must
## not be touched, so no file can be picked up, opened or filed.
var _desk_input_enabled := true
var _last_ambient_msec := -100000


func _ready() -> void:
	GameScore.reset()
	Music.play(&"ingame")
	SFX.start_loop(&"ambience_crickets")
	_start_ambient(&"door_knock", knock_min_sec, knock_max_sec)
	_start_ambient(&"whisper", whisper_min_sec, whisper_max_sec)
	_printer = SLIP_PRINTER_SCENE.instantiate()
	_printer.position = get_viewport_rect().size * Vector2(0.82, 0.08)
	add_child(_printer)
	# The clipboard asks Main which board is live, so swaps stay Main's call.
	clipboard_panel.board_source = get_active_board
	# The desk art itself is the interface: cases are dragged out of the tray,
	# and the rules are read by tapping the clipboard.
	case_container.can_interact = _is_desk_free
	case_container.pulled_paper_size = FILE_PAPER_SIZE * desk_file_scale
	case_container.case_pulled.connect(_on_case_pulled)
	desk_clipboard.can_interact = _is_desk_free
	desk_clipboard.tapped.connect(clipboard_panel.open)
	document_viewer.closed.connect(_on_document_closed)
	shift_screen.begin_requested.connect(_begin_current_shift)
	_show_current_shift()


func _show_current_shift() -> void:
	# The eyes only blink while there is work in front of them.
	eyelids.stop_blinking()
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
	# The very first shift is the archivist waking up at the desk; later
	# shifts just carry on blinking.
	if _shift_index == 0:
		# Nothing can be touched until the eyes have finished opening.
		_set_desk_input_enabled(false)
		await eyelids.play_wake()
		_set_desk_input_enabled(true)
	else:
		eyelids.start_blinking()


func _spawn_next_case() -> void:
	var shift := shifts[_shift_index]
	if _case_index >= shift.cases.size():
		_finish_current_shift()
		return
	spawn_case(shift.cases[_case_index])


## A new case lands in the tray. It only becomes a file on the desk once the
## player drags it out (see _on_case_pulled).
func spawn_case(case_data: CaseData) -> void:
	case_container.load_case(case_data)
	SFX.play(&"case_arrive")


## The player dragged the case out of the tray and let go: lay it on the desk
## where it was dropped and open the case preview straight away. From then on
## it is an ordinary desk file — tap to reopen, hold and drag to a tray.
func _on_case_pulled(case_data: CaseData, screen_position: Vector2) -> void:
	var file: FileEntity = FILE_ENTITY_SCENE.instantiate()
	file.case_data = case_data
	file.scale = Vector2.ONE * desk_file_scale
	file.position = _clamp_to_screen(screen_position, FILE_PAPER_SIZE * desk_file_scale)
	file.set_interaction_enabled(_desk_input_enabled)
	add_child(file)
	file.filing_evaluated.connect(_on_file_filed.bind(case_data))
	file.open_requested.connect(_open_document.bind(file))
	_open_document(file)


## Keeps something of this size fully on screen when centred on point.
func _clamp_to_screen(point: Vector2, size: Vector2) -> Vector2:
	var view := get_viewport_rect().size
	var half := size * 0.5
	return Vector2(
		clampf(point.x, half.x, view.x - half.x),
		clampf(point.y, half.y, view.y - half.y)
	)


## Whether the desk props (case tray, clipboard) may be touched right now.
func _is_desk_free() -> bool:
	return _desk_input_enabled \
		and active_file == null \
		and not document_viewer.visible \
		and not shift_screen.visible \
		and not clipboard_panel.is_open() \
		and not _is_file_held()


## True while the player is carrying a desk file towards the cabinet, so the
## props it passes over don't light up underneath it.
func _is_file_held() -> bool:
	for child in get_children():
		if child is FileEntity and child.is_held():
			return true
	return false


func _open_document(file: FileEntity) -> void:
	if not _desk_input_enabled:
		return
	clipboard_panel.close()
	active_file = file
	file.set_interaction_enabled(false)
	document_viewer.open(file.case_data, file.ink_image)


func _on_document_closed(redaction_result: Dictionary, ink_image: Image) -> void:
	if is_instance_valid(active_file):
		active_file.ink_image = ink_image
		active_file.set_redaction_result(redaction_result)
		active_file.set_interaction_enabled(_desk_input_enabled)
	active_file = null


func _on_file_filed(tray_type: int, redaction_result: Dictionary, case_data: CaseData) -> void:
	var correct_tray: bool = FilingTray.is_wildcard(case_data.correct_tray) or tray_type == case_data.correct_tray
	var redaction_passed: bool = bool(redaction_result.get("is_valid", false))
	GameScore.register_case_result(case_data, tray_type, redaction_result)
	FilingLog.record_filing(case_data, tray_type, redaction_result)
	_print_slip_after_delay(tray_type)
	print("Filed ", case_data.id, " | tray correct: ", correct_tray, " | redaction correct: ", redaction_passed,
		" | ", redaction_result.get("reason", ""),
		" (coverage %.0f%%, overspill %.0f%%)" % [float(redaction_result.get("coverage", 0.0)) * 100.0, float(redaction_result.get("overspill", 0.0)) * 100.0],
		" | accuracy: ", GameScore.accuracy, " paranoia: ", GameScore.paranoia)
	_case_index += 1
	# The document finishes its filing tween before the next one is spawned.
	call_deferred("_spawn_next_case")


## The fax starts ~0.3 s after the drawer shuts (Build Guide 3.6) and the next
## case is allowed to arrive meanwhile, so this deliberately does not block
## the filing loop — it awaits internally, and _on_file_filed does not await it.
func _print_slip_after_delay(tray_type: int) -> void:
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(_printer):
		_printer.print_slip(SlipDeck.draw(tray_type))




## Turns the whole desk on or off: every paper on it, and the clipboard. Used
## for the eye-opening and eye-closing beats, where the desk is on screen but
## the archivist cannot yet (or can no longer) work.
func _set_desk_input_enabled(enabled: bool) -> void:
	_desk_input_enabled = enabled
	for child in get_children():
		if child is FileEntity:
			child.set_interaction_enabled(enabled)
	clipboard_panel.set_interactive(enabled)


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
	# After the last shift the eyes close for good, and the verdict fades up
	# out of that darkness.
	_set_desk_input_enabled(false)
	await eyelids.play_sleep()
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
	eyelids.reveal()
