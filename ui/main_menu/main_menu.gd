extends Control

## Primary navigation hub, shown after the press-start screen. Forwards
## button presses to MenuManager and has no game state of its own.

## Shown as a hover tooltip on the Online button when Steam failed to
## initialize, explaining why the button is disabled.
const STEAM_UNAVAILABLE_TOOLTIP: String = "Steam was unable to initialize. Please restart Steam and try again."

@onready var _online_button: Button = %OnlineButton
@onready var _local_button: Button = %LocalButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_online_button.pressed.connect(_on_online_pressed)
	_local_button.pressed.connect(_on_local_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_update_online_button_state()


## Disables the Online button and attaches an explanatory tooltip if Steam
## failed to initialize. SteamManager has already resolved this by the time
## this screen exists, since autoloads finish their own _ready() before the
## first scene's _ready() runs, so no signal needs to be awaited here.
func _update_online_button_state() -> void:
	var steam_ready: bool = SteamManager.is_steam_initialized

	_online_button.disabled = not steam_ready
	_online_button.tooltip_text = "" if steam_ready else STEAM_UNAVAILABLE_TOOLTIP


func _on_online_pressed() -> void:
	MenuManager.change_screen(&"online_screen")


func _on_local_pressed() -> void:
	MenuManager.change_screen(&"local_screen")


func _on_options_pressed() -> void:
	MenuManager.change_screen(&"options_screen")


func _on_quit_pressed() -> void:
	get_tree().quit()
