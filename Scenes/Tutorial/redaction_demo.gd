class_name RedactionDemo
extends Node2D

## Case 1 tutorial: a "ghost" marker that shows how to cover the anomaly.
## Drawn as a child of DocumentViewer's Document node, so (0, 0) is the centre
## of the page. It reads the anomaly straight from CaseData, so it always sits
## on whatever the case marks as wrong (on Case 1: the third eye).
##
## One loop: a pulsing ring points at the spot, then a translucent ink bar is
## swept across it left-to-right with a fingertip dot leading, then it fades.

@export var loop_sec := 2.2
@export var ring_color := Color(1.0, 0.86, 0.35, 0.95)
@export var ink_color := Color(0.0, 0.0, 0.0, 0.55)
@export var finger_color := Color(1.0, 1.0, 1.0, 0.9)
## Tiny anomalies are hard to see; the demo never draws smaller than this.
@export var min_size := Vector2(34.0, 18.0)

var _target := Rect2()
var _time := 0.0


## Aims the demo at the case's first anomaly region, on a page drawn at
## document_size (DocumentViewer's on-screen size for the page).
func aim(case_data: CaseData, document_size: Vector2) -> bool:
	if case_data == null or case_data.anomaly_regions.is_empty():
		return false
	var region: Rect2 = case_data.anomaly_regions[0]
	var rect := Rect2(-document_size * 0.5 + region.position * document_size, region.size * document_size)
	var grown := Vector2(maxf(rect.size.x, min_size.x), maxf(rect.size.y, min_size.y))
	_target = Rect2(rect.get_center() - grown * 0.5, grown)
	return true


func play() -> void:
	_time = 0.0
	visible = true
	set_process(true)


func stop() -> void:
	visible = false
	set_process(false)


func _ready() -> void:
	z_index = 50
	stop()


func _process(delta: float) -> void:
	_time = fmod(_time + delta, loop_sec)
	queue_redraw()


func _draw() -> void:
	var t := _time / loop_sec
	var center := _target.get_center()

	# 0.00–0.30: ring pulses in to point at the spot.
	var ring_t := clampf(t / 0.30, 0.0, 1.0)
	var ring_radius := lerpf(_target.size.x * 1.6, _target.size.x * 0.75, ease(ring_t, -2.0))
	var ring_alpha := ring_color.a * (1.0 - clampf((t - 0.75) / 0.25, 0.0, 1.0))
	draw_arc(center, ring_radius, 0.0, TAU, 48, Color(ring_color, ring_alpha), 2.0, true)

	# 0.30–0.75: the marker sweeps across, left to right.
	var sweep := clampf((t - 0.30) / 0.45, 0.0, 1.0)
	var fade := 1.0 - clampf((t - 0.80) / 0.20, 0.0, 1.0)
	if sweep > 0.0:
		var bar := Rect2(_target.position, Vector2(_target.size.x * sweep, _target.size.y))
		draw_rect(bar, Color(ink_color, ink_color.a * fade))
		var tip := Vector2(bar.end.x, center.y)
		if sweep < 1.0:
			draw_circle(tip, 6.0, Color(finger_color, finger_color.a * fade))
			draw_arc(tip, 9.0, 0.0, TAU, 24, Color(finger_color, 0.35 * fade), 1.5, true)
