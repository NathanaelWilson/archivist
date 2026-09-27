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

## The clipboard normally sits under the document viewer; opened while a
## document is up (from its RULES button) it is lifted above it.
const DESK_LAYER := 5
const OVER_DOCUMENT_LAYER := 12


func _ready() -> void:
	# The rect drawn in the scene, before any content has stretched it.
	_base_size = Vector2(panel.offset_right - panel.offset_left, panel.offset_bottom - panel.offset_top)
	handle.pressed.connect(toggle)
	dim.gui_input.connect(_on_dim_input)
	panel.visible = false
	dim.visible = false
	
	# Connect the page buttons
	next_button.pressed.connect(_show_page.bind(2))
	back_button.pressed.connect(_show_page.bind(1))
	
	# Start on page 1
	_show_page(1, false)


func _show_page(page_number: int, with_sound := true) -> void:
	page1.visible = (page_number == 1)
	page2.visible = (page_number == 2)
	if with_sound:
		SFX.play(&"page_flip")


## Both pages share one fixed board size: the board's size in the scene,
## clamped to the screen. Each page's spacer stretches to fill it, so Next /
## Back never change the board's shape, and it never runs off screen.
@export var screen_margin := 16.0
var _base_size := Vector2.ZERO


var _fit_id := 0
## Smallest the clipboard text may shrink to when a board is too long.
@export_range(0.5, 1.0, 0.05) var min_text_scale := 0.6
## Every board the game can show (Main sets it). The text size is chosen
## once so that the LONGEST of them fits, and then used for all of them —
## so the clipboard reads the same in Shift 1, 2 and 3.
var board_catalog: Array = []
var _shared_text_scale := -1.0


func _fit_board_to_pages() -> void:
	_fit_id += 1
	var my_id := _fit_id
	var view := get_viewport().get_visible_rect().size
	var room := view - Vector2.ONE * screen_margin * 2.0
	var board_size := _base_size.min(room)
	panel.custom_minimum_size = board_size
	if _shared_text_scale < 0.0:
		# First time only, laid out invisibly: every board is tried, and the
		# text shrinks a step at a time until the longest one fits — so
		# Next / Back always stay on the board, whatever the copy says.
		panel.modulate.a = 0.0
		var shown := _current_board()
		var boards: Array = board_catalog if not board_catalog.is_empty() else [shown]
		var text_scale := 1.0
		for board in boards:
			_render(board)
			while true:
				var fits = await _fits_at(text_scale, board_size, my_id)
				if fits == null:
					return # opened again meanwhile; the newer fit wins
				if fits or text_scale <= min_text_scale:
					break
				text_scale = maxf(min_text_scale, text_scale - 0.08)
		_shared_text_scale = text_scale
		_render(shown)
	_apply_text_scale(_shared_text_scale)
	_show_page(1, false)
	panel.reset_size()
	panel.size = board_size
	panel.position = panel.position.clamp(
		Vector2.ONE * screen_margin,
		(view - board_size - Vector2.ONE * screen_margin).max(Vector2.ONE * screen_margin))
	panel.modulate.a = 1.0


## Whether both pages of the rendered board fit at this text scale. null if
## the clipboard was reopened while measuring.
func _fits_at(text_scale: float, board_size: Vector2, my_id: int) -> Variant:
	_apply_text_scale(text_scale)
	var fits := true
	for page_number in [2, 1]:
		_show_page(page_number, false)
		panel.reset_size()
		await get_tree().process_frame
		if my_id != _fit_id:
			return null
		var needed := panel.get_combined_minimum_size()
		if needed.y > board_size.y + 0.5 or needed.x > board_size.x + 0.5:
			fits = false
	return fits


## Scales every label on the board from its own designed font size.
func _apply_text_scale(text_scale: float) -> void:
	for node in panel.find_children("*", "Label", true, false):
		var label := node as Label
		if not label.has_meta("base_font_size"):
			label.set_meta("base_font_size", label.get_theme_font_size("font_size"))
		var base: int = label.get_meta("base_font_size")
		label.add_theme_font_size_override("font_size", maxi(8, roundi(base * text_scale)))


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


## over_document: open on top of the document viewer (its RULES button).
func open(over_document := false) -> void:
	var board := _current_board()
	if board == null:
		return
	layer = OVER_DOCUMENT_LAYER if over_document else DESK_LAYER
	_render(board)
	panel.visible = true
	dim.visible = true
	_fit_board_to_pages()
	handle.text = "PUT DOWN"
	SFX.play(&"page_flip")
	_files_at_last_read = FilingLog.total_filed


func close() -> void:
	panel.visible = false
	dim.visible = false
	layer = DESK_LAYER
	handle.text = "CLIPBOARD"


func _current_board() -> ClipboardBoard:
	if not board_source.is_valid():
		push_warning("ClipboardPanel has no board_source; Main should set it.")
		return null
	return board_source.call() as ClipboardBoard


## Built on first render from the scene's own labels, so they share their
## font, size and colour: the board's free text, and a two-column FILE table.
var _body: Label
var _file_grid: VBoxContainer


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
		var parts := _split_file_line(line)
		var drawer_name: String = parts[0]
		var description: String = parts[1]
		
		# One entry per drawer: the name, then (on the next line) what goes
		# there, wrapping across the full width of the board.
		var name_label := _cell(drawer_name)
		name_label.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05))
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var desc_label := _cell(description)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var entry := VBoxContainer.new()
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_theme_constant_override("separation", 2)
		entry.add_child(name_label)
		entry.add_child(desc_label)
		_file_grid.add_child(entry)

	file_heading.visible = not board.file_lines.is_empty()
	_file_grid.visible = file_heading.visible
	
	# Always start on page 1 when opening a new board
	_show_page(1, false)

func _ensure_extra_nodes() -> void:
	if _body != null:
		return
	_body = cover_lines.duplicate() as Label
	_body.name = "Body"
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_sibling(_body)
	
	# A plain vertical list: a GridContainer sizes its column to the
	# narrowest child, and wrapping labels are 0 wide on their own, which
	# squeezed the text into one letter per line.
	_file_grid = VBoxContainer.new()
	_file_grid.name = "FileGrid"
	_file_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_grid.add_theme_constant_override("separation", 12)
	
	# Add the grid to Page2, right before the back button
	page2.add_child(_file_grid)
	page2.move_child(_file_grid, page2.get_node("SpacerBottom").get_index()) # under the heading, above the spacer that holds Back at the bottom


## "DRAWER<TAB>description". Lines typed with spaces instead of a tab
## (two or more in a row) are split there too, so a line can never end up
## as one long unwrapped drawer name that stretches the board.
func _split_file_line(line: String) -> Array[String]:
	var parts := line.split("\t", true, 1)
	if parts.size() < 2:
		var gap := RegEx.create_from_string("\\s{2,}").search(line)
		if gap != null:
			parts = PackedStringArray([line.substr(0, gap.get_start()), line.substr(gap.get_end())])
	var drawer_name := parts[0].strip_edges()
	var description := parts[1].strip_edges() if parts.size() > 1 else ""
	return [drawer_name, description]


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
