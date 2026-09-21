extends Control

const GAME_SCENE_PATH := "res://Root/main.tscn"

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton
@onready var settings_button: TextureButton = $SettingsButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	settings_button.pressed.connect(_on_settings_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_settings_pressed() -> void:
	# TODO: hook up a real settings panel once one exists
	print("Settings pressed - not implemented yet")
