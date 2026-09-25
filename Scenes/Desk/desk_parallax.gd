class_name DeskParallax
extends Node

## Makes the desk view feel alive on a phone: tilting the device slides the
## whole desk a few pixels, as if the player were leaning over it. Nothing is
## ever revealed past the edge of the painted desk.
##
## How it works:
##   * It moves `target` — Main — whose Node2D children are the desk and
##     everything lying on it (envelope, trays, printer). The UI lives on
##     CanvasLayers (document viewer, clipboard, shift card, eyelids), which
##     are not affected, so only the room moves.
##   * The desk is zoomed in slightly (zoom) so there is art beyond the screen
##     edge to lean into; the offset is then clamped so the view can never
##     leave the Desk's painted background.
##   * Tilt comes from the gravity sensor. The "neutral" pose follows the
##     phone slowly (recenter_sec), so however the player holds it, it rests
##     centred — only movement is felt, not the angle they happen to sit at.
##   * On desktop there is no sensor; debug_mouse lets the mouse stand in.
##
## Input keeps working because the desk, files and trays all test touches
## with to_local()/global_position, which already include this transform.

@export var target: Node2D
@export var desk: Desk
## Extra zoom on the desk, giving room to move. 1.04 = 4% bigger.
@export_range(1.0, 1.2, 0.005) var zoom := 1.04
## Pixels of movement per unit of tilt (tilt is in g, about -1..1).
@export var strength := Vector2(60.0, 40.0)
## Hard cap on the movement, in viewport pixels, before the art-edge clamp.
@export var max_offset := Vector2(14.0, 9.0)
## How quickly the view follows the tilt (higher = snappier).
@export var follow_speed := 6.0
## How long the neutral pose takes to catch up with how the phone is held.
@export var recenter_sec := 3.0
## Desktop testing: lean with the mouse instead of the sensor.
@export var debug_mouse := false
## Sensor axes can come through rotated on some devices in landscape. If
## tilting left/right moves the desk up/down, tick swap_axes; if a direction
## feels backwards, flip that component of axis_sign to -1.
@export var swap_axes := false
@export var axis_sign := Vector2(1.0, 1.0)

var _neutral := Vector2.ZERO
var _has_neutral := false
var _offset := Vector2.ZERO


func _process(delta: float) -> void:
	if target == null:
		return
	var view := target.get_viewport_rect().size
	var desired := _read_lean(view) * strength
	desired = desired.clamp(-max_offset, max_offset)
	_offset = _offset.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))
	_apply(view)


## -1..1-ish lean, relative to the neutral pose.
func _read_lean(view: Vector2) -> Vector2:
	if debug_mouse and not OS.has_feature("mobile"):
		var mouse := target.get_viewport().get_mouse_position()
		return ((mouse / view) - Vector2(0.5, 0.5)) * 2.0 * 0.25
	var gravity := Input.get_gravity()
	if gravity == Vector3.ZERO:
		return Vector2.ZERO # no sensor (desktop, or not reporting yet)
	var tilt := Vector2(gravity.x, gravity.y) / 9.81
	if swap_axes:
		tilt = Vector2(tilt.y, tilt.x)
	tilt *= axis_sign
	if not _has_neutral:
		_neutral = tilt
		_has_neutral = true
	# The neutral pose drifts toward how the phone is actually being held.
	var drift := clampf(get_process_delta_time() / maxf(recenter_sec, 0.01), 0.0, 1.0)
	_neutral = _neutral.lerp(tilt, drift)
	# Leaning one way slides the room the other, like looking past it.
	return -(tilt - _neutral)


func _apply(view: Vector2) -> void:
	# Zoom about the centre of the screen, then offset.
	var position := view * 0.5 * (1.0 - zoom) + _offset
	# Keep the painted desk covering the whole screen: its rect, in Main's
	# space, scaled by zoom, must contain the viewport.
	if desk != null:
		var art := Rect2(desk.position, desk.design_size * desk.scale)
		position.x = clampf(position.x, view.x - art.end.x * zoom, -art.position.x * zoom)
		position.y = clampf(position.y, view.y - art.end.y * zoom, -art.position.y * zoom)
	target.scale = Vector2(zoom, zoom)
	target.position = position
