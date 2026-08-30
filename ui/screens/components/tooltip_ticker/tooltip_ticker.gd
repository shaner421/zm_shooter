extends Control

## Cycles through hint strings loaded from a plain text file, showing one at
## a time, with a fade transition between each. Meant to be instanced as a
## child of any screen that wants rotating tips at the bottom of the view.
## Owns its own data loading and timing, no external script needs to know
## this exists beyond instancing it.

## Path to a plain text file with one tooltip per line. Lines starting with
## # are treated as comments and skipped, as are blank lines.
@export_file("*.txt") var tooltip_file_path: String = "res://data/tooltips.txt"

## Seconds each tooltip stays fully visible before fading to the next one.
## Does not include the fade itself, so the total time between tips is this
## value plus one fade out and one fade in.
@export var cycle_interval_seconds: float = 12.0

## Seconds each fade, out or in, takes. Kept short relative to
## cycle_interval_seconds so it reads as a quick blend rather than a slow
## crossfade.
@export var fade_duration_seconds: float = 0.4

## Shuffles the full tip list once on load, then plays through it in that
## order. Avoids repeating a tip until every other tip has been shown, unlike
## picking a new random entry each interval which can repeat immediately.
@export var shuffle_order: bool = true

@onready var _label: Label = %TooltipLabel
@onready var _cycle_timer: Timer = %CycleTimer

var _tooltips: Array[String] = []
var _current_index: int = -1

## Tracks the currently running fade so a new cycle can cleanly cancel it if
## one is somehow still in progress, rather than letting two tweens fight
## over the same property.
var _fade_tween: Tween = null


func _ready() -> void:
	_tooltips = _load_tooltips(tooltip_file_path)

	if shuffle_order:
		_tooltips.shuffle()

	if _tooltips.is_empty():
		hide()
		return

	# Starts invisible so the very first tooltip fades in the same way every
	# later one does, rather than just appearing abruptly.
	_label.modulate.a = 0.0

	_cycle_timer.wait_time = cycle_interval_seconds
	_cycle_timer.timeout.connect(_show_next_tooltip)
	_cycle_timer.start()

	_show_next_tooltip()


## Reads path as plain text and splits it into one entry per non-empty,
## non-comment line. Returns an empty array if the file is missing or fails
## to open, so this component just hides itself rather than breaking the
## screen around it.
func _load_tooltips(path: String) -> Array[String]:
	var result: Array[String] = []

	if not FileAccess.file_exists(path):
		push_warning("TooltipTicker: file not found at '%s'" % path)
		return result

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("TooltipTicker: failed to open '%s', error %s" % [path, FileAccess.get_open_error()])
		return result

	for line in file.get_as_text().split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		result.append(trimmed)

	return result


## Fades the label out, swaps its text once fully invisible, then fades it
## back in. Cancels any fade already in progress first, so rapid or
## overlapping calls cannot leave two tweens driving the same alpha value.
func _show_next_tooltip() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(_label, "modulate:a", 0.0, fade_duration_seconds)
	_fade_tween.tween_callback(_advance_tooltip_text)
	_fade_tween.tween_property(_label, "modulate:a", 1.0, fade_duration_seconds)


## Swaps the label's text to the next tooltip in sequence. Split out from
## _show_next_tooltip so it can run as a tween step at the point the label is
## fully invisible, rather than at the moment the cycle timer fires.
func _advance_tooltip_text() -> void:
	_current_index = (_current_index + 1) % _tooltips.size()
	_label.text = _tooltips[_current_index]
