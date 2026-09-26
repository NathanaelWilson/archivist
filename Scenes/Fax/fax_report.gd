class_name FaxReport
extends CanvasLayer

## The report taken out of the fax: one sheet of fax paper over the blurred
## desk, saying how the last case was sorted and redacted, with the
## Department's remark (a SlipDeck line) at the bottom. Tap anywhere to put it
## down.

signal closed

@onready var case_label: Label = $Root/Center/Paper/Margin/Content/Case
@onready var sort_label: Label = $Root/Center/Paper/Margin/Content/Sort
@onready var redaction_label: Label = $Root/Center/Paper/Margin/Content/Redaction
@onready var remark_label: Label = $Root/Center/Paper/Margin/Content/Remark

var _can_close := false


func _ready() -> void:
	visible = false


## report keys: case_id, tray_name, sort_ok, redaction_text, remark.
func show_report(report: Dictionary) -> void:
	case_label.text = "%s          DESK 14" % report.get("case_id", "CASE")
	sort_label.text = "SORTED TO   %s\nSORTING     %s" % [
		report.get("tray_name", "—"),
		"ACCEPTED" if report.get("sort_ok", false) else "REJECTED",
	]
	redaction_label.text = "REDACTION   %s" % report.get("redaction_text", "—")
	remark_label.text = "\"%s\"" % report.get("remark", "")
	visible = true
	SFX.play(&"page_flip")
	# A short beat before a tap can close it, so the tap that opened it
	# (released a moment later) does not put it straight back down.
	_can_close = false
	await get_tree().create_timer(0.3).timeout
	_can_close = true


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var release: Variant = PointerInput.release_position(event)
	if PointerInput.press_position(event) != null or release != null:
		get_viewport().set_input_as_handled()
	if release != null and _can_close:
		visible = false
		closed.emit()
