class_name WelcomeLetter
extends CanvasLayer

## Prologue, once, right after the eyes first open on Shift 1: the welcome
## letter slides up from below the screen, zoomed so only its top part shows.
## START appears after a moment; pressing it slides the letter back down.

signal finished

const LETTER := preload("res://Assets/Images/WelcomingLetter.webp")

## Share of the letter's height that shows on screen; the rest is below the edge.
@export var visible_share := 0.6
@export var top_margin := 16.0
@export var slide_sec := 0.6
@export var start_delay_sec := 4.0

var _letter: TextureRect
var _start: Button


func _init() -> void:
	layer = 12 # over the fax report, under the eyelids and pause menu


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP # the desk is off-limits meanwhile
	root.theme = preload("res://Assets/Fonts/main_menu_theme.tres")
	add_child(root)

	_letter = TextureRect.new()
	_letter.texture = LETTER
	_letter.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_letter)

	# Same look as the DONE button on the document page.
	_start = Button.new()
	_start.text = "START"
	_start.focus_mode = Control.FOCUS_NONE
	_start.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_start.add_theme_color_override("font_color", Color(0.93, 0.89, 0.8))
	_start.add_theme_color_override("font_hover_color", Color(1, 0.86, 0.35))
	_start.add_theme_font_size_override("font_size", 18)
	var normal := _pill(Color(0.12, 0.105, 0.085, 0.92), Color(0.93, 0.89, 0.8))
	var hover := _pill(Color(0.25, 0.21, 0.16, 0.95), Color(1, 0.86, 0.35))
	_start.add_theme_stylebox_override("normal", normal)
	_start.add_theme_stylebox_override("hover", hover)
	_start.add_theme_stylebox_override("pressed", hover)
	_start.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_start.offset_left = -130.0
	_start.offset_top = -70.0
	_start.offset_right = -24.0
	_start.offset_bottom = -24.0
	_start.visible = false
	_start.pressed.connect(_on_start_pressed)
	root.add_child(_start)


## Slides the letter in, waits, shows START. Await `finished` for the close.
func play() -> void:
	var view := get_viewport().get_visible_rect().size
	var zoom := (view.y - top_margin) / (LETTER.get_height() * visible_share)
	_letter.size = Vector2(LETTER.get_size()) * zoom
	var x := (view.x - _letter.size.x) * 0.5
	_letter.position = Vector2(x, view.y)
	var t := create_tween()
	t.tween_property(_letter, "position:y", top_margin, slide_sec) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(slide_sec + start_delay_sec, false).timeout
	_start.modulate.a = 0.0
	_start.visible = true
	create_tween().tween_property(_start, "modulate:a", 1.0, 0.3)


func _on_start_pressed() -> void:
	_start.disabled = true
	_start.visible = false
	var t := create_tween()
	t.tween_property(_letter, "position:y", get_viewport().get_visible_rect().size.y, slide_sec) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await t.finished
	finished.emit()
	queue_free()


func _pill(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(26)
	return box
