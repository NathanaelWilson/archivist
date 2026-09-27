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
@onready var notice: Label = $Board/Margin/Content/Page1/Notice
@onready var cover_heading: Label = $Board/Margin/Content/Page1/CoverHeading
@onready var cover_lines: Label = $Board/Margin/Content/Page1/CoverLines
@onready var file_heading: Label = $Board/Margin/Content/Page2/FileHeading
@onready var file_lines: Label = $Board/Margin/Content/Page2/FileLines

# New Page Control Nodes
@onready var page1: VBoxContainer = $Board/Margin/Content/Page1
@onready var page2: VBoxContainer = $Board/Margin/Content/Page2
@onready var next_button: Button = $Board/Margin/Content/Page1/NextButton
@onready var back_button: Button = $Board/Margin/Content/Page2/BackButton


func _ready() -> void:
	handle.pressed.connect(toggle)
	dim.gui_input.connect(_on_dim_input)
	panel.visible = false
	dim.visible = false
	
	# Connect the page buttons
	next_button.pressed.connect(_show_page.bind(2))
	back_button.pressed.connect(_show_page.bind(1))
	
	# Start on page 1
	_show_page(1)


func _show_page(page_number: int) -> void:
	page1.visible = (page_number == 1)
	page2.visible = (page_number == 2)
	SFX.play(&"page_flip") # Reuse your existing sound!


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


## Built on first render from the scene's own labels, so they share their
## font, size and colour: the board's free text, and a two-column FILE table.
var _body: Label
var _file_grid: GridContainer


func _render(board: ClipboardBoard) -> void:
	_ensure_extra_nodes()
	notice.text = _fill_notice(board.notice_text)

	_body.text = board.body_text
	_body.visible = not board.body_text.is_empty()

	cover_heading.text = "COVER"
	var numbered: Array[String] = []
	for i in board.cover_lines.size():
		numbered.append("%d  %s" % [i + 1, board.cover_lines[i].replace("\n", "\n    ")])
	cover_lines.text = "\n".join(numbered)
	cover_heading.visible = not board.cover_lines.is_empty()
	cover_lines.visible = cover_heading.visible

	file_heading.text = "FILE"
	file_lines.visible = false # replaced by the grid
	
	# Clear old grid items
	for child in _file_grid.get_children():
		child.queue_free()
		
	# Build the new hierarchical list
	for line in board.file_lines:
		var parts := line.split("\t", true, 1)
		var drawer_name := parts[0].strip_edges()
		var description := parts[1].strip_edges() if parts.size() > 1 else ""
		
		var row_vbox := VBoxContainer.new()
		row_vbox.add_theme_constant_override("separation", 2)
		
		var name_label := _cell(drawer_name)
		name_label.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05))
		name_label.add_theme_font_size_override("font_size", 16)
		
		var desc_label := _cell(description)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		row_vbox.add_child(name_label)
		row_vbox.add_child(desc_label)
		_file_grid.add_child(row_vbox)

	file_heading.visible = not board.file_lines.is_empty()
	_file_grid.visible = file_heading.visible
	
	# Always start on page 1 when opening a new board
	_show_page(1)

func _ensure_extra_nodes() -> void:
	if _body != null:
		return
	_body = cover_lines.duplicate() as Label
	_body.name = "Body"
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_sibling(_body)
	
	_file_grid = GridContainer.new()
	_file_grid.name = "FileGrid"
	_file_grid.columns = 1 
	_file_grid.add_theme_constant_override("h_separation", 0)
	_file_grid.add_theme_constant_override("v_separation", 12)
	
	# Add the grid to Page2, right before the back button
	page2.add_child(_file_grid)
	page2.move_child(_file_grid, page2.get_child_count() - 2) # Put it before the back button


func _cell(text: String) -> Label:
	var label := file_lines.duplicate() as Label
	label.visible = true
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP # names line up with a description's first line
	return label


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
