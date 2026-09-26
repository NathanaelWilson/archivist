@tool
class_name CaseData
extends Resource

## The data shape a "case" is, per DES-01 in the Task Board. Everything the
## desk needs to spawn, render, ink-check and file a document lives here —
## nothing downstream (FileEntity, the tray, the scorer) should need to
## special-case a specific case by id.

enum DocType { PORTRAIT, FORM, RECORD_SHEET }
enum Level { CLEAN, WRONG } ## CLEAN = nothing to cover; WRONG = has an anomaly to cover

@export var id: String = ""
@export var doc_type: DocType = DocType.PORTRAIT
## CLEAN means there is nothing on this document to redact: the redaction
## fields below are hidden and ignored, and any ink is a mistake. WRONG means
## an anomaly must be covered. This is independent of the tray — a document
## with nothing to cover can still belong to the Department of Truth because
## the whole thing is false.
@export var level: Level = Level.WRONG:
	set(value):
		level = value
		notify_property_list_changed()
## Which tray this document belongs in, whatever its level.
@export var correct_tray: FilingTray.TrayType = FilingTray.TrayType.PUBLIC_ARCHIVE

## Rectangles normalized to the document (x/y/width/height from 0.0 to 1.0).
## They stay aligned if source art changes size.
@export var anomaly_regions: Array[Rect2] = []
## "Safe zones" around the anomaly, normalized like anomaly_regions. Ink
## inside a safe zone never counts as overspill, however much there is.
@export var overspill_regions: Array[Rect2] = []
@export_range(0.0, 1.0, 0.01) var required_coverage: float = 0.8
## Share of the player's ink allowed outside the anomaly AND outside every
## safe zone. More than this fails the redaction.
@export_range(0.0, 1.0, 0.01) var maximum_overspill: float = 0.1

## Two rules on the board cancel out on this document, on purpose (Case 11:
## a staff card — staff are not to be covered — whose photo has the smile
## that must be covered). Either reading holds up:
##   * covering the anomaly earns its Accuracy point; leaving it costs nothing,
##   * the right drawer earns its point whether or not it was covered,
##   * nothing done to this document adds Paranoia.
@export var cover_optional: bool = false

## The room lights flicker while this document is on the desk: once as it
## arrives, then again every so often until it is filed. Purely atmosphere.
@export var lights_flicker: bool = false
## Case 1: a "?" in the document viewer that shows how to redact, and an
## arrow from the closed envelope to its drawer until it is filed.
@export var show_tutorial: bool = false

## The marker bleeds on this document: after each stroke the ink keeps
## creeping into the paper and drips down the page. Purely visual — the bleed
## is never scored, so it cannot fail a redaction the player did correctly.
@export var ink_bleeds: bool = false

@export var asset: Texture2D
## Optional "settled" swap texture — the slide-in/settle dread beat.
@export var settle_asset: Texture2D

@export var slip_id: String = "" ## "" = draw from the general slip pool
@export var live_number_slot: String = "" ## e.g. "files_handled" for Case 10
@export var clipboard_board_id: String = "" ## which board should be showing


## False for CLEAN documents: nothing on them may be redacted.
func requires_redaction() -> bool:
	return level == Level.WRONG


func get_pixel_regions(image_size: Vector2i) -> Array[Rect2i]:
	if not requires_redaction():
		return []
	return _to_pixel_regions(anomaly_regions, image_size)


func get_overspill_pixel_regions(image_size: Vector2i) -> Array[Rect2i]:
	if not requires_redaction():
		return []
	return _to_pixel_regions(overspill_regions, image_size)


## Hides the redaction settings in the Inspector for CLEAN cases, so a
## document with nothing to cover cannot be given an anomaly by accident.
func _validate_property(property: Dictionary) -> void:
	const REDACTION_PROPERTIES := [
		"anomaly_regions", "overspill_regions", "required_coverage", "maximum_overspill"
	]
	if property.name in REDACTION_PROPERTIES and not requires_redaction():
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _to_pixel_regions(normalized_regions: Array[Rect2], image_size: Vector2i) -> Array[Rect2i]:
	var pixel_regions: Array[Rect2i] = []
	var bounds := Rect2i(Vector2i.ZERO, image_size)
	for normalized_region in normalized_regions:
		var region := Rect2i(
			floori(normalized_region.position.x * image_size.x),
			floori(normalized_region.position.y * image_size.y),
			ceili(normalized_region.size.x * image_size.x),
			ceili(normalized_region.size.y * image_size.y)
		).intersection(bounds)
		if region.has_area():
			pixel_regions.append(region)
	return pixel_regions
