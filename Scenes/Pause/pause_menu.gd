class_name PauseMenu
extends CanvasLayer

## In-game pause. A gear (the same icon as the main menu's Settings) sits in
## the top-right corner of the desk; tapping it pauses the game and shows two
## choices:
##   SETTINGS   — the same audio settings as the main menu (journal window);
##   MAIN MENU  — leave the shift and go back to the title.
## Tapping anywhere off the choices (or the gear again) resumes.
##
## This layer keeps running while the tree is paused (process_mode ALWAYS);
## everything else on the desk — tweens, timers, the eyelids — stops.

const MAIN_MENU_SCENE_PATH := "res://Scenes/MainMenu/main_menu.tscn"

@onready var pause_button: TextureButton = $PauseButton
@onready var menu: Control = $Menu
@onready var dim: ColorRect = $Menu/Dim
@onready var settings_button: Button = $Menu/Choices/SettingsButton
@onready var main_menu_button: Button = $Menu/Choices/MainMenuButton
@onready var settings_screen: Control = $Settings
@onready var settings_close_button: Button = $Settings/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.pressed.connect(toggle)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	settings_close_button.pressed.connect(_on_settings_close_pressed)
	dim.gui_input.connect(_on_dim_input)
	menu.visible = false
	settings_screen.visible = false


func is_open() -> bool:
	return menu.visible or settings_screen.visible


## The gear is hidden while something else owns the corner (the document
## viewer's "?" sits there).
func set_button_visible(shown: bool) -> void:
	pause_button.visible = shown and not is_open()


func toggle() -> void:
	if is_open():
		resume()
	else:
		pause()


func pause() -> void:
	SFX.play(&"ui_click")
	get_tree().paused = true
	menu.visible = true
	settings_screen.visible = false
	pause_button.visible = false


func resume() -> void:
	SFX.play(&"ui_click")
	menu.visible = false
	settings_screen.visible = false
	pause_button.visible = true
	get_tree().paused = false


func _on_settings_pressed() -> void:
	SFX.play(&"ui_click")
	menu.visible = false
	settings_screen.visible = true


func _on_settings_close_pressed() -> void:
	SFX.play(&"ui_click")
	settings_screen.visible = false
	menu.visible = true


func _on_main_menu_pressed() -> void:
	SFX.play(&"ui_click")
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


## A tap off the two choices resumes. Controls get touch as emulated mouse
## clicks, so this one check covers phone and desktop.
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dim.accept_event()
		resume()
