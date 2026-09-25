class_name ShiftScreen
extends CanvasLayer

signal begin_requested

## "BEGIN SHIFT" breathes in and out so it reads as something to tap.
@export var pulse_min_alpha := 0.25
@export var pulse_half_sec := 0.9

var _pulse: Tween

@onready var title_label: Label = $Overlay/Center/Panel/Margin/Content/Title
@onready var begin_button: Button = $Overlay/Center/Panel/Margin/Content/BeginButton
## The whole block around "SHIFT N" + "BEGIN SHIFT" is the tap target; the
## button itself is only the visual cue (its mouse_filter is Ignore).
@onready var tap_area: Control = $Overlay/Center/Panel


func _ready() -> void:
	tap_area.gui_input.connect(_on_tap_area_input)
	# Hovering the area holds the cue fully lit (desktop); a tap goes straight through.
	tap_area.mouse_entered.connect(func():
		_stop_pulse()
		begin_button.modulate.a = 1.0
	)
	tap_area.mouse_exited.connect(func():
		if begin_button.visible:
			_start_pulse()
	)
	visible = false


func present_shift(shift_data: ShiftData, shift_number: int, shift_total: int) -> void:
	title_label.text = "SHIFT %d" % shift_number
	begin_button.text = "BEGIN SHIFT"
	begin_button.visible = true
	visible = true
	_start_pulse()


func present_complete() -> void:
	title_label.text = "SHIFT COMPLETE"
	begin_button.visible = false
	_stop_pulse()
	visible = true


## Phone taps arrive as emulated mouse clicks, so this one check covers both.
func _on_tap_area_input(event: InputEvent) -> void:
	if not visible or not begin_button.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tap_area.accept_event()
		SFX.play(&"shift_begin")
		begin_requested.emit()


func dismiss() -> void:
	_stop_pulse()
	visible = false


func _start_pulse() -> void:
	_stop_pulse()
	begin_button.modulate.a = 1.0
	_pulse = create_tween().set_loops()
	_pulse.tween_property(begin_button, "modulate:a", pulse_min_alpha, pulse_half_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(begin_button, "modulate:a", 1.0, pulse_half_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
