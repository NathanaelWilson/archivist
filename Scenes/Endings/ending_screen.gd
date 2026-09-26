class_name EndingScreen
extends CanvasLayer

## Shared behaviour for the four Record-of-Outcomes ending screens — one
## scene per ending (ending_loyalist / ending_liability / ending_paranoid /
## ending_zealot.tscn). Each scene only sets its `ending_id`; Main picks which
## scene to instantiate from GameScore.evaluate_ending() and calls present().
##
## The ending itself is the notice art in Assets/Endings/. Each scene sets it
## on its Notice node, so the art is visible in the editor while the marks
## over it (blood, redaction bars) are placed. If a scene is left without one,
## it is found by name instead — each file is named after its ending
## (Loyalist.png, Liability.png, Paranoid.png, Zealot.png).
##
## present() plays the whole ending with no input: the notice scrolls up like
## credits (zoomed so only its top half is in frame), sits for HOLD_SEC, then
## each ending's own fade to dark plays, the screen stays dark, and `finished`
## is emitted under a black cover that fades out over the main menu.

signal finished

const NOTICE_PATH_FORMAT := "res://Assets/Endings/%s.png"
const BLUR_SHADER := preload("res://Shaders/backdrop_blur.gdshader")
const LIABILITY_BLOOD := preload("res://Assets/Endings/Liability_ending.webp")
const ZEALOT_FLICKER := preload("res://Assets/Endings/ZealotFlicker.jpg")
const PARANOID_REDACT_FORMAT := "res://Assets/Endings/ParanoidRedact/ParanoidRedact_%d.png"
const PARANOID_REDACT_COUNT := 14

const SCROLL_SEC := 6.0
## Gap between the top of the screen and the top of the notice once it stops.
const PAPER_TOP_GAP := 16.0
const HOLD_SEC := 12.0
const DARK_HOLD_SEC := 4.0
const RETURN_FADE_SEC := 1.5
const BLUR_SEC := 3.0
const DARKEN_SEC := 2.5
const BLEED_SEC := 6.0
## The blood art (2000 px wide) is only solid between x 440 and 1560, and
## down to about 55% of its height; that part is stretched over the screen.
const BLOOD_BAND := Vector2(440.0, 1560.0)
const BLOOD_ART_WIDTH := 2000.0
const BLOOD_SOLID_FRACTION := 0.55
const REDACT_STEP_SEC := 0.35
const ZEALOT_FLICKER_DELAY_SEC := 3.0
const ZEALOT_FLICKER_SEC := 2.0
const ZEALOT_FLICKER_ALPHA := 0.6

@export var ending_id: StringName = &""

@onready var overlay: Control = $Overlay
@onready var center: Control = $Overlay/Center
@onready var notice: TextureRect = $Overlay/Center/Content/Notice

var _black := ColorRect.new()


func _ready() -> void:
	visible = false
	center.modulate.a = 0.0
	if notice.texture == null:
		notice.texture = _load_notice()
	_black.color = Color(0, 0, 0, 0)
	_fill(_black)
	overlay.add_child(_black)


func present() -> void:
	visible = true
	Music.play(StringName("ending_%s" % ending_id)) # e.g. ending_zealot
	# Per-ending stinger (ending_<id>) if it exists, otherwise the shared one.
	if not SFX.play(StringName("ending_%s" % ending_id)):
		SFX.play(&"ending_reveal")
	await _scroll_notice_in()
	await get_tree().create_timer(HOLD_SEC).timeout
	match ending_id:
		&"liability": await _bleed_out()
		&"paranoid": await _redact_out()
		_: await _blur_out() # loyalist, zealot
	if ending_id == &"zealot":
		await get_tree().create_timer(ZEALOT_FLICKER_DELAY_SEC).timeout
		await _zealot_flicker()
	else:
		await get_tree().create_timer(DARK_HOLD_SEC).timeout
	_cover_scene_change()
	finished.emit()


## Credits-style: the notice rises from below the screen and stops with its
## top just under the top edge, zoomed so its bottom half stays cut off.
func _scroll_notice_in() -> void:
	await get_tree().process_frame # let the containers lay the notice out
	var view := overlay.get_viewport_rect().size
	var top := notice.global_position.y
	var s := (view.y - PAPER_TOP_GAP) / (notice.size.y * 0.5)
	center.pivot_offset = Vector2(center.size.x * 0.5, 0.0)
	center.scale = Vector2(s, s)
	center.position.y = view.y - s * top
	var tween := create_tween().set_parallel()
	tween.tween_property(center, "position:y", PAPER_TOP_GAP - s * top, SCROLL_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(center, "modulate:a", 1.0, SCROLL_SEC * 0.5)
	await tween.finished


## Loyalist / Zealot: the screen goes out of focus, then dark.
func _blur_out() -> void:
	var blur := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = BLUR_SHADER
	mat.set_shader_parameter("blur", 0.0)
	mat.set_shader_parameter("dim", 0.0)
	mat.set_shader_parameter("tint_strength", 0.0)
	blur.material = mat
	_add_under_black(blur)
	var tween := create_tween()
	tween.tween_property(mat, "shader_parameter/blur", 5.0, BLUR_SEC)
	tween.tween_property(_black, "color:a", 1.0, DARKEN_SEC)
	await tween.finished


## Liability: blood runs down from the top until it covers the screen,
## darkening as it goes.
func _bleed_out() -> void:
	var view := overlay.get_viewport_rect().size
	var band := BLOOD_BAND.y - BLOOD_BAND.x
	var blood := TextureRect.new()
	blood.texture = LIABILITY_BLOOD
	blood.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blood.stretch_mode = TextureRect.STRETCH_SCALE
	blood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blood.size = Vector2(view.x * BLOOD_ART_WIDTH / band, view.y * 1.1 / BLOOD_SOLID_FRACTION)
	blood.position = Vector2(-view.x * BLOOD_BAND.x / band, -blood.size.y)
	overlay.add_child(blood)
	overlay.move_child(blood, _black.get_index())
	SFX.play(&"ending_blood")
	var tween := create_tween().set_parallel()
	tween.tween_property(blood, "position:y", view.y - blood.size.y * BLOOD_SOLID_FRACTION, BLEED_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(blood, "modulate", Color.BLACK, BLEED_SEC) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_black, "color:a", 1.0, DARKEN_SEC).set_delay(BLEED_SEC - DARKEN_SEC)
	await tween.finished


## Paranoid: the screen is redacted bar by bar (the art is drawn at screen
## size, so each piece is simply stretched over the screen), then goes dark.
func _redact_out() -> void:
	for i in range(1, PARANOID_REDACT_COUNT + 1):
		var bar := TextureRect.new()
		bar.texture = load(PARANOID_REDACT_FORMAT % i)
		bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bar.stretch_mode = TextureRect.STRETCH_SCALE
		_add_under_black(bar)
		SFX.play(&"redact_stroke")
		await get_tree().create_timer(REDACT_STEP_SEC).timeout
	var tween := create_tween()
	tween.tween_property(_black, "color:a", 1.0, DARKEN_SEC)
	await tween.finished


## Zealot: a face glitches in and out over the dark, at random intervals.
func _zealot_flicker() -> void:
	var face := TextureRect.new()
	face.texture = ZEALOT_FLICKER
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.modulate.a = ZEALOT_FLICKER_ALPHA
	face.visible = false
	_fill(face)
	overlay.add_child(face) # over the black
	SFX.play(&"light_glitch")
	var left := ZEALOT_FLICKER_SEC
	while left > 0.0:
		face.visible = not face.visible
		var step := randf_range(0.03, 0.18)
		await get_tree().create_timer(step).timeout
		left -= step
	face.queue_free()


## A black cover that outlives this scene: Main swaps to the menu under it,
## then it fades out.
func _cover_scene_change() -> void:
	var cover := CanvasLayer.new()
	cover.layer = 128
	var rect := ColorRect.new()
	rect.color = Color.BLACK
	_fill(rect)
	cover.add_child(rect)
	get_tree().root.add_child(cover)
	var tween := cover.create_tween()
	tween.tween_interval(0.1) # the menu scene loads first
	tween.tween_property(rect, "color:a", 0.0, RETURN_FADE_SEC)
	tween.tween_callback(cover.queue_free)


func _add_under_black(node: Control) -> void:
	_fill(node)
	overlay.add_child(node)
	overlay.move_child(node, _black.get_index())


func _fill(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE


## "loyalist" -> res://Assets/Endings/Loyalist.png
func _load_notice() -> Texture2D:
	var path := NOTICE_PATH_FORMAT % String(ending_id).capitalize()
	if not ResourceLoader.exists(path):
		push_warning("EndingScreen: no notice art for '%s' at %s." % [ending_id, path])
		return null
	return load(path) as Texture2D
