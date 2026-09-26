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

var _pending: Array[Dictionary] = []
var _blink_left := 0.0


func _ready() -> void:
	super()
	tapped.connect(_deliver)


## A new report has come through: blink, then show it.
func receive(report: Dictionary) -> void:
	_pending.append(report)
	attention = true
	_blink_left = auto_show_delay
	SFX.play(&"printer")


func has_report() -> bool:
	return not _pending.is_empty()


func _process(delta: float) -> void:
	super(delta)
	if _pending.is_empty():
		return
	_blink_left -= delta
	# is_available() is false while the desk is busy, so the report waits.
	if _blink_left <= 0.0 and is_available():
		_deliver()


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
