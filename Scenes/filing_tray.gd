@tool
class_name FilingTray
extends Area2D

## One of the three fixed trays (Public Archive / Department of Truth /
## Incinerator) — on the desk these are the three drawers of the filing
## cabinet on the right, top to bottom. Per the storyboard: "Target brightens
## faintly — the only feedback before a decision is final. No confirm dialog,
## because a confirm is a second chance." So this node does exactly two
## things: brighten while a held file is pointed at it, and accept the file
## the instant it's dropped there. No are-you-sure step anywhere.
##
## There is no box drawn any more: the drawer IS the cabinet art. The touch
## area is drawer_polygon, traced over the drawer front in the desk art's
## pixels (the Desk node scales it to the screen), and the only visual is a
## faint additive glow in that same shape while a file hovers it.

## ANY is not a physical tray and is never spawned on the desk. It exists so
## a CaseData can say "this document has no right drawer": whichever tray the
## player picks, the filing changes neither Accuracy nor Paranoia.
enum TrayType { PUBLIC_ARCHIVE, DEPARTMENT_OF_TRUTH, INCINERATOR, ANY }

## The trays that actually appear on the desk, in order, top to bottom.
const SPAWNED_TRAY_TYPES: Array[int] = [
	TrayType.PUBLIC_ARCHIVE, TrayType.DEPARTMENT_OF_TRUTH, TrayType.INCINERATOR
]

## Every tray on the desk is in this group, so a held file can find them.
const GROUP := &"filing_trays"


## True for a case whose tray choice carries no consequence.
static func is_wildcard(tray_type: int) -> bool:
	return tray_type == TrayType.ANY

@export var tray_type: TrayType = TrayType.PUBLIC_ARCHIVE
## The drawer front, relative to this node. Edit the points in the Inspector;
## the glow previews the shape in the editor so it can be lined up with the art.
@export var drawer_polygon := PackedVector2Array():
	set(value):
		drawer_polygon = value
		_apply_polygon()
@export var brighten_speed: float = 8.0

@onready var visual: Polygon2D = $Visual
@onready var collision: CollisionPolygon2D = $CollisionPolygon2D

## Set by the held FileEntity: true only for the drawer the player is
## actually pointing at.
var _hovered: bool = false


func _ready() -> void:
	_apply_polygon()
	if Engine.is_editor_hint():
		visual.modulate.a = 1.0
		return
	add_to_group(GROUP)
	visual.modulate.a = 0.0
	monitoring = true
	monitorable = true


## True if this global/viewport point is on the drawer front.
func contains_point(global_point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(global_point), drawer_polygon)


## Called by the held FileEntity. The sound fires on the rising edge only,
## so sweeping the paper past a drawer chirps once rather than every frame.
func set_hovered(value: bool) -> void:
	if value == _hovered:
		return
	_hovered = value
	if _hovered:
		SFX.play(&"tray_hover")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target := 1.0 if _hovered else 0.0
	visual.modulate.a = lerpf(visual.modulate.a, target, clampf(brighten_speed * delta, 0.0, 1.0))


## Called by FileEntity when it drops on this drawer.
func notify_received(_file: FileEntity) -> void:
	_hovered = false


func _apply_polygon() -> void:
	if not is_node_ready():
		return
	visual.polygon = drawer_polygon
	collision.polygon = drawer_polygon


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
