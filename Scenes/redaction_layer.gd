class_name RedactionLayer
extends Sprite2D

## Permanent ink and validation for one CaseData document. FileEntity owns
## gesture recognition and calls begin_stroke/stroke_to/end_stroke.

const IMG_SIZE := Vector2i(171, 342)
const REDACT_COLOR := Color.BLACK
## A broad, horizontal chisel tip: closer to a Stabilo marker than a square
## pixel stamp. The soft edge is only visual; the opaque centre is scored.
const MARKER_SIZE := Vector2i(12, 6)
const MARKER_CORNER_RADIUS := 2.0
const DEBUG_TARGET_RED := Color(1.0, 0.0, 0.0, 0.38)
const DEBUG_TARGET_YELLOW := Color(1.0, 0.85, 0.0, 0.45)
const DEBUG_TARGET_GREEN := Color(0.0, 1.0, 0.0, 0.38)
const DEBUG_SAFE_ZONE := Color(0.2, 0.55, 1.0, 0.22)
## Mask values: required anomaly pixels are white, safe-zone pixels grey.
const MASK_SAFE_ZONE := Color(0.5, 0.5, 0.5)

@export var show_debug_anomaly_regions := true

var case_data: CaseData
var ink_image: Image
var anomaly_mask: Image
var debug_image: Image
var _last_image_position := Vector2.ZERO

@onready var debug_overlay: Sprite2D = $"../DebugAnomalyOverlay"

signal redaction_evaluated(result: Dictionary)


func _ready() -> void:
	_create_canvases(IMG_SIZE)


## canvas_size is the document's on-screen size; DocumentViewer passes the
## size it fitted the case art to so ink, anomaly mask and art stay aligned.
## saved_ink restores ink the player already put on this document.
func set_case_data(new_case_data: CaseData, canvas_size: Vector2i = IMG_SIZE, saved_ink: Image = null) -> void:
	case_data = new_case_data
	_create_canvases(canvas_size)
	if saved_ink != null and not saved_ink.is_empty() and saved_ink.get_format() == Image.FORMAT_RGBA8:
		# duplicate() is typed Resource, so the cast is needed to assign it.
		ink_image = saved_ink.duplicate() as Image
		if ink_image.get_size() != canvas_size:
			ink_image.resize(canvas_size.x, canvas_size.y, Image.INTERPOLATE_NEAREST)
		(texture as ImageTexture).set_image(ink_image)
		evaluate_redaction() # refresh the debug colour for the restored ink


## A copy of the current ink, for the document to keep while it is closed.
func get_ink_image() -> Image:
	if ink_image == null:
		return null
	return ink_image.duplicate() as Image


func clear_ink() -> void:
	_create_canvases(ink_image.get_size())


func begin_stroke(screen_position: Vector2) -> void:
	_last_image_position = _to_image_position(screen_position)
	_stamp(_last_image_position)
	(texture as ImageTexture).update(ink_image)


func stroke_to(screen_position: Vector2) -> void:
	var target := _to_image_position(screen_position)
	var distance := _last_image_position.distance_to(target)
	for step in ceili(distance):
		_stamp(_last_image_position.lerp(target, float(step) / maxf(distance, 1.0)))
	_last_image_position = target
	(texture as ImageTexture).update(ink_image)


func end_stroke() -> Dictionary:
	return evaluate_redaction()


func evaluate_redaction() -> Dictionary:
	if case_data == null:
		return {"is_valid": false, "reason": "No case data is assigned."}
	# A Public Archive case (and any case with no anomaly authored) must be
	# filed exactly as it arrived: any ink at all fails it.
	if not case_data.requires_redaction() or case_data.anomaly_regions.is_empty():
		var clean_ink_pixels := 0
		for y in ink_image.get_height():
			for x in ink_image.get_width():
				if ink_image.get_pixel(x, y).a > 0.5:
					clean_ink_pixels += 1
		var clean_result := {
			"is_valid": clean_ink_pixels == 0,
			"reason": "OK" if clean_ink_pixels == 0 else "This document needs no redaction — remove the ink.",
			"coverage": 1.0,
			"overspill": 0.0 if clean_ink_pixels == 0 else 1.0,
			"required_pixels": 0,
			"covered_pixels": 0,
		}
		redaction_evaluated.emit(clean_result)
		return clean_result

	var required_pixels := 0
	var covered_pixels := 0
	var ink_pixels := 0
	var ink_outside_anomaly := 0
	for y in ink_image.get_height():
		for x in ink_image.get_width():
			var inked := ink_image.get_pixel(x, y).a > 0.5
			var mask_value := anomaly_mask.get_pixel(x, y).r
			var required := mask_value > 0.75
			var allowed := mask_value > 0.25 # anomaly or a safe zone
			if required:
				required_pixels += 1
				if inked:
					covered_pixels += 1
			if inked:
				ink_pixels += 1
				if not allowed:
					ink_outside_anomaly += 1

	var coverage: float = float(covered_pixels) / float(maxi(required_pixels, 1))
	var overspill: float = float(ink_outside_anomaly) / float(maxi(ink_pixels, 1))
	var covered_enough: bool = coverage >= case_data.required_coverage
	var clean_enough: bool = overspill <= case_data.maximum_overspill
	var is_valid: bool = covered_enough and clean_enough
	var reason := "OK"
	if not covered_enough:
		reason = "Anomaly not covered enough (%.0f%% of %.0f%% needed)." % [coverage * 100.0, case_data.required_coverage * 100.0]
	elif not clean_enough:
		reason = "Too much ink outside the anomaly (%.0f%% of ink, max %.0f%%)." % [overspill * 100.0, case_data.maximum_overspill * 100.0]
	var result := {
		"is_valid": is_valid,
		"reason": reason,
		"coverage": coverage,
		"overspill": overspill,
		"required_pixels": required_pixels,
		"covered_pixels": covered_pixels,
	}
	# Debug colour mirrors the real verdict: green = valid, yellow = covered
	# but too much ink outside, red = anomaly not covered enough.
	_update_debug_overlay(covered_enough, clean_enough)
	redaction_evaluated.emit(result)
	return result


func _create_canvases(image_size: Vector2i) -> void:
	ink_image = Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	ink_image.fill(Color.TRANSPARENT)
	texture = ImageTexture.create_from_image(ink_image)
	anomaly_mask = Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_L8)
	anomaly_mask.fill(Color.BLACK)
	debug_image = Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	debug_image.fill(Color.TRANSPARENT)
	if case_data != null:
		var bounds := Rect2i(Vector2i.ZERO, image_size)
		var regions := case_data.get_pixel_regions(image_size)
		# Safe zones first, then the required areas on top of them.
		for region in case_data.get_overspill_pixel_regions(image_size):
			anomaly_mask.fill_rect(region.intersection(bounds), MASK_SAFE_ZONE)
		for region in regions:
			anomaly_mask.fill_rect(region, Color.WHITE)
	_update_debug_overlay(false, true)


func _stamp(image_position: Vector2) -> void:
	var pixel := Vector2i(roundi(image_position.x), roundi(image_position.y))
	var bounds := Rect2i(Vector2i.ZERO, ink_image.get_size())
	var half_size := MARKER_SIZE / 2
	var stamp := Rect2i(pixel - half_size, MARKER_SIZE).intersection(bounds)
	var inner_half_size := Vector2(MARKER_SIZE) * 0.5 - Vector2.ONE * MARKER_CORNER_RADIUS
	for y in range(stamp.position.y, stamp.end.y):
		for x in range(stamp.position.x, stamp.end.x):
			var point := Vector2(x - pixel.x, y - pixel.y).abs()
			var corner_distance := Vector2(
				maxf(point.x - inner_half_size.x, 0.0),
				maxf(point.y - inner_half_size.y, 0.0)
			).length()
			var alpha := clampf(MARKER_CORNER_RADIUS + 0.5 - corner_distance, 0.0, 1.0)
			if alpha > 0.0:
				var existing_alpha := ink_image.get_pixel(x, y).a
				ink_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, maxf(existing_alpha, alpha)))


func _update_debug_overlay(covered: bool, clean: bool) -> void:
	if not is_instance_valid(debug_overlay):
		return
	debug_overlay.visible = show_debug_anomaly_regions and case_data != null
	if not debug_overlay.visible:
		return
	debug_image.fill(Color.TRANSPARENT)
	var color := DEBUG_TARGET_RED
	if covered:
		color = DEBUG_TARGET_GREEN if clean else DEBUG_TARGET_YELLOW
	for region in case_data.get_overspill_pixel_regions(ink_image.get_size()):
		debug_image.fill_rect(region, DEBUG_SAFE_ZONE)
	for region in case_data.get_pixel_regions(ink_image.get_size()):
		debug_image.fill_rect(region, color)
	debug_overlay.texture = ImageTexture.create_from_image(debug_image)


func _to_image_position(screen_position: Vector2) -> Vector2:
	return to_local(screen_position) - offset + get_rect().size * 0.5
