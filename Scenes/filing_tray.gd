class_name FilingTray
extends Area2D

## One of the three fixed trays (Public Archive / Department of Truth /
## Incinerator). Per the storyboard: "Target brightens faintly — the only
## feedback before a decision is final. No confirm dialog, because a confirm
## is a second chance." So this node does exactly two things: brighten while
## a held file overlaps it, and accept the file the instant it's dropped
## while overlapping. No are-you-sure step anywhere.

enum TrayType { PUBLIC_ARCHIVE, DEPARTMENT_OF_TRUTH, INCINERATOR }

@export var tray_type: TrayType = TrayType.PUBLIC_ARCHIVE
@export var brighten_color: Color = Color(1.25, 1.22, 1.1)
@export var brighten_speed: float = 8.0

@onready var visual: CanvasItem = $Visual

var _hover_count: int = 0


func _ready() -> void:
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	if area is FileEntity and area.is_held():
		_hover_count += 1


func _on_area_exited(area: Area2D) -> void:
	if area is FileEntity:
		_hover_count = maxi(0, _hover_count - 1)


func _process(delta: float) -> void:
	var target: Color = brighten_color if _hover_count > 0 else Color.WHITE
	visual.modulate = visual.modulate.lerp(target, brighten_speed * delta)


## Called by FileEntity when it drops while overlapping this tray.
func notify_received(_file: FileEntity) -> void:
	_hover_count = 0
