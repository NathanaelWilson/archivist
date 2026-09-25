class_name SplashScreen
extends CanvasLayer

## The title card at the very start of Shift 1: once the eyes have opened on
## the desk, the photo and the "Department of Truth" title come up over it,
## with the desk behind them blurred (Shaders/backdrop_blur.gdshader).
##
## Both images (Assets/Images/SplashScreen/Photo.png, Assets/Images/Title.png)
## are full frames in the desk's source-art space (4083 x 1750), exactly like
## the desk props, so they are laid out the same way the Desk node is: scaled
## to cover the viewport and centred. Where the artist put them in Affinity is
## where they appear.
##
## play() is awaitable: it fades the card in, holds it for hold_sec, and
## fades it out again. No tap needed; taps are swallowed while it is up so
## nothing on the desk reacts underneath it.

## Size of the art the images are laid out in (the same as Desk).
@export var design_size := Vector2(4083, 1750)
@export var fade_in_sec := 0.8
@export var fade_out_sec := 0.5
## How long the card stays fully on screen, between fading in and out.
@export var hold_sec := 1.0

@onready var root: Control = $Root
@onready var art: Node2D = $Art


func _ready() -> void:
	visible = false
	get_viewport().size_changed.connect(_fit_art)
	_fit_art()


func play() -> void:
	_fit_art()
	visible = true
	root.modulate.a = 0.0
	art.modulate.a = 0.0
	var fade_in := create_tween().set_parallel(true)
	fade_in.tween_property(root, "modulate:a", 1.0, fade_in_sec)
	fade_in.tween_property(art, "modulate:a", 1.0, fade_in_sec)
	await fade_in.finished
	await get_tree().create_timer(hold_sec).timeout
	var fade_out := create_tween().set_parallel(true)
	fade_out.tween_property(root, "modulate:a", 0.0, fade_out_sec)
	fade_out.tween_property(art, "modulate:a", 0.0, fade_out_sec)
	await fade_out.finished
	visible = false


# Read in _input so a tap is taken before anything on the desk can see it;
# the full-screen Root control also swallows it for any Button underneath.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if PointerInput.press_position(event) != null or PointerInput.release_position(event) != null:
		get_viewport().set_input_as_handled()


## Cover-fit, identical to Desk.fit_to_viewport().
func _fit_art() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := maxf(view.x / design_size.x, view.y / design_size.y)
	art.scale = Vector2(fit, fit)
	art.position = (view - design_size * fit) * 0.5
