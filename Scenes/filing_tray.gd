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
## A light tick in the hand when a held file moves over this tray, so the
## player can feel which drawer they are on without looking. Kept short and
## weak on purpose — a hint, not a buzz.
@export var hover_haptic_ms: int = 18
@export_range(0.0, 1.0, 0.05) var hover_haptic_strength: float = 0.25

@onready var visual: CanvasItem = $Visual
@onready var label: Label = $Label

## Set by the held FileEntity: true only for the one tray the player is
## actually pointing at, never for every tray the tall paper happens to touch.
var _hovered: bool = false


func _ready() -> void:
	label.text = _display_name()
	monitoring = true
	monitorable = true


## Called by the held FileEntity. The sound fires on the rising edge only,
## so sweeping the paper past a tray chirps once rather than every frame.
func set_hovered(value: bool) -> void:
	if value == _hovered:
		return
	_hovered = value
	if _hovered:
		SFX.play(&"tray_hover")
		# Phones only; a desktop debug session has nothing to vibrate.
		Input.vibrate_handheld(hover_haptic_ms, hover_haptic_strength)


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
