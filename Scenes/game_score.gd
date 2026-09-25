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

## --- Thresholds (GDD "The Four Endings > Scoring") ----------------------
## Accuracy is out of 15 across the full run; Paranoia has no cap.
@export var accuracy_threshold: int = 10
@export var paranoia_threshold: int = 6

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


## Call once per filed case (main.gd does this from _on_file_filed). The GDD's
## scoring, rule for rule:
##
##   ACCURACY — out of 15.
##     Level-1 cases (1, 2, 6, 7, 8): +1 for covering the anomaly, +1 for the
##       right drawer = 10. The drawer point needs the cover too: filing an
##       uncovered anomaly in the right drawer is still passing it on
##       unhandled. Without this, a player who never touches the paper would
##       file everything "correctly" and reach exactly 10 — The Loyalist — and
##       doing nothing must not score well.
##     Clean cases (3, 4, 10): +1 for the right drawer = 3.
##     Case 5 (Department of Truth), Case 9 (Incinerator): +1 each = 2.
##     Case 12 (ANY): no drawer is right or wrong — worth nothing either way.
##
##   PARANOIA — no cap.
##     +1 if any stroke on this case landed entirely on clean paper (a stroke
##       touching neither the anomaly nor its safe zone). Counted once per
##       case, however many such strokes, so a scribbler cannot run it up.
##     +2 for burning something harmless: incinerating a document that
##       belongs in the Public Archive.
func register_case_result(case_data: CaseData, tray_type: int, redaction_result: Dictionary) -> void:
	var tray_matters: bool = not FilingTray.is_wildcard(case_data.correct_tray)
	var right_drawer: bool = tray_matters and tray_type == case_data.correct_tray
	var needs_cover: bool = case_data.level == CaseData.Level.WRONG
	var covered: bool = needs_cover and bool(redaction_result.get("is_valid", false))

	# --- Accuracy
	if needs_cover:
		if covered:
			add_accuracy(1)
			if right_drawer:
				add_accuracy(1)
	elif right_drawer:
		add_accuracy(1)

	# --- Paranoia
	if bool(redaction_result.get("stray_stroke", false)):
		add_paranoia(1)
	var harmless: bool = case_data.correct_tray == FilingTray.TrayType.PUBLIC_ARCHIVE
	if harmless and tray_type == FilingTray.TrayType.INCINERATOR:
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
