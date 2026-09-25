class_name AudioSettingsPanel
extends Control

## The "Audio Setting" block inside the Settings (journal) screen: one slider
## per audio bus with its percentage on the right. Moving a slider changes the
## volume immediately; the choice is saved shortly after the player lets go.

@onready var music_slider: HSlider = $Center/Content/MusicRow/Slider
@onready var music_value: Label = $Center/Content/MusicRow/Value
@onready var sfx_slider: HSlider = $Center/Content/SfxRow/Slider
@onready var sfx_value: Label = $Center/Content/SfxRow/Value
@onready var save_timer: Timer = $SaveTimer


func _ready() -> void:
	_bind(music_slider, music_value, &"Music")
	_bind(sfx_slider, sfx_value, &"SFX")
	save_timer.timeout.connect(AudioSettings.save)


func _bind(slider: HSlider, value_label: Label, bus: StringName) -> void:
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.set_value_no_signal(roundf(AudioSettings.get_volume(bus) * 100.0))
	_show_percent(value_label, slider.value)
	slider.value_changed.connect(func(value: float):
		AudioSettings.set_volume(bus, value / 100.0)
		_show_percent(value_label, value)
		save_timer.start() # saves 0.5 s after the last change
	)
	# A short sample on release so the new SFX level can be heard.
	if bus == &"SFX":
		slider.drag_ended.connect(func(_changed: bool): SFX.play(&"ui_click"))


func _show_percent(value_label: Label, value: float) -> void:
	value_label.text = "%d%%" % int(value)
