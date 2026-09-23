class_name FilingTray
extends Area2D

## One of the three fixed trays (Public Archive / Department of Truth /
## Incinerator). Per the storyboard: "Target brightens faintly — the only
## feedback before a decision is final. No confirm dialog, because a confirm
## is a second chance." So this node does exactly two things: brighten while
## a held file overlaps it, and accept the file the instant it's dropped
## while overlapping. No are-you-sure step anywhere.

## ANY is not a physical tray and is never spawned on the desk. It exists so
## a CaseData can say "this document has no right drawer": whichever tray the
## player picks, the filing changes neither Accuracy nor Paranoia.
enum TrayType { PUBLIC_ARCHIVE, DEPARTMENT_OF_TRUTH, INCINERATOR, ANY }

## The trays that actually appear on the desk, in order, top to bottom.
const SPAWNED_TRAY_TYPES: Array[int] = [
	TrayType.PUBLIC_ARCHIVE, TrayType.DEPARTMENT_OF_TRUTH, TrayType.INCINERATOR
]


## True for a case whose tray choice carries no consequence.
static func is_wildcard(tray_type: int) -> bool:
	return tray_type == TrayType.ANY

@export var tray_type: TrayType = TrayType.PUBLIC_ARCHIVE
@export var brighten_color: Color = Color(1.25, 1.22, 1.1)
@export var brighten_speed: float = 8.0

@onready var visual: CanvasItem = $Visual
@onready var label: Label = $Label

## Set by the held FileEntity: true only for the one tray the player is
## actually pointing at, never for every tray the tall paper happens to touch.
var _hovered: bool = false


func _ready() -> void:
	label.text = _display_name()
	monitoring = true
	monitorable = true


func _on_area_entered(area: Area2D) -> void:
	if area is FileEntity and area.is_held():
		if _hover_count == 0:
			SFX.play(&"tray_hover")
		_hover_count += 1


func _on_area_exited(area: Area2D) -> void:
	if area is FileEntity:
		_hover_count = maxi(0, _hover_count - 1)
func set_hovered(value: bool) -> void:
	_hovered = value


func _process(delta: float) -> void:
	var target: Color = brighten_color if _hovered else Color.WHITE
	visual.modulate = visual.modulate.lerp(target, brighten_speed * delta)


## Called by FileEntity when it drops while overlapping this tray.
func notify_received(_file: FileEntity) -> void:
	_hovered = false


func _display_name() -> String:
	match tray_type:
		TrayType.PUBLIC_ARCHIVE:
			return "Public Archive"
		TrayType.DEPARTMENT_OF_TRUTH:
			return "Department\nof Truth"
		TrayType.INCINERATOR:
			return "Incinerator"
		TrayType.ANY:
			return "Any Tray"
	return "Unknown Tray"
