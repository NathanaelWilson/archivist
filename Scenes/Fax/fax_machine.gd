class_name FaxMachine
extends DeskProp

## The fax machine on the desk. After every filing the Department faxes back
## a report on it — how the case was sorted and how it was redacted. The
## machine blinks (the desk-prop outline, on and off) for a moment while the
## report comes through, then Main shows it on the FaxReport sheet on its own.
##
## If the desk is busy when the blink ends (a document or the rules are open,
## the eyes are closing), the machine keeps blinking and hands the report over
## as soon as the desk is free. Tapping it while it blinks takes the report
## out early.

signal report_requested(report: Dictionary)

## How long the fax blinks before the report is shown by itself.
@export var auto_show_delay := 0.8
## While a report prints, the machine rattles: its art jitters by up to this
## many *screen* pixels, shake_rate times a second, for shake_sec seconds.
@export var shake_px := 1.6
@export var shake_rate := 28.0
@export var shake_sec := 0.9

var _pending: Array[Dictionary] = []
var _blink_left := 0.0
var _shake_left := 0.0
var _shake_tick := 0.0


func _ready() -> void:
	super()
	tapped.connect(_deliver)


## A new report has come through: blink, then show it.
func receive(report: Dictionary) -> void:
	_pending.append(report)
	attention = true
	_blink_left = auto_show_delay
	_shake_left = shake_sec
	SFX.play(&"printer")


func has_report() -> bool:
	return not _pending.is_empty()


func _process(delta: float) -> void:
	super(delta)
	_update_shake(delta)
	if _pending.is_empty():
		return
	_blink_left -= delta
	# is_available() is false while the desk is busy, so the report waits.
	if _blink_left <= 0.0 and is_available():
		_deliver()


## Jitters the art (Sprite2D offset, so the node itself never moves and the
## desk layout is untouched). The desk is drawn scaled down, so the screen
## amplitude is converted into the sprite's own pixels.
func _update_shake(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta
	if _shake_left <= 0.0:
		offset = Vector2.ZERO
		return
	_shake_tick -= delta
	if _shake_tick > 0.0:
		return
	_shake_tick = 1.0 / shake_rate
	var to_local_px := 1.0 / maxf(absf(global_scale.x), 0.001)
	# Eases off over the last third so it settles instead of stopping dead.
	var strength := clampf(_shake_left / (shake_sec / 3.0), 0.0, 1.0)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * shake_px * to_local_px * strength


## Nothing to take out of an empty fax.
func _accepts_input() -> bool:
	return has_report()


## Hands over the newest report; older unread ones are dropped.
func _deliver() -> void:
	if _pending.is_empty():
		return
	var newest: Dictionary = _pending.back()
	_pending.clear()
	attention = false
	report_requested.emit(newest)
