class_name Desk
extends Node2D

## The on-shift desk: the background plate plus every touchable prop on it.
##
## Children are positioned in the SOURCE ART's pixel space (MAIN.psd, 4083 x
## 1750), so a prop's position is simply its slice's top-left corner from
## Affinity — e.g. the case tray's slice starts at (1494, 414). This node then
## scales the whole desk to cover the viewport (cropping the sides a little,
## since the art is wider than the game's 874 x 402), exactly like the main
## menu's background does, so props always land on the same spot of the
## painted desk whatever the window size.

## Size of the art the children are laid out in.
@export var design_size := Vector2(4083, 1750)


func _ready() -> void:
	get_viewport().size_changed.connect(fit_to_viewport)
	fit_to_viewport()


func fit_to_viewport() -> void:
	var view := get_viewport_rect().size
	var fit := maxf(view.x / design_size.x, view.y / design_size.y)
	scale = Vector2(fit, fit)
	position = (view - design_size * fit) * 0.5
