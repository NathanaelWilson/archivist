class_name SlipPrinter
extends Node2D

## Placeholder fax output. The real machine (Build Guide 3.6) is a physical
## object with a whirr, a slip feeding out, and the old slip sliding off the
## desk edge. For now this just shows the slip's text on a Label, at the
## fax's eventual position. Swap the Label for the real art later.

@export var slip_visible_sec := 6.0

var _slip: Label
var _tween: Tween


func _ready() -> void:
	_slip = Label.new()
	_slip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slip.custom_minimum_size = Vector2(220, 60)
	_slip.position = Vector2(-110, -30)
	_slip.modulate.a = 0.0
	_slip.text = ""
	add_child(_slip)


## Shows one slip. Called by Main ~0.3 s after a filing. If a previous slip
## is still on screen it is replaced, standing in for "the old slip slides
## off the desk" until the fax art lands.
func print_slip(text: String) -> void:
	_slip.text = text
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_slip, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(slip_visible_sec)
	_tween.tween_property(_slip, "modulate:a", 0.0, 0.3)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
