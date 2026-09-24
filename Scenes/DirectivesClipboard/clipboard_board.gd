class_name ClipboardBoard
extends Resource

## One clipboard board. The desk's clipboard shows only skeleton lines at
## rest; this resource is what it renders when the player lifts it. Six
## instances exist (A, A2, B, B2, C, C2) and swap silently mid-shift per
## the GDD's schedule — main.gd picks which one is live, the clipboard UI
## just asks for it and draws it.

@export var id: StringName = &""
## Boxed line at the top of every board. May contain "\n" for multiple
## lines and "{N}" for a runtime-substituted count (board C only).
@export var notice_text: String = ""
@export var cover_lines: Array[String] = []
@export var file_lines: Array[String] = []
