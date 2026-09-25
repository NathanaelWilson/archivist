class_name InteractableOutline
extends Node

## Drop this as a child of a CanvasItem with a transparent-background texture
## (TextureButton, TextureRect, Sprite2D) to give it the same silhouette
## outline the desk props use: Shaders/desk_prop.gdshader, white by default,
## about 2.3 screen pixels thick, traced around the drawn shape rather than
## its bounding box, and never clipped where the art touches its edges.
##
## For a TextureButton it also restricts hover and clicks to the drawn
## silhouette (click mask), so the outline appears only when the pointer is
## actually on the picture — same as the desk props.
##
## This node doesn't decide what "hovered" means — whatever detects it (a
## Control's mouse_entered/mouse_exited, ...) calls show_outline(true/false).

@export var outline_color: Color = Color(1, 1, 1, 1)
## On-screen thickness in viewport pixels. The desk props' outline is 10
## source pixels drawn at ~0.23x, i.e. about 2.3.
@export var outline_width_px: float = 2.3
## Same alpha cut-off as the desk props: faint padding/anti-alias fringe
## below alpha_floor is neither drawn nor outlined.
@export var alpha_floor: float = 0.55
@export var alpha_ceiling: float = 0.8
@export var silhouette_click_mask: bool = true

const OUTLINE_SHADER := preload("res://Shaders/desk_prop.gdshader")

var _material: ShaderMaterial
var _target: CanvasItem


func _ready() -> void:
	_target = get_parent() as CanvasItem
	if _target == null:
		push_warning("InteractableOutline must be a child of a CanvasItem (Sprite2D, TextureRect, TextureButton, ...)")
		return

	_material = ShaderMaterial.new()
	_material.shader = OUTLINE_SHADER
	_material.set_shader_parameter("outline_color", outline_color)
	_material.set_shader_parameter("alpha_floor", alpha_floor)
	_material.set_shader_parameter("alpha_ceiling", alpha_ceiling)
	_material.set_shader_parameter("outline_enabled", false)
	_target.material = _material

	if _target is Control:
		(_target as Control).resized.connect(_fit_to_drawn_size)
	_fit_to_drawn_size()

	if silhouette_click_mask and _target is TextureButton:
		_build_click_mask(_target as TextureButton)


func show_outline(enabled: bool) -> void:
	if _material:
		_material.set_shader_parameter("outline_enabled", enabled)


func _texture() -> Texture2D:
	if _target is TextureButton:
		return (_target as TextureButton).texture_normal
	if _target is TextureRect:
		return (_target as TextureRect).texture
	if _target is Sprite2D:
		return (_target as Sprite2D).texture
	return null


## The shader works in texels; a Control draws its texture at its laid-out
## size, so convert the on-screen width into texels for the current size.
func _fit_to_drawn_size() -> void:
	var tex := _texture()
	if tex == null or _material == null:
		return
	var tex_size := tex.get_size()
	var drawn := tex_size # Sprite2D: one local unit per texel
	if _target is Control:
		drawn = _drawn_size((_target as Control).size, tex_size)
		_material.set_shader_parameter("uv_per_unit", Vector2.ONE / drawn)
		_material.set_shader_parameter("grow_units", outline_width_px + 2.0)
	var units_per_texel := drawn.x / tex_size.x
	_material.set_shader_parameter("outline_width", outline_width_px / maxf(units_per_texel, 0.0001))


## Size the texture is actually drawn at inside a Control of this size.
## Every stretch mode the menu uses keeps the aspect ratio; SCALE and
## ignore-size-off TextureRects are handled too.
func _drawn_size(control_size: Vector2, tex_size: Vector2) -> Vector2:
	var mode := -1
	if _target is TextureButton:
		mode = (_target as TextureButton).stretch_mode
		if mode == TextureButton.STRETCH_SCALE:
			return control_size
	elif _target is TextureRect:
		mode = (_target as TextureRect).stretch_mode
		if mode == TextureRect.STRETCH_SCALE:
			return control_size
	var fit := minf(control_size.x / tex_size.x, control_size.y / tex_size.y)
	return tex_size * fit


func _build_click_mask(button: TextureButton) -> void:
	var tex := button.texture_normal
	if tex == null or button.texture_click_mask != null:
		return
	var image := tex.get_image()
	if image == null:
		return
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	var mask := BitMap.new()
	mask.create_from_image_alpha(image, (alpha_floor + alpha_ceiling) * 0.5)
	button.texture_click_mask = mask
