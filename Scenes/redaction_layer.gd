class_name RedactionLayer
extends Sprite2D

const IMG_SIZE: Vector2i = Vector2i(512, 1024)
const REDACT_COLOR: Color = Color(0.0, 0.0, 0.0)
const REDACT_SIZE : int = 5
var img: Image

func _ready() -> void:
	img = Image.create_empty(IMG_SIZE.x, IMG_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	texture = ImageTexture.create_from_image(img)
	
func _redact_image(position) -> void:
	var semi_transparent_color := REDACT_COLOR
	semi_transparent_color.a = 1.0
	img.fill_rect(Rect2i(position, Vector2i(1,1)).grow(REDACT_SIZE), semi_transparent_color)
	

func _input(event: InputEvent)-> void:
	if event is InputEventMouseButton:
		if event.pressed and event.is_echo() == false:
			var lpos = to_local(event.position)
			var impos = lpos-offset+get_rect().size/2.0
			_redact_image(impos)
			texture.update(img)
	if event is InputEventMouseMotion:
		if event.button_mask == MOUSE_BUTTON_LEFT:
			var lpos = to_local(event.position)
			var impos = lpos-offset+get_rect().size/2.0
			
			if event.relative.length_squared() > 0:
				var num := ceili(event.relative.length())
				var target_pos = impos - (event.relative)
				for i in num: 
					impos = impos.move_toward(target_pos, 1.0)
					_redact_image(impos)
			texture.update(img)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
