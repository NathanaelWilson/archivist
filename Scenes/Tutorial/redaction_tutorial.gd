class_name RedactionTutorial
extends Control

## Case 1 tutorial inside the document viewer (only for cases whose CaseData
## has show_tutorial on). A "?" sits top-right and breathes until
## it is used. Tapping it shows how to redact: a short explanation on the
## right, and a RedactionDemo sweeping a ghost marker over the anomaly itself.
## Both go away with GOT IT, or the moment the player starts inking.

const DEMO_SCRIPT := preload("res://Scenes/Tutorial/redaction_demo.gd")

@export var pulse_min_alpha := 0.35
@export var pulse_half_sec := 0.8

@onready var help_button: Button = $HelpButton
@onready var hint_panel: Control = $HintPanel
@onready var got_it_button: Button = $HintPanel/Margin/Content/GotItButton

var _demo: RedactionDemo
var _pulse: Tween
var _used := false


func _ready() -> void:
	help_button.pressed.connect(_on_help_pressed)
	got_it_button.pressed.connect(hide_help)
	hint_panel.visible = false
	help_button.visible = false


## Called by DocumentViewer every time a page opens. Shows the "?" only for
## tutorial cases; document is the page node the demo is drawn on.
func present(case_data: CaseData, document: Node2D, document_size: Vector2) -> void:
	hide_help()
	var wanted := case_data != null and case_data.show_tutorial
	help_button.visible = wanted
	if not wanted:
		_stop_pulse()
		return
	if _demo == null or not is_instance_valid(_demo):
		_demo = DEMO_SCRIPT.new()
		document.add_child(_demo)
	if not _demo.aim(case_data, document_size):
		_demo.stop()
	if not _used:
		_start_pulse()


## The viewer closed: everything off.
func dismiss() -> void:
	hide_help()
	help_button.visible = false
	_stop_pulse()


## The player started drawing — they have got the idea.
func on_ink_started() -> void:
	hide_help()


func hide_help() -> void:
	hint_panel.visible = false
	if _demo != null and is_instance_valid(_demo):
		_demo.stop()


func _on_help_pressed() -> void:
	SFX.play(&"ui_click")
	if hint_panel.visible:
		hide_help()
		return
	_used = true
	_stop_pulse()
	help_button.modulate.a = 1.0
	hint_panel.visible = true
	if _demo != null and is_instance_valid(_demo):
		_demo.play()


func _start_pulse() -> void:
	_stop_pulse()
	help_button.modulate.a = 1.0
	_pulse = create_tween().set_loops()
	_pulse.tween_property(help_button, "modulate:a", pulse_min_alpha, pulse_half_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(help_button, "modulate:a", 1.0, pulse_half_sec) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	help_button.modulate.a = 1.0
