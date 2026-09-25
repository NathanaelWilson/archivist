class_name DeskProp
extends Sprite2D

## A piece of desk art the player touches directly (the rules clipboard, the
## case tray, ...), instead of a UI button.
##
## The art comes straight out of the Affinity slices, which bake the scene's
## grain/grade into the whole slice rectangle, so the raw alpha is never
## trusted:
##   * desk_prop.gdshader drops everything below alpha_floor when drawing and
##     traces the highlight outline around what is left;
##   * touches are tested against a BitMap built from the same cut-off, so
##     only the object's real silhouette responds — never the padding.
##
## Input runs in _unhandled_input, so anything drawn over the desk as UI (the
## rules board, the shift card, the document viewer's Close button) gets the
## touch first. Main also hands every prop a can_interact gate, so nothing on
## the desk reacts while a document or the eyelids own the screen.

signal tapped

@export var alpha_floor := 0.55
@export var alpha_ceiling := 0.8
@export var outline_color := Color(1, 1, 1, 1)
## In source-art pixels. The desk is drawn at roughly 0.23x, so 10 is about
## two screen pixels.
@export var outline_width := 10.0
## A touch that wanders further than this (viewport pixels) is not a tap.
@export var tap_slop := 12.0
## Off for art that is only drawn with the cut-off (the desk front, the
## cabinet): it never outlines or reacts, but contains_point() still works,
## e.g. to tell whether the desk is covering something behind it.
@export var interactive := true

const SHADER := preload("res://Shaders/desk_prop.gdshader")

## Set by Main. Returns true while the desk may be touched at all.
var can_interact: Callable = Callable()

var _hit_mask: BitMap
var _material: ShaderMaterial
var _hovered := false
var _pressing := false
var _press_position := Vector2.ZERO
var _outline_shown := false


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("alpha_floor", alpha_floor)
	_material.set_shader_parameter("alpha_ceiling", alpha_ceiling)
	_material.set_shader_parameter("outline_color", outline_color)
	_material.set_shader_parameter("outline_width", outline_width)
	_material.set_shader_parameter("outline_enabled", false)
	material = _material
	_build_hit_mask()


## True if this screen/viewport point lands on the object itself.
func contains_point(screen_position: Vector2) -> bool:
	if _hit_mask == null:
		return false
	var rect := get_rect()
	var local := to_local(screen_position)
	if not rect.has_point(local):
		return false
	var mask_size := _hit_mask.get_size()
	var pixel := Vector2i((local - rect.position).floor())
	pixel = pixel.clamp(Vector2i.ZERO, mask_size - Vector2i.ONE)
	return _hit_mask.get_bitv(pixel)


## Centre of the prop's art, in global (viewport) coordinates.
func get_global_center() -> Vector2:
	return to_global(get_rect().get_center())


func is_available() -> bool:
	if not is_visible_in_tree() or not _accepts_input():
		return false
	return not can_interact.is_valid() or bool(can_interact.call())


## Drops any touch in progress, e.g. when the desk is locked mid-gesture.
func cancel_touch() -> void:
	if _pressing:
		_pressing = false
		_on_touch_cancelled()


func _process(_delta: float) -> void:
	var available := is_available()
	if _pressing and not available:
		cancel_touch()
	_set_outline((_hovered or _pressing) and available)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not PointerInput.is_emulated(event):
		_hovered = contains_point(event.position)

	var press: Variant = PointerInput.press_position(event)
	if press != null:
		if is_available() and contains_point(press as Vector2):
			get_viewport().set_input_as_handled()
			_pressing = true
			_press_position = press as Vector2
			_on_press(press as Vector2)
		return

	var drag: Variant = PointerInput.drag_position(event)
	if drag != null:
		if _pressing:
			get_viewport().set_input_as_handled()
			_on_drag(drag as Vector2)
		return

	var release: Variant = PointerInput.release_position(event)
	if release != null and _pressing:
		get_viewport().set_input_as_handled()
		_pressing = false
		_on_release(release as Vector2)


# ------------------------------------------------ Overridable behaviour --

## False while this prop has nothing to offer (e.g. an empty case tray).
func _accepts_input() -> bool:
	return interactive


func _on_press(_screen_position: Vector2) -> void:
	pass


func _on_drag(_screen_position: Vector2) -> void:
	pass


## Default gesture: a tap that starts and ends on the object.
func _on_release(screen_position: Vector2) -> void:
	if screen_position.distance_to(_press_position) <= tap_slop and contains_point(screen_position):
		tapped.emit()


func _on_touch_cancelled() -> void:
	pass


# ------------------------------------------------------------ Internals --

func _set_outline(shown: bool) -> void:
	if shown == _outline_shown or _material == null:
		return
	_outline_shown = shown
	_material.set_shader_parameter("outline_enabled", shown)


func _build_hit_mask() -> void:
	if texture == null:
		return
	var image := texture.get_image()
	if image == null:
		push_warning("%s: could not read its texture, so it cannot be touched." % name)
		return
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	_hit_mask = BitMap.new()
	# Halfway through the shader's feather: a touch counts where the art is
	# clearly drawn, never on the tinted padding.
	_hit_mask.create_from_image_alpha(image, (alpha_floor + alpha_ceiling) * 0.5)
