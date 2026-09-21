class_name FileInspector
extends CanvasLayer

## Assign an ArchiveFile resource here for a case. The anomaly rectangles remain
## hidden; only the document image and redaction ink are visible to the player.
@export var current_file: ArchiveFile:
	set(value):
		current_file = value
		if is_node_ready():
			_load_file()

## All three layers use this together, so the debug mask remains pixel-aligned
## with the image and the player's ink at the requested 2x presentation size.
@export var document_scale := Vector2(2.0, 2.0)

@onready var document_image: Sprite2D = $DocumentImage
@onready var redaction_layer: RedactionLayer = $RedactionLayer


func _ready() -> void:
	_load_file()


func _load_file() -> void:
	document_image.scale = document_scale
	redaction_layer.scale = document_scale
	$DebugAnomalyOverlay.scale = document_scale
	if current_file != null:
		document_image.texture = current_file.document_texture
		redaction_layer.set_case_file(current_file)


func submit_redaction() -> Dictionary:
	return redaction_layer.evaluate_redaction()
