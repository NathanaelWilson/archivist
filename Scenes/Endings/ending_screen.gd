class_name EndingScreen
extends CanvasLayer

## Shared behaviour for the four Record-of-Outcomes ending screens — one
## scene per ending (ending_loyalist / ending_liability / ending_paranoid /
## ending_zealot.tscn). Each scene only sets its `ending_id`; Main picks which
## scene to instantiate from GameScore.evaluate_ending() and calls present().
##
## The ending itself is the notice art in Assets/Endings/. Each scene sets it
## on its Notice node, so the art is visible in the editor while the marks
## over it (blood, redaction bars) are placed. If a scene is left without one,
## it is found by name instead — each file is named after its ending
## (Loyalist.png, Liability.png, Paranoid.png, Zealot.png).

signal clocked_out

const NOTICE_PATH_FORMAT := "res://Assets/Endings/%s.png"

@export var ending_id: StringName = &""

@onready var notice: TextureRect = $Overlay/Center/Content/Notice
@onready var clock_out_button: Button = $Overlay/Center/Content/ClockOutButton


func _ready() -> void:
	visible = false
	clock_out_button.pressed.connect(func():
		SFX.play(&"clock_out")
		clocked_out.emit()
	)
	if notice.texture == null:
		notice.texture = _load_notice()


func present() -> void:
	visible = true
	Music.play(StringName("ending_%s" % ending_id)) # e.g. ending_zealot
	# Per-ending stinger (ending_<id>) if it exists, otherwise the shared one.
	if not SFX.play(StringName("ending_%s" % ending_id)):
		SFX.play(&"ending_reveal")


## "loyalist" -> res://Assets/Endings/Loyalist.png
func _load_notice() -> Texture2D:
	var path := NOTICE_PATH_FORMAT % String(ending_id).capitalize()
	if not ResourceLoader.exists(path):
		push_warning("EndingScreen: no notice art for '%s' at %s." % [ending_id, path])
		return null
	return load(path) as Texture2D
