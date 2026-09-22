class_name RecordsScreen
extends Control

## The Record of Outcomes screen (the "Records" button's overlay). A book
## spread: the left page shows either the default title or whichever
## ending's line was last selected on the right page; the right page is a
## 3-then-1 grid of the four OutcomeSlot boxes plus the "{N} OF 4 FILED"
## count.

const DEFAULT_TITLE := "Record of Outcomes"

const ENDING_TITLES := {
	&"loyalist": "THE LOYALIST",
	&"liability": "THE LIABILITY",
	&"paranoid": "THE PARANOID",
	&"zealot": "THE ZEALOT",
}
const ENDING_LINES := {
	&"loyalist": "Careful. Obedient. Moved to the subject list.",
	&"liability": "Let things through. They are real now.",
	&"paranoid": "Removed what was never dangerous. Removed in turn.",
	&"zealot": "Covered everything. Kept nothing.",
}
const ENDING_COUNT := 4

@onready var left_title: Label = $BookSpread/Pages/LeftPage/Margin/Content/LeftTitle
@onready var left_body: Label = $BookSpread/Pages/LeftPage/Margin/Content/LeftBody
@onready var filed_count_label: Label = $BookSpread/Pages/RightPage/Margin/Content/FiledCountHeader
@onready var grid: GridContainer = $BookSpread/Pages/RightPage/Margin/Content/Grid

var _chosen_slot: OutcomeSlot = null


func _ready() -> void:
	for slot in grid.get_children():
		if slot is OutcomeSlot:
			slot.selected.connect(_on_slot_selected)


## Call whenever the screen is shown so it reflects the latest OutcomeRecord
## state and resets the left page back to the default title.
func refresh() -> void:
	left_title.text = DEFAULT_TITLE
	left_body.text = ""
	filed_count_label.text = "%d OF %d FILED" % [OutcomeRecord.get_filed_count(), ENDING_COUNT]
	if is_instance_valid(_chosen_slot):
		_chosen_slot.set_chosen(false)
	_chosen_slot = null
	for slot in grid.get_children():
		if slot is OutcomeSlot:
			slot.refresh()


func _on_slot_selected(ending_id: StringName, slot: OutcomeSlot) -> void:
	if is_instance_valid(_chosen_slot) and _chosen_slot != slot:
		_chosen_slot.set_chosen(false)
	_chosen_slot = slot
	slot.set_chosen(true)
	left_title.text = ENDING_TITLES.get(ending_id, DEFAULT_TITLE)
	left_body.text = ENDING_LINES.get(ending_id, "")
