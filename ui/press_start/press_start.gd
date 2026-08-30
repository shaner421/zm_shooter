extends Control

## Opening screen shown before the main menu. Advances to the main menu on
## the first detected input of almost any kind. Does not consume the input
## event, so whatever triggered the advance still reaches the main menu
## normally afterward if relevant.

## Screen name to advance to once input is detected. Set in the inspector so
## this scene is not hardcoded to a specific registry key.
@export var next_screen: StringName = &"main_menu"

## Guards against firing more than once while the screen is still finishing
## its transition out.
var _has_advanced: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if _has_advanced:
		return

	if _is_start_input(event):
		_has_advanced = true
		MenuManager.change_screen(next_screen, false, false)


## Filters for input types that should count as "any button", excluding
## things like mouse motion or joystick drift that would trigger this
## unintentionally just from the player moving their mouse.
func _is_start_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true

	if event is InputEventMouseButton and event.pressed:
		return true

	if event is InputEventJoypadButton and event.pressed:
		return true

	return false
