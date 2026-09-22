extends Node2D

## The playable shift loop. Each ShiftData resource owns the ordered cases for
## one shift; the same CaseData can intentionally be reused across shifts.

const FILE_ENTITY_SCENE := preload("res://Scenes/file_entity.tscn")
const FILING_TRAY_SCENE := preload("res://Scenes/filing_tray.tscn")

@export var shifts: Array[ShiftData] = []

@onready var document_viewer: DocumentViewer = $DocumentViewer
@onready var shift_screen: ShiftScreen = $ShiftScreen
var active_file: FileEntity
var _shift_index := 0
var _case_index := 0


func _ready() -> void:
	_spawn_trays()
	document_viewer.closed.connect(_on_document_closed)
	shift_screen.begin_requested.connect(_begin_current_shift)
	_show_current_shift()


func _show_current_shift() -> void:
	if _shift_index >= shifts.size():
		shift_screen.present_complete()
		return
	shift_screen.present_shift(shifts[_shift_index], _shift_index + 1, shifts.size())


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


func _open_document(file: FileEntity) -> void:
	active_file = file
	file.set_interaction_enabled(false)
	document_viewer.open(file.case_data)


func _on_document_closed(redaction_result: Dictionary) -> void:
	if is_instance_valid(active_file):
		active_file.set_redaction_result(redaction_result)
		active_file.set_interaction_enabled(true)
	active_file = null


func _spawn_trays() -> void:
	var viewport_size := get_viewport_rect().size
	var tray_x := viewport_size.x * 0.82
	for type in FilingTray.TrayType.values():
		var tray: FilingTray = FILING_TRAY_SCENE.instantiate()
		tray.tray_type = type
		tray.position = Vector2(tray_x, viewport_size.y * (0.25 + 0.25 * type))
		add_child(tray)


func _on_file_filed(tray_type: int, redaction_result: Dictionary, case_data: CaseData) -> void:
	var correct_tray: bool = tray_type == case_data.correct_tray
	var redaction_passed: bool = bool(redaction_result.get("is_valid", false))
	print("Filed ", case_data.id, " | tray correct: ", correct_tray, " | redaction correct: ", redaction_passed,
		" | ", redaction_result.get("reason", ""),
		" (coverage %.0f%%, overspill %.0f%%)" % [float(redaction_result.get("coverage", 0.0)) * 100.0, float(redaction_result.get("overspill", 0.0)) * 100.0])
	_case_index += 1
	# The document finishes its filing tween before the next one is spawned.
	call_deferred("_spawn_next_case")


func _finish_current_shift() -> void:
	_shift_index += 1
	_show_current_shift()
