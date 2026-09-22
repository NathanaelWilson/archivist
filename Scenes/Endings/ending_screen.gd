class_name EndingScreen
extends CanvasLayer

## Shared behaviour for the four Record-of-Outcomes ending screens — one
## scene per ending (ending_loyalist / ending_liability / ending_paranoid /
## ending_zealot.tscn). Each scene sets its own `ending_id` and `body_text`
## in the Inspector; Main picks which scene to instantiate from
## GameScore.evaluate_ending() and calls present() on it.
##
## This is a placeholder presentation (title + one GDD line + a CLOCK OUT
## button) — the full notice art / body-horror beat from the GDD's "How all
## four are delivered" section isn't built yet.

signal clocked_out

@export var ending_id: StringName = &""
@export_multiline var body_text: String = ""

@onready var title_label: Label = $Overlay/Center/Panel/Margin/Content/Title
@onready var body_label: Label = $Overlay/Center/Panel/Margin/Content/Body
@onready var clock_out_button: Button = $Overlay/Center/Panel/Margin/Content/ClockOutButton


func _ready() -> void:
	visible = false
	clock_out_button.pressed.connect(func(): clocked_out.emit())
	title_label.text = GameScore.get_display_name(ending_id)
	body_label.text = body_text


func present() -> void:
	visible = true
