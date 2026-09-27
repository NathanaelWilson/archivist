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

## The clipboard normally sits under the document viewer; opened while a
## document is up (from its RULES button) it is lifted above it.
const DESK_LAYER := 5
const OVER_DOCUMENT_LAYER := 12


func _ready() -> void:
	_crop_paper_to_sheet()
	# The rect drawn in the scene, before any content has stretched it.
	_base_size = Vector2(panel.offset_right - panel.offset_left, panel.offset_bottom - panel.offset_top)
	handle.pressed.connect(toggle)
	dim.gui_input.connect(_on_dim_input)
	panel.visible = false
	dim.visible = false
	
	# Connect the page buttons
	
	# Start on page 1
	_show_page(1, false)


## The clipboard is a single page now: WHAT TO COVER? on top and HOW TO
## ARCHIVE? underneath, always both. The old Page1 / Page2 nodes are kept as
## the two halves; their Next / Back buttons and bottom spacers are hidden.
func _show_page(_page_number: int = 1, _with_sound := true) -> void:
	page1.visible = true
	page2.visible = true
	for spacer in [page1.get_node_or_null("SpacerBottom"), page2.get_node_or_null("SpacerBottom")]:
		if spacer != null:
			spacer.visible = false


## Both pages share one fixed board size: the board's size in the scene,
## clamped to the screen. Each page's spacer stretches to fill it, so Next /
## Back never change the board's shape, and it never runs off screen.
@export var screen_margin := 16.0
var _base_size := Vector2.ZERO

## Fixed text sizes, set by hand in the Inspector — the same on every board.
@export_group("Text sizes")
## The boxed notice at the top ("READ THIS BOARD BEFORE EVERY FILE.").
@export var notice_font_size := 16:
	set(value):
		notice_font_size = value
		_apply_font_sizes()
## "WHAT TO COVER?" and "HOW TO ARCHIVE?".
@export var heading_font_size := 15:
	set(value):
		heading_font_size = value
		_apply_font_sizes()
## The numbered rules AND the HOW TO ARCHIVE? entries (drawer names and
## what goes in them), and board C2's message.
@export var rule_font_size := 11:
	set(value):
		rule_font_size = value
		_apply_font_sizes()
@export_group("Spacing")
## Gestalt proximity: things that belong together sit closer than things
## that don't. Smallest inside one item, largest between the sections.
## Between the notice and the first section, and between the two sections.
@export var section_gap := 16
## Between a heading and the list under it.
@export var heading_gap := 4
## Between two rules / two drawer entries.
@export var item_gap := 7
## Inside one drawer entry: its name and the line that says what goes in it.
@export var inside_item_gap := 1
@export_group("")

## Main still hands over every board; kept so that call keeps working.
var board_catalog: Array = []


func _fit_board_to_pages() -> void:
	var view := get_viewport().get_visible_rect().size
	var room := view - Vector2.ONE * screen_margin * 2.0
	var board_size := _base_size.min(room)
	panel.custom_minimum_size = board_size
	_apply_font_sizes()
	_show_page(1, false)
	panel.reset_size()
	panel.size = board_size
	panel.position = panel.position.clamp(
		Vector2.ONE * screen_margin,
		(view - board_size - Vector2.ONE * screen_margin).max(Vector2.ONE * screen_margin))


## Applies the fixed sizes above to everything on the board.
func _apply_font_sizes() -> void:
	if not is_node_ready():
		return
	notice.add_theme_font_size_override("font_size", notice_font_size)
	cover_heading.add_theme_font_size_override("font_size", heading_font_size)
	file_heading.add_theme_font_size_override("font_size", heading_font_size)
	cover_lines.add_theme_font_size_override("font_size", rule_font_size)
	if _rule_list != null:
		for rule in _rule_list.get_children():
			if not rule.is_queued_for_deletion():
				(rule as Label).add_theme_font_size_override("font_size", rule_font_size)
	if _body != null:
		_body.add_theme_font_size_override("font_size", rule_font_size)
	if _file_grid != null:
		for entry in _file_grid.get_children():
			if entry.is_queued_for_deletion() or entry.get_child_count() < 2:
				continue
			(entry.get_child(0) as Label).add_theme_font_size_override("font_size", rule_font_size)
			(entry.get_child(1) as Label).add_theme_font_size_override("font_size", rule_font_size)


## Proximity spacing (see the Spacing exports). The sections' own VBox
## gaps are the heading-to-list gap; the notice and the two sections are
## pushed apart with the larger section gap.
func _apply_spacing() -> void:
	if _rule_list == null:
		return
	page1.add_theme_constant_override("separation", heading_gap)
	page2.add_theme_constant_override("separation", heading_gap)
	(page1.get_parent() as Container).add_theme_constant_override("separation", section_gap)
	_notice_gap.custom_minimum_size = Vector2(0, maxf(0.0, section_gap - heading_gap * 2))
	_rule_list.add_theme_constant_override("separation", item_gap)
	_file_grid.add_theme_constant_override("separation", item_gap)
	for entry in _file_grid.get_children():
		entry.add_theme_constant_override("separation", inside_item_gap)


## PaperBackground.png has empty, transparent space around the sheet. The
## board shows just the sheet: the crop is worked out from the picture
## itself, so it stays right whenever the PNG is replaced or resized.
func _crop_paper_to_sheet() -> void:
	var paper := get_node_or_null("Board/PaperBackground") as TextureRect
	if paper == null:
		return
	var atlas := paper.texture as AtlasTexture
	if atlas == null or atlas.atlas == null:
		return
	var full := Rect2(Vector2.ZERO, atlas.atlas.get_size())
	var image := atlas.atlas.get_image()
	if image == null:
		atlas.region = full
		return
	if image.is_compressed():
		image.decompress()
	var used := image.get_used_rect()
	atlas.region = Rect2(used) if used.has_area() else full


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
var _rule_list: VBoxContainer
var _notice_gap: Control


func _render(board: ClipboardBoard) -> void:
	_ensure_extra_nodes()
	notice.text = _fill_notice(board.notice_text)

	_body.text = board.body_text
	_body.visible = not board.body_text.is_empty()

	cover_heading.text = "WHAT TO COVER?"
	cover_lines.visible = false # replaced by one label per rule
	for child in _rule_list.get_children():
		child.queue_free()
	for i in board.cover_lines.size():
		var rule := _cell("%d. %s" % [i + 1, board.cover_lines[i].replace("\n", " ")])
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rule_list.add_child(rule)
	cover_heading.visible = not board.cover_lines.is_empty()
	_rule_list.visible = cover_heading.visible

	file_heading.text = "HOW TO ARCHIVE?"
	file_lines.visible = false # replaced by the grid
	
	# Clear old grid items
	for child in _file_grid.get_children():
		child.queue_free()
		
	# Build the new hierarchical list
	var drawer_number := 0
	for line in board.file_lines:
		drawer_number += 1
		var parts := _split_file_line(line)
		var drawer_name: String = parts[0]
		var description: String = parts[1]
		
		# One entry per drawer: the name, then (on the next line) what goes
		# there, wrapping across the full width of the board.
		var name_label := _cell("%d. %s" % [drawer_number, drawer_name])
		name_label.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05))
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var desc_label := _cell(description)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var entry := VBoxContainer.new()
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_theme_constant_override("separation", inside_item_gap)
		entry.add_child(name_label)
		entry.add_child(desc_label)
		_file_grid.add_child(entry)

	file_heading.visible = not board.file_lines.is_empty()
	_file_grid.visible = file_heading.visible
	
	_apply_spacing()
	# Always start on page 1 when opening a new board
	_show_page(1, false)

func _ensure_extra_nodes() -> void:
	if _body != null:
		return
	_body = cover_lines.duplicate() as Label
	_body.name = "Body"
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_sibling(_body)
	
	# Gap under the notice (and C2's message), before WHAT TO COVER?.
	_notice_gap = Control.new()
	_notice_gap.name = "NoticeGap"
	_notice_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_sibling(_notice_gap)

	# One label per rule, so the space BETWEEN rules can be larger than the
	# line spacing INSIDE a rule that wraps.
	_rule_list = VBoxContainer.new()
	_rule_list.name = "RuleList"
	_rule_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cover_lines.add_sibling(_rule_list)

		# A plain vertical list: a GridContainer sizes its column to the
	# narrowest child, and wrapping labels are 0 wide on their own, which
	# squeezed the text into one letter per line.
	_file_grid = VBoxContainer.new()
	_file_grid.name = "FileGrid"
	_file_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_grid.add_theme_constant_override("separation", 6)
	
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
