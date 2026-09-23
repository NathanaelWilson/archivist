class_name PointerInput
extends Object

## Touch is the real control scheme; the mouse is kept only so the game can be
## debugged on desktop. Both have to work at once, which is where the trap is:
## Godot's "emulate mouse from touch" setting is left ON (Buttons and other
## Controls need it to be tappable), so on a phone one finger also produces a
## full set of mouse events. Any handler that reads both would fire twice per
## tap — opening a document and immediately re-closing it, or stamping ink
## twice.
##
## So every raw pointer handler goes through here instead:
##   * real touch is always accepted,
##   * mouse events are accepted only when they came from an actual mouse
##     (emulated ones carry device == DEVICE_EMULATION),
##   * only the first finger drives a gesture, so a second thumb resting on
##     the screen cannot hijack a drag.
## Each function returns the screen position of the gesture, or null when the
## event is not that kind of gesture.

const DEVICE_EMULATION := -1 ## Godot's device id for emulated input.
const PRIMARY_FINGER := 0


static func is_emulated(event: InputEvent) -> bool:
	return event.device == DEVICE_EMULATION


## Finger (or mouse button) went down.
static func press_position(event: InputEvent) -> Variant:
	if event is InputEventScreenTouch:
		if event.pressed and event.index == PRIMARY_FINGER:
			return event.position
		return null
	if event is InputEventMouseButton and not is_emulated(event):
		if event.pressed and not event.is_echo() and event.button_index == MOUSE_BUTTON_LEFT:
			return event.position
	return null


## Finger (or mouse button) lifted.
static func release_position(event: InputEvent) -> Variant:
	if event is InputEventScreenTouch:
		if not event.pressed and event.index == PRIMARY_FINGER:
			return event.position
		return null
	if event is InputEventMouseButton and not is_emulated(event):
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			return event.position
	return null


## Finger dragging, or mouse moving with the left button held.
static func drag_position(event: InputEvent) -> Variant:
	if event is InputEventScreenDrag:
		if event.index == PRIMARY_FINGER:
			return event.position
		return null
	if event is InputEventMouseMotion and not is_emulated(event):
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			return event.position
	return null
