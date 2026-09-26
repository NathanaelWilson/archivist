class_name DragHint
extends Node2D

## Case 1 tutorial: a dashed arrow from the envelope on the desk to the drawer
## it belongs in, with a fingertip dot travelling along it — the "hold and
## drag it here" gesture. Main adds it as its own child, so it moves with the
## desk (DeskParallax) like the envelope and cabinet do.

@export var travel_sec := 1.6
@export var color := Color(1.0, 0.93, 0.75, 0.95)
@export var dash_length := 9.0
@export var width := 3.0
## How high the arrow bows above the straight line, as a share of its length.
@export var arc_height := 0.22

var _from_node: Node2D
var _from_offset := Vector2.ZERO
var _to_global := Vector2.ZERO
var _time := 0.0


## from_node is the envelope (followed live, so parallax and nudges are
## respected); to_global is the drawer's drop point.
func point(from_node: Node2D, to_global: Vector2, from_offset := Vector2.ZERO) -> void:
	_from_node = from_node
	_to_global = to_global
	_from_offset = from_offset
	_time = 0.0
	visible = true
	set_process(true)


func hide_hint() -> void:
	visible = false
	set_process(false)


func _ready() -> void:
	z_index = 90 # above the desk and files at rest, under a file being carried
	hide_hint()


func _process(delta: float) -> void:
	if not is_instance_valid(_from_node):
		hide_hint()
		return
	_time = fmod(_time + delta, travel_sec + 0.5)
	queue_redraw()


func _curve_point(a: Vector2, b: Vector2, t: float) -> Vector2:
	var mid := (a + b) * 0.5
	var normal := (b - a).orthogonal().normalized()
	if normal.y > 0.0:
		normal = -normal # always bow upwards
	var control := mid + normal * a.distance_to(b) * arc_height
	return a.lerp(control, t).lerp(control.lerp(b, t), t)


func _draw() -> void:
	if not is_instance_valid(_from_node):
		return
	var a := to_local(_from_node.global_position + _from_offset)
	var b := to_local(_to_global)
	var steps := 40
	var points := PackedVector2Array()
	for i in steps + 1:
		points.append(_curve_point(a, b, float(i) / steps))

	# Dashes crawl toward the drawer.
	var crawl := fmod(_time * 30.0, dash_length * 2.0)
	var walked := -crawl
	for i in steps:
		var p0 := points[i]
		var p1 := points[i + 1]
		var seg := p0.distance_to(p1)
		if fmod(walked + dash_length * 100.0, dash_length * 2.0) < dash_length:
			draw_line(p0, p1, color, width, true)
		walked += seg

	# Arrowhead at the drawer.
	var tail := points[steps - 2]
	var dir := (b - tail).normalized()
	var side := dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([b + dir * 4.0, b - dir * 12.0 + side * 8.0, b - dir * 12.0 - side * 8.0]), color)

	# Fingertip travelling from the envelope to the drawer.
	var t := clampf(_time / travel_sec, 0.0, 1.0)
	var fade := 1.0 - clampf((_time - travel_sec) / 0.5, 0.0, 1.0)
	var tip := _curve_point(a, b, ease(t, -1.6))
	draw_circle(tip, 7.0, Color(1, 1, 1, 0.9 * fade))
	draw_arc(tip, 11.0, 0.0, TAU, 24, Color(1, 1, 1, 0.35 * fade), 2.0, true)
