class_name FilingTray
extends Area2D

## One of the three fixed trays (Public Archive / Department of Truth /
## Incinerator) — the three drawers of the filing cabinet, top to bottom. Per
## the storyboard: "Target brightens faintly — the only feedback before a
## decision is final. No confirm dialog, because a confirm is a second
## chance." The feedback is now the drawer itself sliding open (FilingCabinet
## swaps the art); this node only knows its shape and accepts the file the
## instant it's dropped there. No are-you-sure step anywhere.
##
## The touch area is two Polygon2D children, drawn in the cabinet PNG's own
## pixels (this node sits at the cabinet's top-left corner):
##   ClosedArea — the drawer front while the drawer is shut;
##   OpenArea   — the whole pulled-out drawer while its "open" art is shown,
##                so the pointer doesn't fall off a drawer that just slid out
##                from under it.
## Both are visible in the editor (open desk.tscn) and hidden in game unless
## debug_show_areas is on. Drag their points in the 2D editor to reshape them.

## Fired when a held file starts or stops pointing at this drawer.
signal hover_changed(tray: FilingTray, hovered: bool)

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


## The drawer under a point, or null. A drawer that is already open is tested
## first, with its bigger open shape, so a drawer that has just slid out over
## its neighbour stays the one being pointed at.
static func tray_at(tree: SceneTree, global_point: Vector2) -> FilingTray:
	var trays := tree.get_nodes_in_group(GROUP)
	for node in trays:
		var tray := node as FilingTray
		if tray != null and tray.is_open() and tray.contains_point(global_point):
			return tray
	for node in trays:
		var tray := node as FilingTray
		if tray != null and not tray.is_open() and tray.contains_point(global_point):
			return tray
	return null


@export var tray_type: TrayType = TrayType.PUBLIC_ARCHIVE
## Shows the live touch area while playing (the shut shape, or the open
## shape while this drawer is out). Desk.debug_show_drawer_areas sets it on
## all three at once.
@export var debug_show_areas := false:
	set(value):
		debug_show_areas = value
		_update_debug_visuals()

@onready var closed_area: Polygon2D = $ClosedArea
@onready var open_area: Polygon2D = $OpenArea
@onready var collision: CollisionPolygon2D = $CollisionPolygon2D

## Set by the Desk: returns true where something drawn in front of the
## cabinet (the desk top) covers the point, so a drop there never counts.
var is_occluded: Callable = Callable()

var _hovered := false
var _open := false


func _ready() -> void:
	add_to_group(GROUP)
	monitoring = true
	monitorable = true
	_sync_collision()
	_update_debug_visuals()


func is_open() -> bool:
	return _open


func is_hovered() -> bool:
	return _hovered


## Called by FilingCabinet when its art shows this drawer pulled out.
func set_open(value: bool) -> void:
	if value == _open:
		return
	_open = value
	_sync_collision()
	_update_debug_visuals()


## True if this global/viewport point is on the drawer as currently drawn.
func contains_point(global_point: Vector2) -> bool:
	if is_occluded.is_valid() and bool(is_occluded.call(global_point)):
		return false
	var area := _active_area()
	return Geometry2D.is_point_in_polygon(area.to_local(global_point), area.polygon)


## Where a filed paper flies to: the middle of the shut drawer front.
func get_drop_point() -> Vector2:
	var points := closed_area.polygon
	if points.is_empty():
		return global_position
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return closed_area.to_global(sum / points.size())


## Called by the held FileEntity. The sound fires on the rising edge only,
## so sweeping the paper past a drawer chirps once rather than every frame.
func set_hovered(value: bool) -> void:
	if value == _hovered:
		return
	_hovered = value
	if _hovered:
		SFX.play(&"tray_hover")
	hover_changed.emit(self, _hovered)


## Called by FileEntity when it drops on this drawer.
func notify_received(_file: FileEntity) -> void:
	set_hovered(false)


func _active_area() -> Polygon2D:
	if _open and open_area.polygon.size() >= 3:
		return open_area
	return closed_area


## Keeps the CollisionPolygon2D matching the live shape, so Godot's
## Debug > Visible Collision Shapes shows exactly what counts right now.
func _sync_collision() -> void:
	if not is_node_ready():
		return
	var area := _active_area()
	collision.polygon = area.transform * area.polygon


func _update_debug_visuals() -> void:
	if not is_node_ready():
		return
	var open_shown := _open and open_area.polygon.size() >= 3
	closed_area.visible = debug_show_areas and not open_shown
	open_area.visible = debug_show_areas and open_shown


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
