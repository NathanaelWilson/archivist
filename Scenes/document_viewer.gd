class_name DocumentViewer
extends CanvasLayer

## Full-screen document view. While visible, this is the only node that
## receives document strokes; the desk paper is disabled by Main.

## ink_image is a copy of the ink on the page, so the file can keep it and
## hand it back the next time it is opened.
signal closed(redaction_result: Dictionary, ink_image: Image)

## Space kept clear between the document and the screen edges, in viewport
## pixels. The document is also kept clear of the Close button on the left
## (mirrored on the right so it stays centred).
@export var screen_margin := 16.0

var case_data: CaseData
var _inking := false
var _document_size := Vector2(RedactionLayer.IMG_SIZE)

@onready var document: Node2D = $Document
@onready var asset: Sprite2D = $Document/Asset
@onready var paper: ColorRect = $Document/Paper
@onready var redaction: RedactionLayer = $Document/RedactionLayer
@onready var close_button: Button = $CloseButton
@onready var backdrop: ColorRect = $Backdrop


func _ready() -> void:
	close_button.pressed.connect(close)
	visible = false


func open(new_case_data: CaseData, saved_ink: Image = null) -> void:
	case_data = new_case_data
	var viewport_size := get_viewport().get_visible_rect().size
	backdrop.size = viewport_size
	document.position = viewport_size * 0.5
	asset.texture = case_data.asset
	_document_size = _fit_document(viewport_size)
	paper.position = -_document_size * 0.5
	paper.size = _document_size
	redaction.set_case_data(case_data, Vector2i(_document_size), saved_ink)
	visible = true
	SFX.play(&"doc_open")


## Scales the case art so the whole page fits on screen, keeping its aspect
## ratio. Returns the on-screen size of the document in viewport pixels; the
## redaction canvas is created at this size so one ink pixel = one screen pixel
## and the normalized anomaly regions still line up with the art.
func _fit_document(viewport_size: Vector2) -> Vector2:
	var side_gutter := maxf(screen_margin, close_button.get_rect().end.x + screen_margin)
	var available := Vector2(
		viewport_size.x - side_gutter * 2.0,
		viewport_size.y - screen_margin * 2.0
	)
	var source_size := Vector2(RedactionLayer.IMG_SIZE)
	if asset.texture != null:
		source_size = asset.texture.get_size()
	var fit_scale := minf(available.x / source_size.x, available.y / source_size.y)
	var fitted := (source_size * fit_scale).floor()
	# Scale from the rounded size so the art exactly matches the ink canvas.
	asset.scale = fitted / source_size
	return fitted


func close() -> void:
	if not visible:
		return
	_inking = false
	SFX.stop_loop(&"marker_loop")
	visible = false
	SFX.play(&"doc_close")
	closed.emit(redaction.evaluate_redaction(), redaction.get_ink_image())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _contains_document(event.position):
			_inking = true
			SFX.play(&"marker_down")
			SFX.start_loop(&"marker_loop")
			redaction.begin_stroke(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _inking:
			_inking = false
			SFX.stop_loop(&"marker_loop")
			redaction.end_stroke()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _inking and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		redaction.stroke_to(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed and _contains_document(event.position):
			_inking = true
			SFX.play(&"marker_down")
			SFX.start_loop(&"marker_loop")
			redaction.begin_stroke(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _inking:
			_inking = false
			SFX.stop_loop(&"marker_loop")
			redaction.end_stroke()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _inking:
		redaction.stroke_to(event.position)
		get_viewport().set_input_as_handled()


func _contains_document(screen_position: Vector2) -> bool:
	var local := document.to_local(screen_position)
	return Rect2(-_document_size * 0.5, _document_size).has_point(local)
