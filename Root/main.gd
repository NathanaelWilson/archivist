extends Node2D

## The playable one-case loop. Assign another CaseData resource to current_case
## when the next document should slide onto the desk.

const FILE_ENTITY_SCENE := preload("res://Scenes/file_entity.tscn")
const FILING_TRAY_SCENE := preload("res://Scenes/filing_tray.tscn")

@export var current_case: CaseData

@onready var document_viewer: DocumentViewer = $DocumentViewer
var active_file: FileEntity


func _ready() -> void:
	_spawn_trays()
	document_viewer.closed.connect(_on_document_closed)
	if current_case != null:
		spawn_case(current_case)


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
	print("Filed ", case_data.id, " | tray correct: ", correct_tray, " | redaction correct: ", redaction_passed)
	# Hook the printer-slip / next-case code here. This method intentionally does
	# not tell the player whether either value was correct.
