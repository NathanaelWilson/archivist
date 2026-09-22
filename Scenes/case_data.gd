class_name CaseData
extends Resource

## The data shape a "case" is, per DES-01 in the Task Board. Everything the
## desk needs to spawn, render, ink-check and file a document lives here —
## nothing downstream (FileEntity, the tray, the scorer) should need to
## special-case a specific case by id.

enum DocType { PORTRAIT, FORM, RECORD_SHEET }
enum Level { CLEAN, WRONG } ## CLEAN = correct as-is; WRONG = has an anomaly to cover

@export var id: String = ""
@export var doc_type: DocType = DocType.PORTRAIT
@export var level: Level = Level.WRONG
@export var correct_tray: FilingTray.TrayType = FilingTray.TrayType.PUBLIC_ARCHIVE

## Rectangles normalized to the document (x/y/width/height from 0.0 to 1.0).
## They stay aligned if source art changes size.
@export var anomaly_regions: Array[Rect2] = []
## "Safe zones" around the anomaly, normalized like anomaly_regions. Ink
## inside a safe zone never counts as overspill, however much there is.
@export var overspill_regions: Array[Rect2] = []
@export_range(0.0, 1.0, 0.01) var required_coverage: float = 0.95
## Share of the player's ink allowed outside the anomaly AND outside every
## safe zone. More than this fails the redaction.
@export_range(0.0, 1.0, 0.01) var maximum_overspill: float = 0.05

@export var asset: Texture2D
## Optional "settled" swap texture — the slide-in/settle dread beat.
@export var settle_asset: Texture2D

@export var slip_id: String = "" ## "" = draw from the general slip pool
@export var live_number_slot: String = "" ## e.g. "files_handled" for Case 10
@export var clipboard_board_id: String = "" ## which board should be showing


func get_pixel_regions(image_size: Vector2i) -> Array[Rect2i]:
	return _to_pixel_regions(anomaly_regions, image_size)


func get_overspill_pixel_regions(image_size: Vector2i) -> Array[Rect2i]:
	return _to_pixel_regions(overspill_regions, image_size)


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
