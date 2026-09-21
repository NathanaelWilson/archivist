class_name FileEntity
extends Area2D

## The "dummy" file/document object the player interacts with all game.
##
## On the desk, the paper only has two gestures: tap to open it, or hold and
## drag it to a tray. Redaction belongs to DocumentViewer after it is opened,
## so the two gestures can never compete for the same touch.
##
## State machine: RESTING -> (INKING | HELD) -> RESTING, or HELD -> FILING -> freed.

signal open_requested
signal picked_up
signal returned_to_desk
signal filed(tray_type: int)
signal filing_evaluated(tray_type: int, redaction_result: Dictionary)

enum State { RESTING, HELD, FILING }

## A short hold promotes a touch to a pickup. Releasing before it elapses
## opens the document instead.
@export var hold_threshold_sec: float = 0.16
@export var max_tilt_deg: float = 10.0
@export var return_time_sec: float = 0.18
@export var file_time_sec: float = 0.12

@export var case_data: CaseData

@onready var collision: CollisionShape2D = $CollisionShape2D

var _state: State = State.RESTING
var _rest_position: Vector2
var _rest_rotation: float
var _drag_offset: Vector2 = Vector2.ZERO

# Gesture-in-progress bookkeeping. _pending is true from touch-down until
# the gesture resolves to either INKING or HELD.
var _pending: bool = false
var _touch_start_pos: Vector2 = Vector2.ZERO
var _hold_timer_id: int = 0
var _interaction_enabled := true
var _redaction_result: Dictionary = {"is_valid": false, "reason": "Document has not been checked."}


func _ready() -> void:
	_rest_position = position
	_rest_rotation = rotation
	monitoring = true
	monitorable = true


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	_pending = false
	_hold_timer_id += 1


func set_redaction_result(result: Dictionary) -> void:
	_redaction_result = result


func is_held() -> bool:
	return _state == State.HELD


# ---------------------------------------------------------------- Input --
# NOTE: this handles a single pointer (mouse, or one finger via Godot's
# "emulate touch from mouse" project setting). The GDD also calls for
# two-finger pan and pinch-to-zoom on the document — those are a separate,
# additive gesture layer (distinct touch indices via InputEventScreenDrag)
# that should sit above this node rather than inside it; not implemented
# here since it doesn't interact with filing.

func _input(event: InputEvent) -> void:
	if not _interaction_enabled or _state == State.FILING:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not event.is_echo():
			_begin_touch(event.position)
		elif not event.pressed:
			_end_touch(event.position)

	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_move_touch(event.position)

	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_touch(event.position)
		else:
			_end_touch(event.position)

	elif event is InputEventScreenDrag:
		_move_touch(event.position)


func _begin_touch(screen_pos: Vector2) -> void:
	if _state != State.RESTING or not _contains_point(screen_pos):
		return
	_pending = true
	_touch_start_pos = screen_pos
	_drag_offset = global_position - screen_pos
	_hold_timer_id += 1
	var my_timer_id := _hold_timer_id
	get_tree().create_timer(hold_threshold_sec).timeout.connect(
		func(): _on_hold_elapsed(my_timer_id)
	)


func _on_hold_elapsed(timer_id: int) -> void:
	if timer_id == _hold_timer_id and _pending and _state == State.RESTING:
		_begin_pickup()


func _move_touch(screen_pos: Vector2) -> void:
	if _state == State.HELD:
		_drag_to(screen_pos)


func _end_touch(screen_pos: Vector2) -> void:
	_pending = false
	_hold_timer_id += 1 # invalidate any pending hold timer
	match _state:
		State.HELD:
			_try_drop(screen_pos)
		State.RESTING:
			open_requested.emit()


func _contains_point(screen_pos: Vector2) -> bool:
	var shape := collision.shape as RectangleShape2D
	if shape == null:
		return false
	# to_local() already accounts for this node's scale, so multiplying by
	# scale here would make the touch hitbox incorrectly larger a second time.
	var extents: Vector2 = shape.size * 0.5
	var local := to_local(screen_pos)
	return abs(local.x) <= extents.x and abs(local.y) <= extents.y


# ---------------------------------------------------------- Pickup/drop --

func _begin_pickup() -> void:
	_state = State.HELD
	z_index = 100
	picked_up.emit()


func _drag_to(screen_pos: Vector2) -> void:
	var target := screen_pos + _drag_offset
	position = target
	# "Picked up and tilted under the finger" — tilt reads off how far the
	# drag has moved from rest, capped at max_tilt_deg either way.
	var delta_x := target.x - _rest_position.x
	var tilt_t: float = clamp(delta_x / 300.0, -1.0, 1.0)
	rotation = deg_to_rad(max_tilt_deg) * tilt_t


func _try_drop(_screen_pos: Vector2) -> void:
	var tray := _first_overlapping_tray()
	if tray:
		_commit_to_tray(tray)
	else:
		_return_to_desk()


func _first_overlapping_tray() -> FilingTray:
	for area in get_overlapping_areas():
		if area is FilingTray:
			return area
	return null


func _commit_to_tray(tray: FilingTray) -> void:
	_state = State.FILING
	tray.notify_received(self)
	var tray_type: int = tray.tray_type
	var tw := create_tween()
	tw.tween_property(self, "global_position", tray.global_position, file_time_sec) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", scale * 0.55, file_time_sec)
	tw.parallel().tween_property(self, "modulate:a", 0.0, file_time_sec)
	tw.finished.connect(func():
		filed.emit(tray_type)
		filing_evaluated.emit(tray_type, _redaction_result)
		queue_free()
	)


func _return_to_desk() -> void:
	_state = State.RESTING
	z_index = 0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", _rest_position, return_time_sec) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", _rest_rotation, return_time_sec)
	tw.chain().tween_callback(func(): returned_to_desk.emit())
