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
