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
var _hover_tray: FilingTray
var _redaction_result: Dictionary = {"is_valid": false, "reason": "Document has not been checked."}
## Ink the player has put on this document, kept while the viewer is closed.
## null until the document is opened and closed for the first time.
var ink_image: Image
## How far that ink has bled, for cases whose marker bleeds. Never scored.
var bleed_image: Image


func _ready() -> void:
	_rest_position = position
	_rest_rotation = rotation
	monitoring = true
	monitorable = true


## Moves the file and makes that its resting spot, so a drop outside every
## tray slides it back here rather than to where it was spawned.
func place_at(point: Vector2) -> void:
	position = point
	_rest_position = point


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	_pending = false
	_hold_timer_id += 1


func set_redaction_result(result: Dictionary) -> void:
	_redaction_result = result


func is_held() -> bool:
	return _state == State.HELD


# ---------------------------------------------------------------- Input --
# One finger: tap the paper to open it, or press and drag it to a tray.
# PointerInput turns touch (the real control) and a debug mouse into the same
# three gestures, and drops the mouse events a phone emulates from the touch
# so a single tap is never handled twice. The GDD also calls for two-finger
# pan and pinch-to-zoom on the document — a separate gesture layer above this
# node, using the other touch indices; not implemented here since it doesn't
# interact with filing.

func _input(event: InputEvent) -> void:
	if not _interaction_enabled or _state == State.FILING:
		return

	# A gesture this paper owns is marked handled, so the desk props
	# underneath it (the clipboard, the case tray) never react to the same
	# touch.
	var press: Variant = PointerInput.press_position(event)
	if press != null:
		_begin_touch(press as Vector2)
		if _pending:
			get_viewport().set_input_as_handled()
		return

	var drag: Variant = PointerInput.drag_position(event)
	if drag != null:
		var was_held := _state == State.HELD
		_move_touch(drag as Vector2)
		if was_held:
			get_viewport().set_input_as_handled()
		return

	var release: Variant = PointerInput.release_position(event)
	if release != null:
		var owned := _pending or _state == State.HELD
		_end_touch(release as Vector2)
		if owned:
			get_viewport().set_input_as_handled()


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
		_set_hover_tray(_tray_at(screen_pos))


func _end_touch(screen_pos: Vector2) -> void:
	var was_tap_on_paper := _pending and _contains_point(screen_pos)
	_pending = false
	_hold_timer_id += 1 # invalidate any pending hold timer
	match _state:
		State.HELD:
			_try_drop(screen_pos)
		State.RESTING:
			# Only a tap that both started and ended on the paper opens it —
			# a tap anywhere else on the desk is not meant for this document.
			if was_tap_on_paper:
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
	SFX.play(&"file_pickup")
	picked_up.emit()


func _drag_to(screen_pos: Vector2) -> void:
	var target := screen_pos + _drag_offset
	position = target
	# "Picked up and tilted under the finger" — tilt reads off how far the
	# drag has moved from rest, capped at max_tilt_deg either way.
	var delta_x := target.x - _rest_position.x
	var tilt_t: float = clamp(delta_x / 300.0, -1.0, 1.0)
	rotation = deg_to_rad(max_tilt_deg) * tilt_t


func _try_drop(screen_pos: Vector2) -> void:
	_set_hover_tray(null)
	var tray := _tray_at(screen_pos)
	if tray:
		_commit_to_tray(tray)
	else:
		_return_to_desk()


## The tray the player is pointing at. The paper is taller than the gap
## between trays, so it usually overlaps all three at once — the overlap list
## alone would pick an arbitrary one. The pointer is what decides.
func _tray_at(screen_pos: Vector2) -> FilingTray:
	var best: FilingTray = null
	var best_distance := INF
	for area in get_overlapping_areas():
		if area is FilingTray:
			var distance: float = area.global_position.distance_to(screen_pos)
			if distance < best_distance:
				best_distance = distance
				best = area
	return best


func _set_hover_tray(tray: FilingTray) -> void:
	if tray == _hover_tray:
		return
	if is_instance_valid(_hover_tray):
		_hover_tray.set_hovered(false)
	_hover_tray = tray
	if is_instance_valid(_hover_tray):
		_hover_tray.set_hovered(true)


func _commit_to_tray(tray: FilingTray) -> void:
	_state = State.FILING
	tray.notify_received(self)
	var tray_type: int = tray.tray_type
	SFX.play(_filing_sound(tray_type))
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


func _filing_sound(tray_type: int) -> StringName:
	match tray_type:
		FilingTray.TrayType.DEPARTMENT_OF_TRUTH:
			return &"file_truth"
		FilingTray.TrayType.INCINERATOR:
			return &"file_incinerate"
	return &"file_archive"


func _return_to_desk() -> void:
	_set_hover_tray(null)
	_state = State.RESTING
	SFX.play(&"file_return")
	z_index = 0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", _rest_position, return_time_sec) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", _rest_rotation, return_time_sec)
	tw.chain().tween_callback(func(): returned_to_desk.emit())
