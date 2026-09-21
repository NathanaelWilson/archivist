class_name CaseData
extends Resource

## The data shape a "case" is, per DES-01 in the Task Board. Everything the
## desk needs to spawn, render, ink-check and file a document lives here —
## nothing downstream (FileEntity, the tray, the scorer) should need to
## special-case a specific case by id.

enum DocType { PORTRAIT, FORM, RECORD_SHEET }
enum Level { CLEAN, WRONG } ## CLEAN = correct as-is; WRONG = has an anomaly to cover

@export var id: String = ""
@export var doc_type: DocType = DocType.PORTRAIT
@export var level: Level = Level.WRONG
@export var correct_tray: FilingTray.TrayType = FilingTray.TrayType.PUBLIC_ARCHIVE

## Anomaly regions in image-local pixel space (RedactionLayer.IMG_SIZE),
## authored as placeholders in DES-02, refined once art is final in DES-07.
@export var hidden_boxes: Array[Rect2] = []

@export var asset: Texture2D
## Optional "settled" swap texture — the slide-in/settle dread beat.
@export var settle_asset: Texture2D

@export var slip_id: String = "" ## "" = draw from the general slip pool
@export var live_number_slot: String = "" ## e.g. "files_handled" for Case 10
@export var clipboard_board_id: String = "" ## which board should be showing
