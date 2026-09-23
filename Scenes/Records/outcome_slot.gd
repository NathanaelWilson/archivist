class_name OutcomeSlot
extends VBoxContainer

## One box in the Record of Outcomes' grid. The art itself (Assets/Agents/)
## already encodes every state as a full square tile — <ending>_<locked or
## unlocked>_<default or selected>.svg — so this script's only job is to
## pick the right file and gate clicking behind OutcomeRecord.
##
## "selected" art shows for hovering (a live preview) AND for whichever slot
## was last actually clicked (a persistent choice, cleared by RecordsScreen
## whenever a different slot is chosen or the screen is reopened). A locked
## slot can be hovered like any other, but its Button is disabled, so
## clicking it never fires `selected` and the left page never updates.

signal selected(ending_id: StringName, slot: OutcomeSlot)

@export var ending_id: StringName = &""

const ICON_PATH_FORMAT := "res://Assets/Agents/%s_%s_%s.svg"

@onready var icon: TextureRect = $Icon
@onready var button: Button = $Icon/Button
@onready var status_label: Label = $StatusLabel

var _is_hovering: bool = false
var _is_chosen: bool = false ## only ever true while unlocked


func _ready() -> void:
	button.pressed.connect(func():
		SFX.play(&"slot_select")
		selected.emit(ending_id, self)
	)
	# A locked slot's Button is disabled, so `pressed` never fires — but it
	# still receives raw input, which is where the "locked" error sound comes from.
	button.gui_input.connect(_on_button_gui_input)
	button.mouse_entered.connect(func(): _set_hovering(true))
	button.mouse_exited.connect(func(): _set_hovering(false))
	refresh()


## Call whenever the Records screen is (re)opened so this slot reflects the
## latest OutcomeRecord state.
func refresh() -> void:
	var filed := OutcomeRecord.is_filed(ending_id)
	button.disabled = not filed
	status_label.text = ("FILED %s" % OutcomeRecord.get_filed_date(ending_id)) if filed else "NOT YET FILED"
	if not filed:
		_is_chosen = false
	_update_icon()


func _on_button_gui_input(event: InputEvent) -> void:
	if not button.disabled:
		return
	# Handles a real finger and a debug mouse click, once each.
	if PointerInput.press_position(event) != null:
		SFX.play(&"slot_locked")


## Called by RecordsScreen so only one slot at a time reads as "chosen".
func set_chosen(chosen: bool) -> void:
	_is_chosen = chosen
	_update_icon()


func _set_hovering(hovering: bool) -> void:
	_is_hovering = hovering
	_update_icon()


func _update_icon() -> void:
	var lock_token := "unlocked" if OutcomeRecord.is_filed(ending_id) else "locked"
	var select_token := "selected" if (_is_hovering or _is_chosen) else "default"
	icon.texture = load(ICON_PATH_FORMAT % [ending_id, lock_token, select_token])
