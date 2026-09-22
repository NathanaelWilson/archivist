extends Node

## Autoload singleton ("GameScore") — the running Accuracy/Paranoia tally for
## the current playthrough, plus the criteria that pick one of the Record of
## Outcomes' four endings (GDD: "The Four Endings").
##
## For the gameplay/tech dev: main.gd already calls register_case_result()
## once per filed case. Read `accuracy` / `paranoia` directly for any HUD or
## debug display, listen to `score_changed` to react live, and call
## evaluate_ending() once the run is over to get back one of the four
## ENDING_* ids below.

signal score_changed(accuracy: int, paranoia: int)

## --- Placeholder thresholds -------------------------------------------------
## The GDD's real numbers ("The Four Endings > Scoring") are tuned for the
## full 12-case game: Accuracy >= 10, Paranoia >= 6. Only case_01 + case_02
## exist right now (Shift 1), so those numbers can never be reached — these
## two are a stand-in scaled for testing with just that shift.
## TODO(design/tech): replace with 10 / 6 once all 12 cases are wired into
## shifts, or move to a formula that scales with cases-played if partial
## testing still needs to work after that.
@export var accuracy_threshold: int = 3
@export var paranoia_threshold: int = 2

var accuracy: int = 0
var paranoia: int = 0

const ENDING_LOYALIST := &"loyalist"
const ENDING_LIABILITY := &"liability"
const ENDING_PARANOID := &"paranoid"
const ENDING_ZEALOT := &"zealot"

const ENDING_DISPLAY_NAMES := {
	ENDING_LOYALIST: "The Loyalist",
	ENDING_LIABILITY: "The Liability",
	ENDING_PARANOID: "The Paranoid",
	ENDING_ZEALOT: "The Zealot",
}


func reset() -> void:
	accuracy = 0
	paranoia = 0
	score_changed.emit(accuracy, paranoia)


func add_accuracy(amount: int = 1) -> void:
	accuracy += amount
	score_changed.emit(accuracy, paranoia)


func add_paranoia(amount: int = 1) -> void:
	paranoia += amount
	score_changed.emit(accuracy, paranoia)


## Call once per filed case (main.gd does this from _on_file_filed, right
## where it already has tray_type + redaction_result). Mirrors the GDD's
## scoring rules 1:1 so the numbers stay meaningful as more cases come online:
##   Accuracy — +1 for the right drawer, +1 more for correctly covering an
##              actual anomaly (a clean case only ever earns the drawer point).
##   Paranoia — +1 per case where any ink landed outside the anomaly/safe
##              zones, +2 extra for incinerating a case that was clean all along.
func register_case_result(case_data: CaseData, tray_type: int, redaction_result: Dictionary) -> void:
	var correct_tray: bool = tray_type == case_data.correct_tray
	var redaction_passed: bool = bool(redaction_result.get("is_valid", false))
	var overspill: float = float(redaction_result.get("overspill", 0.0))

	if correct_tray:
		add_accuracy(1)
	if case_data.level == CaseData.Level.WRONG and redaction_passed:
		add_accuracy(1)

	if overspill > 0.0:
		add_paranoia(1)
	if case_data.level == CaseData.Level.CLEAN and tray_type == FilingTray.TrayType.INCINERATOR:
		add_paranoia(2)


## Reads top-to-bottom exactly like the GDD's table — Zealot is checked first
## because it overlaps both single-axis endings.
func evaluate_ending() -> StringName:
	if paranoia >= paranoia_threshold and accuracy >= accuracy_threshold:
		return ENDING_ZEALOT
	if paranoia >= paranoia_threshold:
		return ENDING_PARANOID
	if accuracy >= accuracy_threshold:
		return ENDING_LOYALIST
	return ENDING_LIABILITY


func get_display_name(ending_id: StringName) -> String:
	return ENDING_DISPLAY_NAMES.get(ending_id, "Unknown Ending")
