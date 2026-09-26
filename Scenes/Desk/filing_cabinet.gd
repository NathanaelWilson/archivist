class_name FilingCabinet
extends DeskProp

## The filing cabinet on the right of the desk. Its art has one picture per
## state — all drawers shut, or one of the three pulled out — and this node
## swaps between them:
##   * while a file is carried over a drawer (FilingTray.set_hovered), that
##     drawer slides open to take it;
##   * with nothing in hand, a mouse hovering a drawer opens it too, as long
##     as the desk is free (Main's can_interact gate).
## A short close delay lets a filed paper finish flying in before the drawer
## shuts, and stops the art flickering when the pointer crosses the thin gap
## between two drawers.
##
## The three FilingTray children hold the drawer shapes, in this PNG's own
## pixels. The cabinet itself is never tapped (interactive = false); it only
## uses DeskProp for its alpha cut-off, which strips the tinted padding the
## Affinity slice carries around the cabinet.
##
## Open-drawer pictures only exist lit (no separate dark set — a drawer slid
## out in the dark shows lit for as long as it is out), but they DO come in
## a bloody flavor: Desk calls set_bloody() whenever the room's blood state
## changes, and open_textures_blood is used instead of open_textures for as
## long as it is bloody.

@export var closed_texture: Texture2D
## One per drawer, top to bottom — indexed by FilingTray.tray_type.
@export var open_textures: Array[Texture2D] = []
## Same, for the bloody room (storyboard p.9 onward). Falls back to
## open_textures if left empty.
@export var open_textures_blood: Array[Texture2D] = []
@export var close_delay_sec := 0.15
## The same four pictures (all shut, then drawers 1-3 out) for the other room
## states, made from the lit art so labels and edges match exactly. Desk
## picks the set with set_room(); the lit set is closed_texture/open_textures.
@export_group("Room states")
@export var dark_art: Array[Texture2D] = []
@export var bloody_art: Array[Texture2D] = []
@export var bloody_dark_art: Array[Texture2D] = []
@export_group("")

var _trays: Array[FilingTray] = []
## Silhouette for the shut picture when Desk swaps in a nearly opaque dark
## slice (Desk calls set_closed_art); open-drawer pictures never use it.
var _closed_silhouette: Texture2D
var _bloody := false
var _lit_closed: Texture2D
var _lit_open: Array[Texture2D] = []
var _mouse_tray: FilingTray
var _open_tray: FilingTray
var _close_timer := 0.0


func _ready() -> void:
	interactive = false
	_lit_closed = closed_texture
	_lit_open = open_textures.duplicate()
	if closed_texture != null:
		texture = closed_texture
	super()
	for child in get_children():
		if child is FilingTray:
			_trays.append(child)


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if event is InputEventMouseMotion and not PointerInput.is_emulated(event):
		_mouse_tray = FilingTray.tray_at(get_tree(), event.position)


func _process(delta: float) -> void:
	super(delta)
	var wanted := _wanted_tray()
	if wanted != null:
		_close_timer = close_delay_sec
		if wanted != _open_tray:
			_show_open(wanted)
	elif _open_tray != null:
		_close_timer -= delta
		if _close_timer <= 0.0:
			_show_open(null)


func _wanted_tray() -> FilingTray:
	for tray in _trays:
		if tray.is_hovered():
			return tray # a carried file is pointing at it
	if _mouse_tray != null and _desk_is_free():
		return _mouse_tray
	return null


func _desk_is_free() -> bool:
	return not can_interact.is_valid() or bool(can_interact.call())


func _show_open(tray: FilingTray) -> void:
	# Every swap to an open-drawer picture is a drawer sliding out, including
	# going straight from one drawer to the next; shutting is silent.
	if tray != null and tray != _open_tray:
		SFX.play(&"cabinet_open")
	_open_tray = tray
	var art := closed_texture
	var textures := open_textures_blood if _bloody and not open_textures_blood.is_empty() else open_textures
	if tray != null and tray.tray_type < textures.size() and textures[tray.tray_type] != null:
		art = textures[tray.tray_type]
	if art != null:
		texture = art
	for each in _trays:
		each.set_open(each == tray)


## Desk switches the room between lit/dark and clean/bloody. Every picture —
## shut and each drawer out — swaps to that state's set; an incomplete set
## falls back to the lit art.
func set_room(lights_on: bool, bloody: bool) -> void:
	var art_set: Array[Texture2D] = []
	if bloody:
		art_set = bloody_art if lights_on else bloody_dark_art
	elif not lights_on:
		art_set = dark_art
	if art_set.size() >= 4 and not art_set.has(null):
		closed_texture = art_set[0]
		open_textures = art_set.slice(1, 4)
	else:
		closed_texture = _lit_closed
		open_textures = _lit_open.duplicate()
	var art := closed_texture
	if _open_tray != null and _open_tray.tray_type < open_textures.size():
		art = open_textures[_open_tray.tray_type]
	if art != null:
		texture = art
