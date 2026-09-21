class_name DocumentViewer
extends CanvasLayer

## Full-screen document view. While visible, this is the only node that
## receives document strokes; the desk paper is disabled by Main.

signal closed(redaction_result: Dictionary)

var case_data: CaseData
var _inking := false

@onready var document: Node2D = $Document
@onready var asset: Sprite2D = $Document/Asset
@onready var redaction: RedactionLayer = $Document/RedactionLayer
@onready var close_button: Button = $CloseButton
@onready var backdrop: ColorRect = $Backdrop


func _ready() -> void:
	close_button.pressed.connect(close)
	visible = false


func open(new_case_data: CaseData) -> void:
	case_data = new_case_data
	var viewport_size := get_viewport().get_visible_rect().size
	backdrop.size = viewport_size
	document.position = viewport_size * 0.5
	asset.texture = case_data.asset
	redaction.set_case_data(case_data)
	visible = true


func close() -> void:
	if not visible:
		return
	_inking = false
	visible = false
	closed.emit(redaction.evaluate_redaction())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _contains_document(event.position):
			_inking = true
			redaction.begin_stroke(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _inking:
			_inking = false
			redaction.end_stroke()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _inking and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		redaction.stroke_to(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed and _contains_document(event.position):
			_inking = true
			redaction.begin_stroke(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _inking:
			_inking = false
			redaction.end_stroke()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _inking:
		redaction.stroke_to(event.position)
		get_viewport().set_input_as_handled()


func _contains_document(screen_position: Vector2) -> bool:
	var local := document.to_local(screen_position)
	return Rect2(-RedactionLayer.IMG_SIZE * 0.5, RedactionLayer.IMG_SIZE).has_point(local)
