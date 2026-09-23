class_name ShiftScreen
extends CanvasLayer

signal begin_requested

@onready var title_label: Label = $Overlay/Center/Panel/Margin/Content/Title
@onready var begin_button: Button = $Overlay/Center/Panel/Margin/Content/BeginButton


func _ready() -> void:
	begin_button.pressed.connect(func():
		SFX.play(&"shift_begin")
		begin_requested.emit()
	)
	visible = false


func present_shift(shift_data: ShiftData, shift_number: int, shift_total: int) -> void:
	title_label.text = "SHIFT %d" % shift_number
	begin_button.text = "BEGIN SHIFT"
	begin_button.visible = true
	visible = true


func present_complete() -> void:
	title_label.text = "SHIFT COMPLETE"
	begin_button.visible = false
	visible = true


func dismiss() -> void:
	visible = false
