extends CanvasLayer

## Shows the current frames per second in a corner of the screen. Present
## globally regardless of what screen or scene is active, since it is
## autoloaded as a scene rather than instanced inside any particular screen.
## Hidden automatically in release exports, visible in the editor and in
## debug exports, since OS.is_debug_build() covers exactly those two cases
## and nothing else.

## How often the displayed number refreshes, in seconds. Refreshing every
## single frame makes the number flicker too fast to actually read, and does
## unnecessary string formatting work each frame for no benefit.
@export var refresh_interval_seconds: float = 0.2

@onready var _label: Label = %FpsLabel

var _time_since_refresh: float = 0.0


func _ready() -> void:
	if not OS.is_debug_build():
		hide()
		set_process(false)
		return

	layer = 100


func _process(delta: float) -> void:
	_time_since_refresh += delta
	if _time_since_refresh < refresh_interval_seconds:
		return

	_time_since_refresh = 0.0
	_label.text = "%d FPS" % Engine.get_frames_per_second()
