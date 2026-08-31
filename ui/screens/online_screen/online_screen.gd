extends Control

## Sub-menu shown after choosing Online from the main menu. Presents the
## three ways a player can start an online session. Holds no networking
## state itself, only forwards button presses to MenuManager. Actual lobby
## creation, code entry, and solo session setup live in whatever screens
## these buttons navigate to, not here.

@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _solo_button: Button = %SoloButton
@onready var playercard:PlayerCard = %PlayerCard
@onready var _player_count_label = %OnlinePlayers
@onready var _controller_hint: Control = %ControllerHint
#@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_solo_button.pressed.connect(_on_solo_pressed)
	#_back_button.pressed.connect(_on_back_pressed)
	_update_identity_display()
	_update_player_count_display()
	
	ControllerStatus.controller_connected.connect(_on_controller_status_changed)
	ControllerStatus.controller_disconnected.connect(_on_controller_status_changed)
	_update_controller_hint()

## Shows the local player's Steam name right away, since SteamManager
## already has it by the time this screen can exist, the Online button is
## disabled unless init already succeeded. The avatar may still be
## downloading though, so this falls back to listening for avatar_ready if
## it is not available yet.
func _update_identity_display() -> void:
	playercard.set_username(str(SteamManager.local_steam_name))

	if SteamManager.local_avatar_texture != null:
		playercard.set_avatar(SteamManager.local_avatar_texture)
	else:
		SteamManager.avatar_ready.connect(_on_avatar_ready)


func _on_avatar_ready(texture: ImageTexture) -> void:
	playercard.set_avatar(texture)


## Kicks off an async request for the current player count and shows a
## placeholder until the result comes back.
func _update_player_count_display() -> void:
	_player_count_label.text = "Loading player count..."
	SteamManager.player_count_received.connect(_on_player_count_received)
	SteamManager.request_player_count()

func _update_controller_hint() -> void:
	var v = ControllerStatus.has_any_controller()
	_controller_hint.modulate = Color(v,v,v,v)


## Handles both controller_connected and controller_disconnected, since
## either one just means "recheck whether any controller is plugged in."
## _arg2 covers the extra controller_name argument that only
## controller_connected sends; controller_disconnected only sends _device.
func _on_controller_status_changed(_device: int, _arg2 = null) -> void:
	_update_controller_hint()


func _on_player_count_received(success: bool, player_count: int) -> void:
	SteamManager.player_count_received.disconnect(_on_player_count_received)

	if success:
		_player_count_label.text = "%d players online" % player_count
	else:
		_player_count_label.text = "Player count unavailable"


func _on_host_pressed() -> void:
	MenuManager.change_screen(&"lobby_screen")


func _on_join_pressed() -> void:
	%JoinCode.visible = %JoinButton.pressed
	%GoButton.visible = %JoinButton.toggle_mode


func _on_solo_pressed() -> void:
	MenuManager.change_screen(&"solo_lobby_screen")


func _on_back_pressed() -> void:
	MenuManager.go_back()
