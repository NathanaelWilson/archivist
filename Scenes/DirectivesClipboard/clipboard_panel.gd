class_name ClipboardPanel
extends CanvasLayer

## The rules clipboard on the desk. At rest it is the clipboard art on the
## desk itself (Main opens this when that prop is tapped); lifting it shows
## whichever ClipboardBoard is live right now, over a dimmed desk — tapping
## anywhere off the board puts it back down. The old "CLIPBOARD" Handle
## button is kept in the scene but hidden, as a fallback.
## The panel does not decide which board that is — Main does, through
## board_source — so the boards can swap silently mid-shift.

## Callable returning the live ClipboardBoard (Main.get_active_board).
var board_source: Callable = Callable()

## Board C's notice counts how many files have gone by since the player last
## lifted the clipboard; "{N}" in notice_text is replaced with that number.
var _files_at_last_read: int = -1

@onready var handle: Button = $Handle
@onready var dim: ColorRect = $Dim
@onready var panel: Control = $Board
@onready var notice: Label = $Board/Margin/Content/Notice
@onready var cover_heading: Label = $Board/Margin/Content/CoverHeading
@onready var cover_lines: Label = $Board/Margin/Content/CoverLines
@onready var file_heading: Label = $Board/Margin/Content/FileHeading
@onready var file_lines: Label = $Board/Margin/Content/FileLines


func _ready() -> void:
	handle.pressed.connect(toggle)
	dim.gui_input.connect(_on_dim_input)
	panel.visible = false
	dim.visible = false


func is_open() -> bool:
	return panel.visible


## Locked while the eyes are opening or closing: the tab cannot be pressed,
## and a board left open is put down.
func set_interactive(enabled: bool) -> void:
	handle.disabled = not enabled
	if not enabled:
		close()


func toggle() -> void:
	if panel.visible:
		close()
	else:
		open()


func open() -> void:
	var board := _current_board()
	if board == null:
		return
	_render(board)
	panel.visible = true
	dim.visible = true
	handle.text = "PUT DOWN"
	SFX.play(&"page_flip")
	_files_at_last_read = FilingLog.total_filed


func close() -> void:
	panel.visible = false
	dim.visible = false
	handle.text = "CLIPBOARD"


func _current_board() -> ClipboardBoard:
	if not board_source.is_valid():
		push_warning("ClipboardPanel has no board_source; Main should set it.")
		return null
	return board_source.call() as ClipboardBoard


func _render(board: ClipboardBoard) -> void:
	notice.text = _fill_notice(board.notice_text)
	cover_heading.text = "WHAT TO COVER"
	cover_lines.text = "\n".join(board.cover_lines)
	file_heading.text = "WHERE IT GOES"
	file_lines.text = "\n".join(board.file_lines)


## Substitutes "{N}" with the number of files filed since the last read.
## Before the first read there is no count yet, so that line is dropped.
func _fill_notice(text: String) -> String:
	if not text.contains("{N}"):
		return text
	if _files_at_last_read < 0:
		var lines := text.split("\n")
		var kept: Array[String] = []
		for line in lines:
			if not line.contains("{N}"):
				kept.append(line)
		return "\n".join(kept)
	return text.replace("{N}", str(FilingLog.total_filed - _files_at_last_read))


## A tap anywhere off the board puts the clipboard down. Controls get touch as
## emulated mouse clicks, so this one check covers phone and desktop.
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
		dim.accept_event()
