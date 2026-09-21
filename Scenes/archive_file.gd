## Data for one document in the archive.
##
## Anomaly regions are expressed in normalized document coordinates (0.0 to 1.0).
## This makes a case reusable if its art is resized.  Keep the regions simple for
## this project: rectangles are quick to author in the Inspector and easy to tune.
class_name ArchiveFile
extends Resource

@export_category("Document")
@export var case_id: String
@export var title: String
@export var document_texture: Texture2D

@export_category("Required redactions")
## Rectangles in normalized document coordinates: x, y, width, height.
@export var anomaly_regions: Array[Rect2] = []
## Each anomaly must be covered by at least this much ink.
@export_range(0.0, 1.0, 0.01) var required_coverage: float = 0.95
## Ink outside all anomaly regions is allowed up to this fraction of total ink.
## Set this to 1.0 if a case should not penalize broad redaction.
@export_range(0.0, 1.0, 0.01) var maximum_overspill := 0.15


func get_pixel_regions(image_size: Vector2i) -> Array[Rect2i]:
	var pixel_regions: Array[Rect2i] = []
	var bounds := Rect2i(Vector2i.ZERO, image_size)
	for normalized_region in anomaly_regions:
		var region := Rect2i(
			floori(normalized_region.position.x * image_size.x),
			floori(normalized_region.position.y * image_size.y),
			ceili(normalized_region.size.x * image_size.x),
			ceili(normalized_region.size.y * image_size.y)
		).intersection(bounds)
		if region.has_area():
			pixel_regions.append(region)
	return pixel_regions
