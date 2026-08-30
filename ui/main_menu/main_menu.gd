extends Control

## Primary navigation hub, shown after the press-start screen. Forwards
## button presses to MenuManager and has no game state of its own.

## Shown as a hover tooltip on the Online button when Steam failed to
## initialize, explaining why the button is disabled.
const STEAM_UNAVAILABLE_TOOLTIP: String = "Steam was unable to initialize. Try again later."

@onready var _online_button: Button = %OnlineButton
@onready var _local_button: Button = %LocalButton
@onready var _options_button: Button = %OptionsButton
@onready var _controller_hint: Control = %ControllerHint


func _ready() -> void:
	_online_button.pressed.connect(_on_online_pressed)
	_local_button.pressed.connect(_on_local_pressed)
	_options_button.pressed.connect(_on_options_pressed)

	_update_online_button_state()

	ControllerStatus.controller_connected.connect(_on_controller_status_changed)
	ControllerStatus.controller_disconnected.connect(_on_controller_status_changed)
	_update_controller_hint()


func _update_online_button_state() -> void:
	var steam_ready: bool = SteamManager.is_steam_initialized

	_online_button.disabled = not steam_ready
	_online_button.tooltip_text = "" if steam_ready else STEAM_UNAVAILABLE_TOOLTIP


func _update_controller_hint() -> void:
	var v = ControllerStatus.has_any_controller()
	_controller_hint.modulate = Color(v,v,v,v)


## Handles both controller_connected and controller_disconnected, since
## either one just means "recheck whether any controller is plugged in."
## _arg2 covers the extra controller_name argument that only
## controller_connected sends; controller_disconnected only sends _device.
func _on_controller_status_changed(_device: int, _arg2 = null) -> void:
	_update_controller_hint()


func _on_online_pressed() -> void:
	MenuManager.change_screen(&"online_screen")


func _on_local_pressed() -> void:
	MenuManager.change_screen(&"local_screen")


func _on_options_pressed() -> void:
	MenuManager.change_screen(&"options_screen")
