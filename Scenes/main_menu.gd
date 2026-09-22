extends Control

const GAME_SCENE_PATH := "res://Root/main.tscn"

@onready var start_button: TextureButton = $CenterContainer/MarginTop/ButtonRow/StartButton
@onready var start_outline: InteractableOutline = $CenterContainer/MarginTop/ButtonRow/StartButton/InteractableOutline
@onready var records_button: TextureButton = $CenterContainer/MarginTop/ButtonRow/RecordsButton
@onready var records_outline: InteractableOutline = $CenterContainer/MarginTop/ButtonRow/RecordsButton/InteractableOutline
@onready var exit_button: TextureButton = $ExitButton
@onready var exit_outline: InteractableOutline = $ExitButton/InteractableOutline
@onready var settings_button: TextureButton = $SettingsButton
@onready var settings_outline: InteractableOutline = $SettingsButton/InteractableOutline

@onready var records_screen: Control = $RecordsScreen
@onready var records_close_button: Button = $RecordsScreen/CloseButton
@onready var page_flip_sfx: AudioStreamPlayer = $RecordsScreen/PageFlipSFX

@onready var journal_screen: Control = $JournalScreen
@onready var journal_close_button: Button = $JournalScreen/CloseButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	records_button.pressed.connect(_on_records_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	records_close_button.pressed.connect(_on_records_close_pressed)
	journal_close_button.pressed.connect(_on_journal_close_pressed)

	# all four buttons are illustrations with real silhouettes now, so they
	# all share the same alpha-based outline shader via InteractableOutline
	# (Start/Records use a white outline_color, Exit/Settings use the default gold)
	_wire_outline(start_button, start_outline)
	_wire_outline(records_button, records_outline)
	_wire_outline(exit_button, exit_outline)
	_wire_outline(settings_button, settings_outline)


func _wire_outline(control: Control, outline: InteractableOutline) -> void:
	control.mouse_entered.connect(func(): outline.show_outline(true))
	control.mouse_exited.connect(func(): outline.show_outline(false))


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_records_pressed() -> void:
	# TODO: placeholder screen/template for the real Record of Outcomes screen
	records_screen.visible = true
	page_flip_sfx.play()


func _on_records_close_pressed() -> void:
	records_screen.visible = false


func _on_settings_pressed() -> void:
	# TODO: placeholder screen/template for the real settings panel
	journal_screen.visible = true


func _on_journal_close_pressed() -> void:
	journal_screen.visible = false
