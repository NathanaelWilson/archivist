extends Control

const GAME_SCENE_PATH := "res://Root/main.tscn"

@onready var start_button: TextureButton = $CenterContainer/MarginTop/ButtonRow/StartButton
@onready var start_outline: InteractableOutline = $CenterContainer/MarginTop/ButtonRow/StartButton/InteractableOutline
@onready var records_button: TextureButton = $CenterContainer/MarginTop/ButtonRow/RecordsButton
@onready var records_outline: InteractableOutline = $CenterContainer/MarginTop/ButtonRow/RecordsButton/InteractableOutline
@onready var exit_button: TextureButton = $ExitButton
@onready var settings_button: TextureButton = $SettingsButton

@onready var records_screen: RecordsScreen = $RecordsScreen
@onready var records_close_button: Button = $RecordsScreen/CloseButton
@onready var page_flip_sfx: AudioStreamPlayer = $RecordsScreen/PageFlipSFX

@onready var journal_screen: Control = $JournalScreen
@onready var journal_close_button: Button = $JournalScreen/CloseButton
@onready var splash_screen: SplashScreen = $SplashScreen
## Everything the player can press, held back while the title card is up.
@onready var menu_controls: Array[Control] = [$CenterContainer, settings_button, exit_button]


func _ready() -> void:
	Music.play(&"menu")
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	records_button.pressed.connect(_on_records_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	records_close_button.pressed.connect(_on_records_close_pressed)
	journal_close_button.pressed.connect(_on_journal_close_pressed)

	# Start/Records are illustrations, outlined in white exactly like the
	# desk props (InteractableOutline). Exit/Settings get no outline, just
	# the hover sound.
	_wire_outline(start_button, start_outline)
	_wire_outline(records_button, records_outline)
	_wire_outline(exit_button, null)
	_wire_outline(settings_button, null)

	# First time the menu appears after launch: the title card comes first,
	# over the blurred desk, and the menu's buttons fade in once it is gone.
	if not SplashScreen.shown_this_launch:
		_play_title_card()


func _play_title_card() -> void:
	for control in menu_controls:
		control.modulate.a = 0.0
	await splash_screen.play()
	var fade := create_tween().set_parallel(true)
	for control in menu_controls:
		fade.tween_property(control, "modulate:a", 1.0, 0.5)


func _wire_outline(control: Control, outline: InteractableOutline) -> void:
	control.mouse_entered.connect(func():
		if outline:
			outline.show_outline(true)
		SFX.play(&"ui_hover")
	)
	control.mouse_exited.connect(func():
		if outline:
			outline.show_outline(false)
	)


func _on_start_pressed() -> void:
	SFX.play(&"ui_click")
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_records_pressed() -> void:
	records_screen.refresh()
	records_screen.visible = true
	SFX.play(&"page_flip")


func _on_records_close_pressed() -> void:
	SFX.play(&"page_flip")
	records_screen.visible = false


func _on_settings_pressed() -> void:
	# Settings screen: the journal window, currently holding the Audio Setting
	# panel (Scenes/Settings/audio_settings_panel.tscn).
	SFX.play(&"ui_click")
	journal_screen.visible = true


func _on_journal_close_pressed() -> void:
	SFX.play(&"ui_click")
	journal_screen.visible = false
