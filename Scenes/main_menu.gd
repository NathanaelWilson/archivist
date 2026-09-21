extends Control

const GAME_SCENE_PATH := "res://Root/main.tscn"

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton
@onready var records_button: Button = $CenterContainer/VBoxContainer/RecordsButton
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

	_setup_hover_outline(start_button, start_button.get_node("HoverOutline"))
	_setup_hover_outline(exit_button, exit_button.get_node("HoverOutline"))
	_setup_hover_outline(records_button, records_button.get_node("HoverOutline"))

	# the gear's icon has a real silhouette (teeth, center hole), so it uses
	# the alpha-based outline shader instead of a bounding-box panel
	settings_button.mouse_entered.connect(func(): settings_outline.show_outline(true))
	settings_button.mouse_exited.connect(func(): settings_outline.show_outline(false))


func _setup_hover_outline(control: Control, outline: Control) -> void:
	control.mouse_entered.connect(func(): outline.visible = true)
	control.mouse_exited.connect(func(): outline.visible = false)


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
