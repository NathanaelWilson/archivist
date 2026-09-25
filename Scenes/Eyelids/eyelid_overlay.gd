class_name EyelidOverlay
extends CanvasLayer

## The archivist's eyes. Everything here is purely visual — it never blocks
## input, so a blink cannot eat a tap or cut a marker stroke in half.
##
## Three beats:
##   blink — every blink_interval_sec, closed and open again inside half a second.
##   wake  — the first shift: dark and unfocused, opening part way, resting
##           there, then finally seeing clearly.
##   sleep — the end of the last shift: the reverse, and it stays shut.

signal wake_finished
signal sleep_finished

@export var blink_interval_sec := 10.0
## A blink is blink_close_sec + blink_open_sec = half a second all told.
@export var blink_close_sec := 0.15
@export var blink_open_sec := 0.35
@export var wake_duration_sec := 3.0
@export var sleep_duration_sec := 3.0
## How dark and how smeared the half-open pause sits at.
@export var half_open_darkness := 0.45
@export var max_blur := 4.0

var _tween: Tween
var _blink_timer: Timer

@onready var eyelid: ColorRect = $Eyelid


func _ready() -> void:
	_blink_timer = Timer.new()
	_blink_timer.wait_time = blink_interval_sec
	_blink_timer.timeout.connect(_blink)
	add_child(_blink_timer)
	_apply(0.0, 0.0)


## Shift 1: the eyes open for the first time. Awaitable.
func play_wake() -> void:
	stop_blinking()
	_apply(1.0, max_blur)
	_kill_tween()
	_tween = create_tween()
	# Opening: most of the dark lifts quickly, but nothing is in focus yet.
	_tween.tween_method(_apply_blended.bind(1.0, max_blur, half_open_darkness, max_blur * 0.6),
		0.0, 1.0, wake_duration_sec * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# The pause at half-open: the room is there, but not yet readable.
	_tween.tween_interval(wake_duration_sec * 0.2)
	# Focusing: the rest of the dark and all of the blur come off.
	_tween.tween_method(_apply_blended.bind(half_open_darkness, max_blur * 0.6, 0.0, 0.0),
		0.0, 1.0, wake_duration_sec * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished
	start_blinking()
	wake_finished.emit()


## End of the last shift: the eyes close for good. Awaitable.
func play_sleep() -> void:
	stop_blinking()
	_kill_tween()
	_tween = create_tween()
	# Sinking: the lids get heavy and the desk goes soft.
	_tween.tween_method(_apply_blended.bind(0.0, 0.0, half_open_darkness, max_blur * 0.6),
		0.0, 1.0, sleep_duration_sec * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_interval(sleep_duration_sec * 0.15)
	# Shutting.
	_tween.tween_method(_apply_blended.bind(half_open_darkness, max_blur * 0.6, 1.0, max_blur),
		0.0, 1.0, sleep_duration_sec * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _tween.finished
	sleep_finished.emit()


## Lifts whatever darkness is on screen, for fading a new screen in from
## black after play_sleep(). Awaitable.
func reveal(duration_sec := 1.5) -> void:
	stop_blinking()
	_kill_tween()
	_tween = create_tween()
	_tween.tween_method(_apply_blended.bind(1.0, max_blur, 0.0, 0.0),
		0.0, 1.0, duration_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _tween.finished


func start_blinking() -> void:
	_blink_timer.wait_time = blink_interval_sec
	_blink_timer.start()


func stop_blinking() -> void:
	_blink_timer.stop()


## Clears the eyelid entirely — used when leaving the shift scene.
func clear() -> void:
	stop_blinking()
	_kill_tween()
	_apply(0.0, 0.0)


func _blink() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_method(_apply_darkness, 0.0, 1.0, blink_close_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_method(_apply_darkness, 1.0, 0.0, blink_open_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _apply_darkness(darkness: float) -> void:
	_apply(darkness, 0.0)


## tween_method drives t from 0 to 1; the four bound values are where the
## darkness and blur start and end.
func _apply_blended(t: float, from_darkness: float, from_blur: float, to_darkness: float, to_blur: float) -> void:
	_apply(lerpf(from_darkness, to_darkness, t), lerpf(from_blur, to_blur, t))


func _apply(darkness: float, blur: float) -> void:
	var shader_material := eyelid.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("darkness", darkness)
	shader_material.set_shader_parameter("blur", blur)
	# A perfectly clear eye has nothing to draw, so the overlay steps aside.
	eyelid.visible = darkness > 0.001 or blur > 0.001


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
