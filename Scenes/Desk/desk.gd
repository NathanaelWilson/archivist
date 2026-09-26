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

## --- Lights and blood -----------------------------------------------------
## The layered room above is the normal, lit, clean desk. The other states
## only exist as flat full-room paintings (background_off, background_*_blood,
## 4083 x 1750 like the layers), so in those states:
##   * Background shows the flat painting and RoomGrade is hidden;
##   * DeskFront shows the SAME painting, cut to the desk by layer2's
##     silhouette (desk_prop.gdshader's mask), so the desk still sits in
##     front of the cabinet;
##   * the flat paintings have no lamp, so the Lamp sprite is shown on top
##     (lamp_on/off), and in the bloody ones the fax has blood painted over
##     it, so a clean Fax (fax_on/off.png) is laid back on top — the blood is
##     on the desk, under the things standing on it;
##   * the cabinet's shut picture swaps to cabinet_off / cabinet_*_blood.
##     Its open-drawer pictures only exist lit, so a drawer slid out in the
##     dark shows lit for as long as it is out.
## The case tray and clipboard swap to their *_off slices in the dark.
@export_group("Lights and blood")
@export var layer1: Texture2D
@export var layer2: Texture2D
@export var background_on: Texture2D
@export var background_off: Texture2D
@export var background_on_blood: Texture2D
@export var background_off_blood: Texture2D
@export var lamp_on: Texture2D
@export var lamp_off: Texture2D
## The layered room's own cabinet picture (all drawers shut, lit, clean).
@export var cabinet_closed: Texture2D
## Silhouette source for the dark cabinet slices, which are nearly opaque.
@export var cabinet_on: Texture2D
@export var cabinet_off: Texture2D
@export var cabinet_on_blood: Texture2D
@export var cabinet_off_blood: Texture2D
@export var container_on: Texture2D
@export var container_off: Texture2D
@export var clipboard_on: Texture2D
@export var clipboard_off: Texture2D
@export var fax_on: Texture2D
@export var fax_off: Texture2D
@export_group("")

var lights_on := true
var bloody := false


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


## Switches the room between lit and dark (the flicker on cases 8 and 11).
func set_lights(on: bool) -> void:
	lights_on = on
	_apply_state()


## Puts the blood in the room (storyboard p.9, low-Accuracy path). Independent
## of the lights, so a bloody room still flickers into a bloody dark room.
func set_bloody(value: bool) -> void:
	bloody = value
	_apply_state()


func _apply_state() -> void:
	var on := lights_on
	var layered := on and not bloody
	var room: Texture2D = layer1
	if not layered:
		if bloody:
			room = background_on_blood if on else background_off_blood
		else:
			room = background_off

	$Background.texture = room
	$RoomGrade.visible = layered
	_set_mask(desk_front, not layered, layer2)
	desk_front.texture = layer2 if layered else room

	$Lamp.visible = not layered
	_set_art($Lamp, lamp_on if on else lamp_off, null if on else lamp_on)
	# The fax is always drawn on top: it is the FaxMachine the player taps for
	# filing reports, and in the bloody rooms it keeps the blood underneath.
	_set_art($Fax, fax_on if on else fax_off, null)

	var shut: Texture2D = cabinet_closed
	if bloody:
		shut = cabinet_on_blood if on else cabinet_off_blood
	elif not on:
		shut = cabinet_off
	cabinet.set_closed_art(shut, null if on else cabinet_on)

	_set_art($CaseContainer, container_on if on else container_off, null if on else container_on)
	_set_art($Clipboard, clipboard_on if on else clipboard_off, null if on else clipboard_on)


## Sets a sprite's picture. silhouette, when given, is the lit slice whose
## alpha cuts the (nearly opaque) dark slice to the object's shape.
func _set_art(sprite: Sprite2D, art: Texture2D, silhouette: Texture2D) -> void:
	if sprite == null or art == null:
		return
	sprite.texture = art
	_set_mask(sprite, silhouette != null, silhouette)


func _set_mask(sprite: Sprite2D, enabled: bool, silhouette: Texture2D) -> void:
	var shader_material := sprite.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("use_mask", enabled)
	shader_material.set_shader_parameter("mask_texture", silhouette)
