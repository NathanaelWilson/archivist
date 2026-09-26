class_name EyelidOverlay
extends CanvasLayer

## The archivist's eyes. Purely visual — it never blocks input on its own
## (Main locks the desk while the eyes are moving).
##
## The lids are real shapes (Shaders/eyelid.gdshader): an upper and a lower
## lid that meet in the middle, instead of a fade.
##   wake  — start of every shift: a couple of heavy blinks, coming into focus.
##   sleep — end of every shift: a couple of blinks, then shut, out of focus.
## The layer sits under the shift card and the ending screens, so those are
## read over closed eyes.

signal wake_finished
signal sleep_finished

@export var wake_duration_sec := 1.3
@export var sleep_duration_sec := 1.1
@export var max_blur := 4.0

## Keyframes as [fraction of the duration, openness, fraction of max_blur].
## Both are blinks, not slow fades: the lids flutter a couple of times —
## heavy, fighting it — before the eye finally shuts (sleep) or settles open
## (wake). Remove the middle rows for a single straight close/open.
const WAKE_KEYS := [
	[0.00, 0.00, 1.00],
	[0.25, 0.55, 0.70],
	[0.38, 0.10, 0.80],
	[0.62, 0.85, 0.30],
	[0.72, 0.60, 0.25],
	[1.00, 1.00, 0.00],
]
const SLEEP_KEYS := [
	[0.00, 1.00, 0.00],
	[0.16, 0.20, 0.20],
	[0.30, 0.85, 0.10],
	[0.48, 0.10, 0.45],
	[0.60, 0.45, 0.50],
	[1.00, 0.00, 1.00],
]

var _tween: Tween

@onready var eyelid: ColorRect = $Eyelid


func _ready() -> void:
	_apply(1.0, 0.0)


## Shift 1: the eyes open for the first time. Awaitable.
func play_wake() -> void:
	_play_keys(WAKE_KEYS, wake_duration_sec)
	await _tween.finished
	wake_finished.emit()


## End of the last shift: the eyes close for good. Awaitable.
## duration_sec overrides sleep_duration_sec (the title card uses a short one).
func play_sleep(duration_sec := -1.0) -> void:
	_play_keys(SLEEP_KEYS, sleep_duration_sec if duration_sec <= 0.0 else duration_sec)
	await _tween.finished
	sleep_finished.emit()


## Opens the eyes plainly (no flutter) after play_sleep(), so the next
## screen is revealed under a rising lid. Awaitable.
func reveal(duration_sec := 1.2) -> void:
	_play_keys([[0.0, 0.0, 0.4], [1.0, 1.0, 0.0]], duration_sec)
	await _tween.finished


## Eyes shut at once, no animation — the state between shifts.
func close_now() -> void:
	_kill_tween()
	_apply(0.0, max_blur)


## Lids fully open, nothing drawn.
func clear() -> void:
	_kill_tween()
	_apply(1.0, 0.0)


func _play_keys(keys: Array, duration_sec: float) -> void:
	_kill_tween()
	var first: Array = keys[0]
	_apply(float(first[1]), float(first[2]) * max_blur)
	_tween = create_tween()
	for i in range(1, keys.size()):
		var from: Array = keys[i - 1]
		var to: Array = keys[i]
		var seconds := maxf((float(to[0]) - float(from[0])) * duration_sec, 0.01)
		# Ease in-out by default: starts and ends gently, never stops in the
		# middle. A key can override it (see WAKE_KEYS).
		var easing: int = int(to[3]) if to.size() > 3 else Tween.EASE_IN_OUT
		_tween.tween_method(
			_apply_between.bind(float(from[1]), float(from[2]), float(to[1]), float(to[2])),
			0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(easing)


func _apply_between(t: float, from_open: float, from_blur: float, to_open: float, to_blur: float) -> void:
	_apply(lerpf(from_open, to_open, t), lerpf(from_blur, to_blur, t) * max_blur)


func _apply(openness: float, blur: float) -> void:
	var shader_material := eyelid.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("openness", openness)
	shader_material.set_shader_parameter("blur", blur)
	# A wide-open, focused eye has nothing to draw, so the overlay steps aside.
	eyelid.visible = openness < 0.999 or blur > 0.001


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
