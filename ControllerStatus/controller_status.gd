extends Node

## Tracks which controllers are currently connected. Autoloaded as a script,
## no exported references needed. Any screen can query the current state
## directly, or connect to the signals below to react live if a controller
## gets plugged in or removed while that screen is visible.

## Emitted when a controller is plugged in, whether at startup or during play.
signal controller_connected(device: int, controller_name: String)

## Emitted when a controller is unplugged.
signal controller_disconnected(device: int)


## Device ids of every controller currently connected. Kept in sync by
## _on_joy_connection_changed, not meant to be written to directly.
var connected_devices: Array[int] = []


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	# Input.get_connected_joypads() only reflects what's plugged in at this
	# exact moment, the joy_connection_changed signal only fires for changes
	# from here onward, so this catches anything already connected before
	# the game launched.
	for device in Input.get_connected_joypads():
		connected_devices.append(device)


## True if at least one controller is currently connected. Main query for UI
## that wants to show or hide controller-specific elements.
func has_any_controller() -> bool:
	return not connected_devices.is_empty()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		if not connected_devices.has(device):
			connected_devices.append(device)
		controller_connected.emit(device, Input.get_joy_name(device))
	else:
		connected_devices.erase(device)
		controller_disconnected.emit(device)
