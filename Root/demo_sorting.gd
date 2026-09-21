extends Node2D

## Standalone test bed for the sorting mechanic — not part of the real
## desk flow (that's DEV-06/DEV-11's job to build against case data and
## the shift script). Run this scene directly (F6) to try: quick flick =
## ink, press-and-hold-then-drag = pick up, drop on a tray = file.

const FileEntityScene := preload("res://Scenes/file_entity.tscn")
const TrayScene := preload("res://Scenes/filing_tray.tscn")


func _ready() -> void:
	_spawn_tray(FilingTray.TrayType.PUBLIC_ARCHIVE, Vector2(900, 180))
	_spawn_tray(FilingTray.TrayType.DEPARTMENT_OF_TRUTH, Vector2(900, 380))
	_spawn_tray(FilingTray.TrayType.INCINERATOR, Vector2(900, 580))
	_spawn_file()


func _spawn_tray(type: FilingTray.TrayType, pos: Vector2) -> void:
	var tray: FilingTray = TrayScene.instantiate()
	tray.tray_type = type
	tray.position = pos
	add_child(tray)


func _spawn_file() -> void:
	var file: FileEntity = FileEntityScene.instantiate()
	file.position = Vector2(350, 380)

	var data := CaseData.new()
	data.id = "case_demo"
	data.level = CaseData.Level.WRONG
	# One placeholder anomaly box near the top of the paper, image-local space.
	data.hidden_boxes = [Rect2(-100, -350, 200, 120)]
	file.case_data = data

	add_child(file)
	file.filed.connect(func(tray_type: int) -> void:
		print("Filed into tray: ", FilingTray.TrayType.keys()[tray_type])
	)
	file.stroke_scored.connect(func(result: Dictionary) -> void:
		print("Stroke scored: ", result)
	)
