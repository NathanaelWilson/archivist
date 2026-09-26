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

## --- Bleeding ink (CaseData.ink_bleeds) ---------------------------------
## The bleed lives on its own layer, drawn under the ink, and is never read by
## evaluate_redaction(): it is something the paper does, not something the
## player did. It is strongest straight after a stroke and settles over
## BLEED_SETTLE_SEC, the way wet ink stops spreading once it soaks in.
const BLEED_TICK_SEC := 0.06
const BLEED_SETTLE_SEC := 8.0
## Blood, not ink: bright and thin where it has only just reached the paper,
## dark and clotted where it has pooled. The colour is picked per pixel from
## how much has built up there.
const BLEED_COLOR_THIN := Color(0.62, 0.03, 0.04)  # fresh, arterial
const BLEED_COLOR_THICK := Color(0.26, 0.0, 0.02)  # pooled, drying
const BLEED_MAX_ALPHA := 0.9
const BLEED_FEATHER_PER_TICK := 12
const BLEED_FEATHER_RADIUS := Vector2(2.0, 7.0)
const MAX_BLEED_SEEDS := 3000
const DRIPS_PER_STROKE := Vector2i(1, 3)
const DRIP_LENGTH := Vector2(18.0, 60.0)

## Draws the anomaly box (red / yellow / green) and safe zone (blue) over the
## case while redacting. For tuning only — off for players. Tick it on the
## RedactionLayer node in document_viewer.tscn to see the boxes again.
@export var show_debug_anomaly_regions := false

var case_data: CaseData
var ink_image: Image
var anomaly_mask: Image
var debug_image: Image
var bleed_image: Image
var _last_image_position := Vector2.ZERO

var _bleeding := false
var _bleed_sprite: Sprite2D
var _bleed_seeds := PackedVector2Array() ## every point the marker has touched
var _stroke_points := PackedVector2Array() ## just this stroke, for its drips
var _drips: Array[Dictionary] = []
var _bleed_activity := 0.0 ## 1 right after a stroke, decays to 0 as it settles
var _bleed_clock := 0.0
## The page as it was before each stroke of this viewing, newest last (see
## undo_last_stroke): {"ink": Image, "bleed": Image or null}. Emptied
## whenever a page is (re)loaded.
var _undo_stack: Array[Dictionary] = []
const MAX_UNDO := 30

@onready var debug_overlay: Sprite2D = $"../DebugAnomalyOverlay"

signal redaction_evaluated(result: Dictionary)


func _ready() -> void:
	# Drawn behind this sprite, so the solid ink always sits on top of its
	# own halo.
	_bleed_sprite = Sprite2D.new()
	_bleed_sprite.show_behind_parent = true
	add_child(_bleed_sprite)
	_create_canvases(IMG_SIZE)


## canvas_size is the document's on-screen size; DocumentViewer passes the
## size it fitted the case art to so ink, anomaly mask and art stay aligned.
## saved_ink restores ink the player already put on this document.
## saved_bleed restores how far that ink had already bled.
func set_case_data(new_case_data: CaseData, canvas_size: Vector2i = IMG_SIZE, saved_ink: Image = null, saved_bleed: Image = null) -> void:
	case_data = new_case_data
	_undo_stack.clear()
	_bleeding = case_data != null and case_data.ink_bleeds
	_create_canvases(canvas_size)
	if saved_ink != null and not saved_ink.is_empty() and saved_ink.get_format() == Image.FORMAT_RGBA8:
		# duplicate() is typed Resource, so the cast is needed to assign it.
		ink_image = saved_ink.duplicate() as Image
		if ink_image.get_size() != canvas_size:
			ink_image.resize(canvas_size.x, canvas_size.y, Image.INTERPOLATE_NEAREST)
		(texture as ImageTexture).set_image(ink_image)
		evaluate_redaction() # refresh the debug colour for the restored ink
		if _bleeding:
			_reseed_bleed_from_ink()
	if _bleeding and saved_bleed != null and not saved_bleed.is_empty() \
			and saved_bleed.get_format() == Image.FORMAT_RGBA8 and saved_bleed.get_size() == canvas_size:
		bleed_image = saved_bleed.duplicate() as Image
		(_bleed_sprite.texture as ImageTexture).set_image(bleed_image)


## A copy of how far the ink has bled, kept with the document while closed.
## null for documents whose ink does not bleed.
func get_bleed_image() -> Image:
	if not _bleeding or bleed_image == null:
		return null
	return bleed_image.duplicate() as Image


## A copy of the current ink, for the document to keep while it is closed.
func get_ink_image() -> Image:
	if ink_image == null:
		return null
	return ink_image.duplicate() as Image


func clear_ink() -> void:
	_create_canvases(ink_image.get_size())


func begin_stroke(screen_position: Vector2) -> void:
	_undo_stack.append({
		"ink": ink_image.duplicate() as Image,
		"bleed": bleed_image.duplicate() as Image if _bleeding and bleed_image != null else null,
	})
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()
	_last_image_position = _to_image_position(screen_position)
	_stamp(_last_image_position)
	_record_bleed_point(_last_image_position)
	(texture as ImageTexture).update(ink_image)


func stroke_to(screen_position: Vector2) -> void:
	var target := _to_image_position(screen_position)
	var distance := _last_image_position.distance_to(target)
	for step in ceili(distance):
		var point := _last_image_position.lerp(target, float(step) / maxf(distance, 1.0))
		_stamp(point)
		_record_bleed_point(point)
	_last_image_position = target
	(texture as ImageTexture).update(ink_image)


## True when there is a stroke from this viewing that can be taken back.
func can_undo() -> bool:
	return not _undo_stack.is_empty()


## Takes back the most recent stroke: the ink returns to how it was just
## before it. Returns the re-evaluated redaction result.
func undo_last_stroke() -> Dictionary:
	if _undo_stack.is_empty():
		return evaluate_redaction()
	var before: Dictionary = _undo_stack.pop_back()
	ink_image = before["ink"]
	(texture as ImageTexture).set_image(ink_image)
	if _bleeding:
		# Bleeding ink: roll the stain back too and let it creep only from
		# what is left.
		if before["bleed"] != null:
			bleed_image = before["bleed"]
			(_bleed_sprite.texture as ImageTexture).set_image(bleed_image)
		_drips.clear()
		_stroke_points.clear()
		_reseed_bleed_from_ink()
	return evaluate_redaction()


func end_stroke() -> Dictionary:
	if _bleeding:
		_spawn_drips()
		_bleed_activity = 1.0
	return evaluate_redaction()


# ------------------------------------------------------------ Bleeding --

func _process(delta: float) -> void:
	if not _bleeding or not is_visible_in_tree():
		return
	if _bleed_activity <= 0.0 and _drips.is_empty():
		return # fully settled: nothing moves, nothing to upload
	_bleed_activity = maxf(0.0, _bleed_activity - delta / BLEED_SETTLE_SEC)
	_bleed_clock += delta
	var changed := false
	while _bleed_clock >= BLEED_TICK_SEC:
		_bleed_clock -= BLEED_TICK_SEC
		changed = _bleed_step() or changed
	if changed:
		(_bleed_sprite.texture as ImageTexture).update(bleed_image)


## One tick of spreading. Returns true if anything was drawn.
func _bleed_step() -> bool:
	var drew := false
	# Feathering: the ink wicks outward along the paper fibres, a little
	# further from the stroke each time, thinner the further it goes.
	var feathers := roundi(BLEED_FEATHER_PER_TICK * _bleed_activity)
	for i in feathers:
		if _bleed_seeds.is_empty():
			break
		var origin: Vector2 = _bleed_seeds[randi() % _bleed_seeds.size()]
		var angle := randf() * TAU
		var reach := randf_range(BLEED_FEATHER_RADIUS.x, BLEED_FEATHER_RADIUS.y)
		_deposit_bleed(origin + Vector2(cos(angle), sin(angle)) * reach, randf_range(0.04, 0.14), 1)
		drew = true
	# Drips: heavy ink runs down the page, wavering, thinning as it goes, and
	# pooling into a bead where it stops.
	for i in range(_drips.size() - 1, -1, -1):
		var drip: Dictionary = _drips[i]
		var pos: Vector2 = drip["pos"]
		pos.y += randf_range(0.6, 1.2)
		pos.x += randf_range(-0.35, 0.35)
		drip["pos"] = pos
		var left: float = float(drip["left"]) - 1.0
		drip["left"] = left
		var width: int = int(drip["width"])
		var strength := clampf(left / float(drip["length"]), 0.25, 1.0)
		_deposit_bleed(pos, 0.5 * strength, width)
		drew = true
		if left <= 0.0 or pos.y >= bleed_image.get_height() - 1:
			_deposit_bleed(pos, 0.55, width + 1) # the bead at the end
			_drips.remove_at(i)
	return drew


func _record_bleed_point(image_position: Vector2) -> void:
	if not _bleeding:
		return
	_stroke_points.append(image_position)
	if _bleed_seeds.size() < MAX_BLEED_SEEDS:
		_bleed_seeds.append(image_position)
	else:
		_bleed_seeds[randi() % MAX_BLEED_SEEDS] = image_position


## Each stroke leaves one to three drips, starting from the underside of the
## marker at random points along the stroke.
func _spawn_drips() -> void:
	if _stroke_points.is_empty():
		return
	var count := randi_range(DRIPS_PER_STROKE.x, DRIPS_PER_STROKE.y)
	for i in count:
		var start: Vector2 = _stroke_points[randi() % _stroke_points.size()]
		var length := randf_range(DRIP_LENGTH.x, DRIP_LENGTH.y)
		_drips.append({
			"pos": start + Vector2(randf_range(-3.0, 3.0), MARKER_SIZE.y * 0.5),
			"left": length,
			"length": length,
			"width": randi_range(0, 1),
		})
	_stroke_points.clear()


## Reopening a bled document: its old strokes keep creeping a little, from
## where the saved ink actually is.
func _reseed_bleed_from_ink() -> void:
	_bleed_seeds.clear()
	for y in range(0, ink_image.get_height(), 2):
		for x in range(0, ink_image.get_width(), 2):
			if ink_image.get_pixel(x, y).a > 0.5 and _bleed_seeds.size() < MAX_BLEED_SEEDS:
				_bleed_seeds.append(Vector2(x, y))
	if not _bleed_seeds.is_empty():
		_bleed_activity = 0.35


## Adds blood around a point, soft at the edge. The more that collects on a
## pixel, the more opaque and the darker it gets, so thin wicking stays a
## bright red stain while drips and beads read as thick and wet.
func _deposit_bleed(center: Vector2, amount: float, radius: int) -> void:
	var cx := roundi(center.x)
	var cy := roundi(center.y)
	for y in range(cy - radius, cy + radius + 1):
		if y < 0 or y >= bleed_image.get_height():
			continue
		for x in range(cx - radius, cx + radius + 1):
			if x < 0 or x >= bleed_image.get_width():
				continue
			var falloff := 1.0 - Vector2(x - center.x, y - center.y).length() / float(radius + 1)
			if falloff <= 0.0:
				continue
			var existing := bleed_image.get_pixel(x, y).a
			var alpha := minf(existing + amount * falloff, BLEED_MAX_ALPHA)
			var thickness := alpha / BLEED_MAX_ALPHA
			var colour := BLEED_COLOR_THIN.lerp(BLEED_COLOR_THICK, thickness * thickness)
			bleed_image.set_pixel(x, y, Color(colour, alpha))


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
			# Nothing on this page needs covering, so any stroke is on clean paper.
			"stray_stroke": clean_ink_pixels > 0,
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
		"stray_stroke": _has_stray_stroke(),
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


## True if any mark on the page sits entirely on clean paper — touching
## neither the anomaly nor its safe zone. Works from the ink itself rather
## than a stroke history, so it survives closing and reopening the file:
## each separate blob of ink is traced, and a blob that never reaches an
## allowed pixel is a stroke made at nothing. Strokes that overlap a valid
## one merge with it and are not counted, since they were aimed at the
## anomaly.
func _has_stray_stroke() -> bool:
	var width := ink_image.get_width()
	var height := ink_image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	for start_y in height:
		for start_x in width:
			var start_index := start_y * width + start_x
			if visited[start_index] != 0 or ink_image.get_pixel(start_x, start_y).a <= 0.5:
				continue
			# Flood the whole blob, noting whether any of it is allowed ink.
			var touches_allowed := false
			var stack: Array[Vector2i] = [Vector2i(start_x, start_y)]
			visited[start_index] = 1
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				if anomaly_mask.get_pixel(p.x, p.y).r > 0.25:
					touches_allowed = true
				for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = p + offset
					if n.x < 0 or n.y < 0 or n.x >= width or n.y >= height:
						continue
					var n_index := n.y * width + n.x
					if visited[n_index] != 0 or ink_image.get_pixel(n.x, n.y).a <= 0.5:
						continue
					visited[n_index] = 1
					stack.append(n)
			if not touches_allowed:
				return true
	return false


func _create_canvases(image_size: Vector2i) -> void:
	ink_image = Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	ink_image.fill(Color.TRANSPARENT)
	texture = ImageTexture.create_from_image(ink_image)
	bleed_image = Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	bleed_image.fill(Color.TRANSPARENT)
	if _bleed_sprite != null:
		_bleed_sprite.texture = ImageTexture.create_from_image(bleed_image)
	_bleed_seeds.clear()
	_stroke_points.clear()
	_drips.clear()
	_bleed_activity = 0.0
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
