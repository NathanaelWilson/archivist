class_name RedactionLayer
extends Sprite2D

## The permanent ink canvas for one File Entity's document.
##
## This no longer owns _input directly. FileEntity decides whether a touch
## is an ink stroke or a pickup-and-drag *before* anything reaches this node,
## then drives it through begin_stroke / stroke_to / end_stroke. That split
## is what lets "drag on the paper" mean two different things in the GDD
## (COVER vs FILE) without the two gestures fighting each other.

const IMG_SIZE: Vector2i = Vector2i(512, 1024)
const REDACT_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)
const REDACT_RADIUS: int = 5

## Anomaly regions for the current case, in image-local pixel space.
## Set by FileEntity from CaseData before the player can touch the file.
var hidden_boxes: Array[Rect2] = []

var img: Image
var _last_img_pos: Vector2 = Vector2.ZERO
var _stroke_touched_box: bool = false
var _stroke_touched_clean: bool = false


func _ready() -> void:
	# Transparent canvas: only what the player inks should ever be opaque.
	img = Image.create_empty(IMG_SIZE.x, IMG_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	texture = ImageTexture.create_from_image(img)


## Call once when a touch resolves to "ink", at the point the drag started.
func begin_stroke(screen_pos: Vector2) -> void:
	_stroke_touched_box = false
	_stroke_touched_clean = false
	_last_img_pos = _to_image_pos(screen_pos)
	_stamp(_last_img_pos)
	texture.update(img)


## Call on every following move while the stroke is live.
func stroke_to(screen_pos: Vector2, relative: Vector2) -> void:
	var target := _to_image_pos(screen_pos)
	if relative.length_squared() > 0.0:
		# Walk pixel-by-pixel so a fast flick doesn't leave gaps in the ink.
		var steps := ceili(relative.length())
		var p := _last_img_pos
		for i in steps:
			p = p.move_toward(target, 1.0)
			_stamp(p)
	_last_img_pos = target
	texture.update(img)


## Call once when the touch is released. Returns what this single stroke
## scored, for FileEntity to forward to the session's Accuracy/Paranoia
## counters (see DEV-05 — not implemented here on purpose; this node only
## reports facts about ink, it never decides what they mean).
func end_stroke() -> Dictionary:
	return {
		"touched_hidden_box": _stroke_touched_box,
		# "Landed wholly on clean paper" per the GDD's Paranoia rule.
		"landed_only_on_clean": _stroke_touched_clean and not _stroke_touched_box,
	}


func _stamp(pos: Vector2) -> void:
	var pixel_rect := Rect2i(Vector2i(pos), Vector2i.ONE).grow(REDACT_RADIUS)
	img.fill_rect(pixel_rect, REDACT_COLOR)

	var stroke_rect := Rect2(pos, Vector2.ONE).grow(REDACT_RADIUS)
	var touched_box := false
	for box in hidden_boxes:
		if box.intersects(stroke_rect):
			touched_box = true
			break

	if touched_box:
		_stroke_touched_box = true
	else:
		_stroke_touched_clean = true


func _to_image_pos(screen_pos: Vector2) -> Vector2:
	var lpos := to_local(screen_pos)
	return lpos - offset + get_rect().size / 2.0
const REDACT_COLOR: Color = Color(0.0, 0.0, 0.0)
const REDACT_SIZE : int = 5
const DEBUG_TARGET_RED := Color(1.0, 0.0, 0.0, 0.38)
const DEBUG_TARGET_GREEN := Color(0.0, 1.0, 0.0, 0.38)
## The current case supplies both the document texture and its hidden anomaly map.
var case_file: ArchiveFile
var img: Image
var anomaly_mask: Image
var debug_image: Image
var last_ink_position := Vector2(-1, -1)

@export var show_debug_anomaly_regions := true
@onready var debug_overlay: Sprite2D = $"../DebugAnomalyOverlay"

signal redaction_evaluated(result: Dictionary)

func _ready() -> void:
	_create_ink_canvas(IMG_SIZE)


func set_case_file(new_case_file: ArchiveFile) -> void:
	case_file = new_case_file
	var image_size := IMG_SIZE
	if case_file != null and case_file.document_texture != null:
		image_size = case_file.document_texture.get_size()
	_create_ink_canvas(image_size)


func clear_ink() -> void:
	_create_ink_canvas(img.get_size())


func _create_ink_canvas(image_size: Vector2i) -> void:
	img = Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	texture = ImageTexture.create_from_image(img)
	_build_anomaly_mask(image_size)


func _build_anomaly_mask(image_size: Vector2i) -> void:
	anomaly_mask = Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_L8)
	anomaly_mask.fill(Color.BLACK)
	debug_image = Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	debug_image.fill(Color.TRANSPARENT)
	if case_file == null:
		_update_debug_overlay(false)
		return
	for region in case_file.get_pixel_regions(image_size):
		anomaly_mask.fill_rect(region, Color.WHITE)
		debug_image.fill_rect(region, DEBUG_TARGET_RED)
	_update_debug_overlay(false)


func _update_debug_overlay(passed: bool) -> void:
	if not show_debug_anomaly_regions or debug_image == null:
		debug_overlay.visible = false
		return
	var debug_color := DEBUG_TARGET_GREEN if passed else DEBUG_TARGET_RED
	debug_image.fill(Color.TRANSPARENT)
	if case_file != null:
		for region in case_file.get_pixel_regions(img.get_size()):
			debug_image.fill_rect(region, debug_color)
	debug_overlay.texture = ImageTexture.create_from_image(debug_image)
	debug_overlay.visible = true
	

func _redact_image(position: Vector2) -> void:
	var pixel := Vector2i(roundi(position.x), roundi(position.y))
	var canvas_bounds := Rect2i(Vector2i.ZERO, img.get_size())
	var stroke := Rect2i(pixel, Vector2i.ONE).grow(REDACT_SIZE).intersection(canvas_bounds)
	if stroke.has_area():
		img.fill_rect(stroke, REDACT_COLOR)


func evaluate_redaction() -> Dictionary:
	if case_file == null or case_file.anomaly_regions.is_empty():
		return { "is_valid": false, "reason": "No anomaly regions have been authored for this case." }

	var required_pixels := 0
	var covered_pixels := 0
	var ink_pixels := 0
	var ink_outside_anomaly := 0
	for y in img.get_height():
		for x in img.get_width():
			var inked := img.get_pixel(x, y).a > 0.5
			var required := anomaly_mask.get_pixel(x, y).r > 0.5
			if required:
				required_pixels += 1
				if inked:
					covered_pixels += 1
			if inked:
				ink_pixels += 1
				if not required:
					ink_outside_anomaly += 1

	var coverage: float = float(covered_pixels) / float(maxi(required_pixels, 1))
	var overspill: float = float(ink_outside_anomaly) / float(maxi(ink_pixels, 1))
	var is_valid: bool = coverage >= case_file.required_coverage and overspill <= case_file.maximum_overspill
	var result := {
		"is_valid": is_valid,
		"coverage": coverage,
		"overspill": overspill,
		"required_pixels": required_pixels,
		"covered_pixels": covered_pixels,
	}
	_update_debug_overlay(is_valid)
	redaction_evaluated.emit(result)
	return result
	

func _input(event: InputEvent)-> void:
	if event is InputEventMouseButton:
		if event.pressed and event.is_echo() == false:
			var impos := _event_to_image_position(event.position)
			_redact_image(impos)
			last_ink_position = impos
			texture.update(img)
		elif not event.pressed:
			last_ink_position = Vector2(-1, -1)
	if event is InputEventMouseMotion:
		if event.button_mask == MOUSE_BUTTON_LEFT:
			var impos := _event_to_image_position(event.position)
			if last_ink_position.x >= 0.0:
				var distance := last_ink_position.distance_to(impos)
				for step in ceili(distance):
					_redact_image(last_ink_position.lerp(impos, float(step) / max(distance, 1.0)))
			else:
				_redact_image(impos)
			last_ink_position = impos
			texture.update(img)


func _event_to_image_position(screen_position: Vector2) -> Vector2:
	var local_position := to_local(screen_position)
	return local_position - offset + get_rect().size * 0.5

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
