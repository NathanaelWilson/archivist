class_name CaseContainer
extends DeskProp

## The in-tray on the desk. Each new case lands in here instead of on the
## desk. Pressing the tray is enough: the case comes straight out and Main
## lays it in the middle of the desk — no dragging it out by hand.

## Emitted the moment the tray is pressed. from_position is where the paper
## leaves from (the tray's centre), so Main can slide it onto the desk.
signal case_pulled(case_data: CaseData, from_position: Vector2)

var _case: CaseData
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


func _on_press(_screen_position: Vector2) -> void:
	if _case == null:
		return
	var case_data := _case
	_case = null
	# The press is fully used up here; drop the gesture so the drag and
	# release that follow do nothing.
	cancel_touch()
	SFX.play(&"file_pickup")
	case_pulled.emit(case_data, get_global_center())


## Pressing already did everything; a tap on the tray has no second meaning.
func _on_release(_screen_position: Vector2) -> void:
	pass


## A small hop so the player notices something new has landed.
func _play_arrival() -> void:
	if _arrive_tween != null and _arrive_tween.is_valid():
		_arrive_tween.kill()
	offset = Vector2(0, -30)
	_arrive_tween = create_tween()
	_arrive_tween.tween_property(self, "offset", Vector2.ZERO, 0.3) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
