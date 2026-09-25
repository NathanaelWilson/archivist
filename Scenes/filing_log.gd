extends Node

## Autoload singleton ("FilingLog") — the neutral, raw fact tracker for
## every filed case in the current run. Counts correct/incorrect redaction
## and correct/incorrect tray as two independent booleans (a case can be
## inked right but filed in the wrong drawer, or vice versa), plus a
## per-case history for a future debug HUD and for QA/tuning.
##
## This is deliberately NOT GameScore. GameScore assigns meaning — it
## turns these same events into an asymmetric Accuracy/Paranoia tally that
## picks the ending. FilingLog assigns none: it just records what happened,
## the way RedactionLayer reports coverage/overspill without deciding
## whether they passed. Anything that wants to *interpret* a filing should
## read GameScore; anything that wants to *inspect* one should read this.

signal filing_recorded(case_data: CaseData, tray_type: int, redaction_result: Dictionary)

## Running totals for the current run. Reset by reset() — unlike
## OutcomeRecord, nothing here is saved to disk.
var total_filed: int = 0
var redaction_correct: int = 0
var redaction_incorrect: int = 0
var tray_correct: int = 0
var tray_incorrect: int = 0

## One entry per filing, in order. Keys:
##   case_id            String          the CaseData id
##   case_index         int             running index at time of filing (0-based)
##   tray_chosen        int             the FilingTray.TrayType actually used
##   tray_expected      int             case_data.correct_tray
##   tray_correct       bool
##   tray_wildcard      bool            true when any tray was acceptable
##   redaction_result   Dictionary      the full result dict from RedactionLayer
##   redaction_correct  bool
var entries: Array[Dictionary] = []


func reset() -> void:
	total_filed = 0
	redaction_correct = 0
	redaction_incorrect = 0
	tray_correct = 0
	tray_incorrect = 0
	entries.clear()


## Called once per filed case from main.gd::_on_file_filed(), alongside —
## not instead of — GameScore.register_case_result().
func record_filing(case_data: CaseData, tray_type: int, redaction_result: Dictionary) -> void:
	# A wildcard case (correct_tray = ANY) can never be filed wrongly.
	var tray_is_wildcard: bool = FilingTray.is_wildcard(case_data.correct_tray)
	var tray_is_correct: bool = tray_is_wildcard or tray_type == case_data.correct_tray
	var redaction_is_correct: bool = bool(redaction_result.get("is_valid", false))

	total_filed += 1
	if redaction_is_correct:
		redaction_correct += 1
	else:
		redaction_incorrect += 1
	if tray_is_correct:
		tray_correct += 1
	else:
		tray_incorrect += 1

	entries.append({
		"case_id": case_data.id,
		"case_index": total_filed - 1,
		"tray_chosen": tray_type,
		"tray_expected": case_data.correct_tray,
		"tray_correct": tray_is_correct,
		"tray_wildcard": tray_is_wildcard,
		"redaction_result": redaction_result,
		"redaction_correct": redaction_is_correct,
	})

	filing_recorded.emit(case_data, tray_type, redaction_result)
