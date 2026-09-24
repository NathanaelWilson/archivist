class_name CaseContainer
extends DeskProp

## The in-tray on the desk. Each new case lands in here instead of on the
## desk; the player presses on the tray and drags the top paper out. Letting
## go once the paper is clear of the tray hands the case to Main (which lays
## it on the desk and opens the case preview). Letting go over the tray, or
## before it has travelled pull_distance, slides the paper back in.

signal case_pulled(case_data: CaseData, screen_position: Vector2)

## How far (viewport pixels) the paper has to travel from where it was
## grabbed before letting go counts as pulling it out.
@export var pull_distance := 40.0
@export var max_tilt_deg := 8.0
@export var paper_color := Color(0.906, 0.890, 0.827, 1.0)
@export var paper_edge_color := Color(0.22, 0.2, 0.17, 1.0)
## On-screen size of the paper while it is being pulled. Main sets this to
## the desk file's size so the hand-off is seamless.
@export var pulled_paper_size := Vector2(68, 137)

var _case: CaseData
var _paper: Node2D
var _paper_tween: Tween
var _arrive_tween: Tween


func has_case() -> bool:
	return _case != null


## A new case arrives in the tray.
func load_case(case_data: CaseData) -> void:
	_case = case_data
	_play_arrival()


func clear_case() -> void:
	_case = null
	cancel_touch()


func _accepts_input() -> bool:
	return _case != null


func _on_press(screen_position: Vector2) -> void:
	_discard_paper()
	_paper = _make_paper()
	add_child(_paper)
	_paper.global_position = get_global_center()
	_paper_tween = create_tween()
	_paper_tween.tween_property(_paper, "global_position", screen_position, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	SFX.play(&"file_pickup")


func _on_drag(screen_position: Vector2) -> void:
	if not is_instance_valid(_paper):
		return
	if _paper_tween != null and _paper_tween.is_valid():
		_paper_tween.kill()
	_paper.global_position = screen_position
	var tilt_t := clampf((screen_position.x - _press_position.x) / 300.0, -1.0, 1.0)
	_paper.rotation = deg_to_rad(max_tilt_deg) * tilt_t


func _on_release(screen_position: Vector2) -> void:
	var pulled_out := screen_position.distance_to(_press_position) >= pull_distance \
		and not contains_point(screen_position)
	if pulled_out and _case != null:
		var case_data := _case
		_case = null
		_discard_paper()
		case_pulled.emit(case_data, screen_position)
	else:
		_slide_paper_back()


func _on_touch_cancelled() -> void:
	_slide_paper_back()


func _slide_paper_back() -> void:
	if not is_instance_valid(_paper):
		return
	SFX.play(&"file_return")
	var paper := _paper
	_paper = null
	if _paper_tween != null and _paper_tween.is_valid():
		_paper_tween.kill()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(paper, "global_position", get_global_center(), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(paper, "rotation", 0.0, 0.14)
	tw.tween_property(paper, "modulate:a", 0.0, 0.14)
	tw.chain().tween_callback(paper.queue_free)


func _discard_paper() -> void:
	if _paper_tween != null and _paper_tween.is_valid():
		_paper_tween.kill()
	if is_instance_valid(_paper):
		_paper.queue_free()
	_paper = null


## A plain paper that follows the finger. It is top_level so it ignores the
## desk's scale and is placed in viewport pixels, like the desk files.
func _make_paper() -> Node2D:
	var paper := Node2D.new()
	paper.top_level = true
	paper.z_index = 60
	var edge := ColorRect.new()
	edge.color = paper_edge_color
	edge.size = pulled_paper_size + Vector2(2, 2)
	edge.position = -edge.size * 0.5
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(edge)
	var fill := ColorRect.new()
	fill.color = paper_color
	fill.size = pulled_paper_size
	fill.position = -fill.size * 0.5
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(fill)
	return paper


## A small hop so the player notices something new has landed.
func _play_arrival() -> void:
	if _arrive_tween != null and _arrive_tween.is_valid():
		_arrive_tween.kill()
	offset = Vector2(0, -30)
	_arrive_tween = create_tween()
	_arrive_tween.tween_property(self, "offset", Vector2.ZERO, 0.3) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
