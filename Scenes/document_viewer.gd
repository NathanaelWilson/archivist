class_name DocumentViewer
extends CanvasLayer

## Full-screen document view. While visible, this is the only node that
## receives document strokes; the desk paper is disabled by Main.
##
## Controls (touch first, mouse/trackpad for desktop):
##   * one finger on the page     — draw with the marker
##   * UNDO (bottom right)        — take back the last stroke, any case
##   * tap anywhere off the page  — put the document down (close)
##   * two-finger pinch / drag    — zoom in and move around the page
##     (desktop: mouse wheel / trackpad pinch to zoom, right- or
##     middle-drag / two-finger scroll to move)
## The old Close button is kept in the scene but hidden.

## ink_image is a copy of the ink on the page, so the file can keep it and
## hand it back the next time it is opened.
## bleed_image is how far that ink has bled (null unless the case bleeds).
signal closed(redaction_result: Dictionary, ink_image: Image, bleed_image: Image)

## Space kept clear between the document and the screen edges, in viewport
## pixels, on top of room for the "?" / UNDO buttons at the sides.
@export var screen_margin := 16.0
@export var side_buttons_width := 76.0
@export var max_zoom := 4.0
## Zoom change per mouse-wheel notch.
@export var wheel_zoom_step := 1.15
## A touch that moves further than this is a drag, not a tap (viewport px).
@export var tap_slop := 12.0

var case_data: CaseData
var _inking := false
var _document_size := Vector2(RedactionLayer.IMG_SIZE)

@onready var document: Node2D = $Document
@onready var asset: Sprite2D = $Document/Asset
@onready var paper: ColorRect = $Document/Paper
@onready var redaction: RedactionLayer = $Document/RedactionLayer
@onready var close_button: Button = $CloseButton
@onready var backdrop: ColorRect = $Backdrop

const TUTORIAL_SCENE := preload("res://Scenes/Tutorial/redaction_tutorial.tscn")
## UNDO for every case, plus the "?" help + marker demo for tutorial cases.
var _tutorial: RedactionTutorial

# --- zoom / pan state
var _center := Vector2.ZERO ## the page's resting centre on screen
var _zoom := 1.0
var _pan := Vector2.ZERO
var _touches := {} ## finger index -> screen position
var _pinch_distance := 0.0
var _pinch_mid := Vector2.ZERO
## A pinch happened during the current touch, so its release is not a tap.
var _gesture_used := false
var _mouse_panning := false
# --- tap-off-the-page-to-close
var _outside_press: Variant = null


func _ready() -> void:
	close_button.visible = false # tap off the page instead
	_tutorial = TUTORIAL_SCENE.instantiate()
	add_child(_tutorial)
	_tutorial.undo_requested.connect(_on_undo_requested)
	visible = false


func open(new_case_data: CaseData, saved_ink: Image = null, saved_bleed: Image = null) -> void:
	if new_case_data == null:
		push_error("DocumentViewer.open() was called without a CaseData.")
		return
	case_data = new_case_data
	var viewport_size := get_viewport().get_visible_rect().size
	backdrop.size = viewport_size
	_center = viewport_size * 0.5
	_reset_view()
	asset.texture = case_data.asset
	_document_size = _fit_document(viewport_size)
	paper.position = -_document_size * 0.5
	paper.size = _document_size
	redaction.set_case_data(case_data, Vector2i(_document_size), saved_ink, saved_bleed)
	visible = true
	_tutorial.present(case_data, document, _document_size)
	_tutorial.set_undo_available(redaction.can_undo())
	SFX.play(&"doc_open")


## Scales the case art so the whole page fits on screen, keeping its aspect
## ratio. Returns the on-screen size of the document in viewport pixels; the
## redaction canvas is created at this size so one ink pixel = one screen pixel
## (at zoom 1) and the normalized anomaly regions still line up with the art.
func _fit_document(viewport_size: Vector2) -> Vector2:
	var side_gutter := screen_margin + side_buttons_width
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
	if _inking:
		_end_ink()
	_touches.clear()
	_mouse_panning = false
	_outside_press = null
	_tutorial.dismiss()
	visible = false
	SFX.play(&"doc_close")
	closed.emit(redaction.evaluate_redaction(), redaction.get_ink_image(), redaction.get_bleed_image())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _handle_zoom_input(event):
		get_viewport().set_input_as_handled()
		return

	# Touch drives the marker; the mouse is the desktop debug path. See
	# PointerInput for why the phone's emulated mouse events are dropped.
	var press: Variant = PointerInput.press_position(event)
	if press != null:
		if _contains_document(press as Vector2):
			_begin_ink(press as Vector2)
		elif not _tutorial.is_over_controls(press as Vector2):
			_outside_press = press
		get_viewport().set_input_as_handled()
		return

	var drag: Variant = PointerInput.drag_position(event)
	if drag != null:
		if _inking:
			redaction.stroke_to(drag as Vector2)
		elif _outside_press != null and (drag as Vector2).distance_to(_outside_press) > tap_slop:
			_outside_press = null # it was a swipe, not a tap
		get_viewport().set_input_as_handled()
		return

	var release: Variant = PointerInput.release_position(event)
	if release != null:
		if _inking:
			_end_ink()
		elif _outside_press != null and not _gesture_used \
				and (release as Vector2).distance_to(_outside_press) <= tap_slop \
				and not _contains_document(release as Vector2):
			_outside_press = null
			close()
		_outside_press = null
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- Zoom --

## Pinch/pan gestures. Returns true when the event was used for the view.
func _handle_zoom_input(event: InputEvent) -> bool:
	# Trackpad (desktop): pinch to zoom, two-finger scroll to move.
	if event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
		return true
	if event is InputEventPanGesture:
		if _zoom > 1.0:
			_pan -= event.delta * 12.0
			_apply_view()
		return true

	# Mouse wheel zooms at the cursor; right/middle drag moves the page.
	if event is InputEventMouseButton and not PointerInput.is_emulated(event):
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, wheel_zoom_step)
			return true
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1.0 / wheel_zoom_step)
			return true
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_mouse_panning = event.pressed
			return true
	if event is InputEventMouseMotion and _mouse_panning and not PointerInput.is_emulated(event):
		_pan += event.relative
		_apply_view()
		return true

	# Touch: a second finger turns the gesture into pinch-zoom + pan.
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() >= 2:
			_start_pinch()
			return true
		if _touches.is_empty():
			_gesture_used = false
		return event.index != PointerInput.PRIMARY_FINGER
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			_update_pinch()
			return true
		return event.index != PointerInput.PRIMARY_FINGER
	return false


func _start_pinch() -> void:
	_gesture_used = true
	_outside_press = null
	if _inking:
		# The first finger was drawing before the second landed: that was a
		# pinch, not a stroke, so take the mark back.
		_inking = false
		SFX.stop_loop(&"marker_loop")
		redaction.end_stroke()
		redaction.undo_last_stroke()
		_tutorial.set_undo_available(redaction.can_undo())
	var points := _two_touches()
	_pinch_distance = maxf(points[0].distance_to(points[1]), 1.0)
	_pinch_mid = (points[0] + points[1]) * 0.5


func _update_pinch() -> void:
	var points := _two_touches()
	var distance := maxf(points[0].distance_to(points[1]), 1.0)
	var mid := (points[0] + points[1]) * 0.5
	_zoom_at(mid, distance / _pinch_distance)
	_pan += mid - _pinch_mid
	_apply_view()
	_pinch_distance = distance
	_pinch_mid = mid


func _two_touches() -> Array[Vector2]:
	var keys := _touches.keys()
	keys.sort()
	return [_touches[keys[0]], _touches[keys[1]]]


## Zooms by factor, keeping the page point under screen_point where it is.
func _zoom_at(screen_point: Vector2, factor: float) -> void:
	var page_point := (screen_point - _center - _pan) / _zoom
	_zoom = clampf(_zoom * factor, 1.0, max_zoom)
	_pan = screen_point - _center - page_point * _zoom
	_apply_view()


func _reset_view() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	_touches.clear()
	_gesture_used = false
	_mouse_panning = false
	_outside_press = null
	_apply_view()


## Applies zoom and pan, never letting the page drift off screen: zoomed in,
## it can be moved until its edge meets the screen edge.
func _apply_view() -> void:
	var view := get_viewport().get_visible_rect().size
	var scaled := _document_size * _zoom
	var limit := Vector2(
		maxf(0.0, (scaled.x - view.x) * 0.5 + screen_margin),
		maxf(0.0, (scaled.y - view.y) * 0.5 + screen_margin)
	)
	if _zoom <= 1.0:
		limit = Vector2.ZERO
	_pan = _pan.clamp(-limit, limit)
	document.scale = Vector2.ONE * _zoom
	document.position = _center + _pan


# ---------------------------------------------------------------- Ink --

func _begin_ink(position: Vector2) -> void:
	_inking = true
	_tutorial.on_ink_started()
	SFX.play(&"marker_down")
	SFX.start_loop(&"marker_loop")
	redaction.begin_stroke(position)


func _on_undo_requested() -> void:
	if _inking:
		return
	redaction.undo_last_stroke()
	_tutorial.set_undo_available(redaction.can_undo())


func _end_ink() -> void:
	_inking = false
	SFX.stop_loop(&"marker_loop")
	redaction.end_stroke()
	_tutorial.set_undo_available(redaction.can_undo())


func _contains_document(screen_position: Vector2) -> bool:
	var local := document.to_local(screen_position)
	return Rect2(-_document_size * 0.5, _document_size).has_point(local)
