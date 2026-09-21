class_name InteractableOutline
extends Node

## Drop this as a child of ANY CanvasItem with a transparent-background
## texture (Sprite2D, TextureRect, TextureButton, ...) to give it a
## silhouette-accurate highlight for "this can be interacted with" - a gear
## icon today, a document, cabinet or fax machine later.
##
## This node itself doesn't know what "hovered" means - whatever detects the
## interaction (a Control's mouse_entered/mouse_exited, an Area2D's
## mouse_entered/mouse_exited, a proximity check, a raycast, ...) should call
## show_outline(true) / show_outline(false) on it.

@export var outline_color: Color = Color(0.960784, 0.752941, 0.0, 1.0)
@export var outline_width: float = 2.0

const OUTLINE_SHADER := preload("res://Shaders/interactable_outline.gdshader")

var _material: ShaderMaterial


func _ready() -> void:
	var target := get_parent() as CanvasItem
	if target == null:
		push_warning("InteractableOutline must be a child of a CanvasItem (Sprite2D, TextureRect, TextureButton, ...)")
		return

	_material = ShaderMaterial.new()
	_material.shader = OUTLINE_SHADER
	_material.set_shader_parameter("outline_color", outline_color)
	_material.set_shader_parameter("outline_width", outline_width)
	_material.set_shader_parameter("outline_enabled", false)
	target.material = _material


func show_outline(enabled: bool) -> void:
	if _material:
		_material.set_shader_parameter("outline_enabled", enabled)
