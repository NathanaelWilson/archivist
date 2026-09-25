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

@export var closed_texture: Texture2D
## One per drawer, top to bottom — indexed by FilingTray.tray_type.
@export var open_textures: Array[Texture2D] = []
@export var close_delay_sec := 0.15

var _trays: Array[FilingTray] = []
## Silhouette for the shut picture when Desk swaps in a nearly opaque dark
## slice (Desk calls set_closed_art); open-drawer pictures never use it.
var _closed_silhouette: Texture2D
var _mouse_tray: FilingTray
var _open_tray: FilingTray
var _close_timer := 0.0


func _ready() -> void:
	interactive = false
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
	if tray != null and tray.tray_type < open_textures.size() and open_textures[tray.tray_type] != null:
		art = open_textures[tray.tray_type]
	if art != null:
		texture = art
	_apply_silhouette(tray == null)
	for each in _trays:
		each.set_open(each == tray)


## Desk swaps the shut-cabinet picture for the dark and bloody rooms. The
## open-drawer pictures only exist lit, so they are left as they are.
func set_closed_art(art: Texture2D, silhouette: Texture2D) -> void:
	if art == null:
		return
	closed_texture = art
	_closed_silhouette = silhouette
	if _open_tray == null:
		texture = art
		_apply_silhouette(true)


func _apply_silhouette(showing_closed: bool) -> void:
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	var use := showing_closed and _closed_silhouette != null
	shader_material.set_shader_parameter("use_mask", use)
	shader_material.set_shader_parameter("mask_texture", _closed_silhouette if use else null)
