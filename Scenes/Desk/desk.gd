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
## Shows the drawers' live touch areas while playing (cyan = shut shape,
## orange = the open shape of the drawer that is out). They are always
## visible in the editor.
@export var debug_show_drawer_areas := false

## Layer order, back to front (MAIN.psd's layers):
##   Background — background_layer1.jpg, the wall and floor;
##   RoomGrade  — background_on_layer2.png as exported: the desk plus the
##                dark grade the slice carries over the rest of the room;
##   Cabinet    — the filing cabinet, padding cut off, so the grade darkens
##                the wall behind it but not the cabinet itself;
##   DeskFront  — background_on_layer2.png again, cut to just the desk, so
##                the desk's corner sits in front of the cabinet;
##   then the case tray and the clipboard on top.
@onready var cabinet: FilingCabinet = $Cabinet
@onready var desk_front: DeskProp = $DeskFront


func _ready() -> void:
	get_viewport().size_changed.connect(fit_to_viewport)
	fit_to_viewport()
	# The desk top is drawn over the bottom-left of the cabinet; a drop
	# there is on the desk, not in the Incinerator.
	for child in cabinet.get_children():
		if child is FilingTray:
			child.is_occluded = desk_front.contains_point
			child.debug_show_areas = debug_show_drawer_areas


func fit_to_viewport() -> void:
	var view := get_viewport_rect().size
	var fit := maxf(view.x / design_size.x, view.y / design_size.y)
	scale = Vector2(fit, fit)
	position = (view - design_size * fit) * 0.5
