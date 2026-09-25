@tool
class_name RedactionBox
extends Area2D

## Editor-only authoring handle for one CaseData region. Select this Area2D in
## Godot's 2D editor, move it, or resize its RectangleShape2D; the normalized
## region is kept in sync with the linked CaseData resource.
##
## region_kind picks which list it edits:
##   ANOMALY   (red)  — what the player must cover.
##   SAFE_ZONE (blue) — where the player may overspill any amount.

enum RegionKind { ANOMALY, SAFE_ZONE }

@export var case_data: CaseData
@export var region_kind: RegionKind = RegionKind.ANOMALY:
	set(value):
		region_kind = value
		queue_redraw()
@export var region_index := 0
@export var document_size := Vector2(512, 1024)

@onready var collision: CollisionShape2D = $CollisionShape2D

## Godot does not know an external resource has changed when a tool script
## edits it, so moving a box would otherwise be lost on save. The write is
## debounced: the .tres is saved once the drag has settled, not every frame.
const SAVE_DELAY_SEC := 0.4

var _unsaved_changes := false
var _save_countdown := 0.0
var _last_position := Vector2.INF
var _last_shape_position := Vector2.INF
var _last_size := Vector2.INF


func _ready() -> void:
	if case_data != null and case_data.asset != null:
		document_size = case_data.asset.get_size()
	_load_from_case()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or collision == null:
		return
	var shape := collision.shape as RectangleShape2D
	if shape == null:
		return
	# Godot's rectangle resize handle moves the CollisionShape2D child as well
	# as changing its size (only the dragged edge moves), so the child's
	# offset has to be watched and included, not just this node's position.
	if position != _last_position or collision.position != _last_shape_position or shape.size != _last_size:
		_write_to_case()
		_remember_state(shape)
		queue_redraw()
		_unsaved_changes = true
		_save_countdown = SAVE_DELAY_SEC
	elif _unsaved_changes:
		_save_countdown -= _delta
		if _save_countdown <= 0.0:
			_save_case_to_disk()


## Writes the linked CaseData back to its .tres. Without this the regions live
## only in memory and vanish when the editor reloads.
func _save_case_to_disk() -> void:
	_unsaved_changes = false
	if case_data == null or case_data.resource_path.is_empty():
		return
	if not case_data.has_method("requires_redaction"):
		# A placeholder instance: the script is not loaded in tool mode, so
		# saving now would write back an incomplete resource.
		push_warning("RedactionBox: '%s' is not fully loaded, so the box was not saved. Reload the project and move the box again." % case_data.resource_path)
		return
	var error := ResourceSaver.save(case_data, case_data.resource_path)
	if error != OK:
		push_warning("RedactionBox: could not save %s (error %d)." % [case_data.resource_path, error])


## The box in document pixels (the parent's space), wherever the editor has
## put the CollisionShape2D inside this node.
func _document_rect() -> Rect2:
	var shape := collision.shape as RectangleShape2D
	var size := shape.size * collision.scale.abs()
	return Rect2(position + collision.position - size * 0.5, size)


func _remember_state(shape: RectangleShape2D) -> void:
	_last_position = position
	_last_shape_position = collision.position
	_last_size = shape.size


## Reads level as a plain property instead of calling
## CaseData.requires_redaction(): in the editor the linked resource can be a
## placeholder instance, which holds exported values but has no methods.
func _case_requires_redaction() -> bool:
	if case_data == null:
		return true
	return int(case_data.level) == int(CaseData.Level.WRONG)


## The CaseData list this box edits (returned by reference, so writes stick).
func _regions() -> Array[Rect2]:
	if region_kind == RegionKind.SAFE_ZONE:
		return case_data.overspill_regions
	return case_data.anomaly_regions


func _load_from_case() -> void:
	if case_data == null or region_index < 0 or region_index >= _regions().size():
		return
	var shape := collision.shape as RectangleShape2D
	if shape == null:
		push_warning("RedactionBox '%s' has no RectangleShape2D to author with." % name)
		return
	var region := _regions()[region_index]
	shape.size = region.size * document_size
	collision.position = Vector2.ZERO
	collision.scale = Vector2.ONE
	position = region.position * document_size + shape.size * 0.5
	_remember_state(shape)
	queue_redraw()


func _write_to_case() -> void:
	if case_data == null or document_size.x <= 0.0 or document_size.y <= 0.0:
		return
	if not _case_requires_redaction():
		return # Public Archive cases carry no regions
	if region_index < 0:
		return
	var regions := _regions()
	while regions.size() <= region_index:
		regions.append(Rect2(0.4, 0.4, 0.1, 0.1))
	var rect := _document_rect()
	regions[region_index] = Rect2(rect.position / document_size, rect.size / document_size)
	case_data.emit_changed()


func _draw() -> void:
	if collision == null:
		return
	var shape := collision.shape as RectangleShape2D
	if shape == null:
		return
	# Draw exactly where the collision shape is, in this node's local space.
	var size := shape.size * collision.scale.abs()
	var rect := Rect2(collision.position - size * 0.5, size)
	if case_data != null and not _case_requires_redaction():
		# CLEAN case: nothing to redact here, so the box is inert.
		draw_rect(rect, Color(0.5, 0.5, 0.5, 0.12), true)
		draw_rect(rect, Color(0.6, 0.6, 0.6, 0.8), false, 3.0)
	elif region_kind == RegionKind.SAFE_ZONE:
		draw_rect(rect, Color(0.2, 0.55, 1.0, 0.15), true)
		draw_rect(rect, Color(0.2, 0.55, 1.0, 1.0), false, 3.0)
	else:
		draw_rect(rect, Color(1.0, 0.08, 0.08, 0.25), true)
		draw_rect(rect, Color(1.0, 0.15, 0.15, 1.0), false, 3.0)
