extends Control

## Shown once the player is in a Steam lobby, whether by hosting a new one
## or joining an existing one. Displays the join code, a card for every
## member with their name and avatar, and the host-only match settings.
## Start, Mode, and Map stay visible to everyone but are disabled unless the
## local player currently owns the lobby, rechecked whenever membership
## changes since Steam can promote a new host mid-session if the current one
## leaves.
##
## If entered while not yet in a lobby, this screen creates one itself,
## which is currently the only path in, the Host Game button. Once a join
## screen exists, it will join a lobby before navigating here instead, and
## this screen will simply display whatever lobby it finds already joined.

## Scene instanced once per lobby member. Must expose set_username(String)
## and set_avatar(Texture2D) methods. Adjust the path if PlayerCard lives
## somewhere else in the project.
const PLAYER_CARD_SCENE: PackedScene = preload("res://ui/screens/components/player_card/player_card.tscn")

## Avatar size requested from Steam for each member card. 2 is medium, 64x64.
const AVATAR_SIZE: int = 2

#@onready var _status_label: Label = %StatusLabel
@onready var _join_code_label: Label = %JoinCodeLabel
@onready var _copy_join_code: Button = %CopyJoinCode
@onready var _player_list: VBoxContainer = %PlayerCards
@onready var _ready_button: Button = %ReadyButton
@onready var _mode_button: Button = %ModeButton
@onready var _map_button: Button = %MapButton
@onready var _invite_button: Button = %InviteButton
@onready var _controller_hint: Control = %ControllerHint
#@onready var _leave_button: Button = %LeaveButton

## Maps a member's Steam ID to the PlayerCard instance currently showing
## them, rebuilt each time _refresh_player_list runs. Used to route a
## delayed avatar_loaded result to the right card once its download
## finishes, even if that arrives after the list has already refreshed.
var _player_cards: Dictionary[int, Node] = {}


func _ready() -> void:
	Steam.lobby_data_update.connect(_on_lobby_data_update)
	_copy_join_code.pressed.connect(_on_copy_join_code_pressed)
	_invite_button.pressed.connect(_on_invite_pressed)
	_ready_button.toggled.connect(_on_ready_toggled)

	Steam.avatar_loaded.connect(_on_avatar_loaded)
	LobbyManager.lobby_created.connect(_on_lobby_created)
	LobbyManager.lobby_members_changed.connect(_on_lobby_state_changed)
	
	ControllerStatus.controller_connected.connect(_on_controller_status_changed)
	ControllerStatus.controller_disconnected.connect(_on_controller_status_changed)
	_update_controller_hint()
	
	if LobbyManager.lobby_id != 0:
		_show_lobby()
	else:
		#_status_label.text = "Creating lobby..."
		#_join_code_label.hide()
		_refresh_host_controls()
		LobbyManager.create_lobby()


# ---- Lobby entry and lifecycle ----

func _on_lobby_created(success: bool) -> void:
	if not success:
		#_status_label.text = "Could not create a lobby. Try again later."
		return

	_show_lobby()


## Reveals the lobby's contents once a lobby is confirmed to exist, whether
## that happened by hosting just now or was already true on entry.
func _show_lobby() -> void:
	#_status_label.text = "Waiting for players"

	if not LobbyManager.join_code.is_empty():
		_join_code_label.text = "Join Code: %s" % LobbyManager.join_code
		_join_code_label.show()
	else:
		_join_code_label.hide()

	_refresh_player_list()
	_refresh_host_controls()


## Called whenever lobby membership changes. Refreshes the player cards and
## the host-only controls together, since a host migration is exactly the
## kind of thing that shows up as a membership change.
func _on_lobby_state_changed() -> void:
	_refresh_player_list()
	_refresh_host_controls()

func _update_controller_hint() -> void:
	var v = ControllerStatus.has_any_controller()
	_controller_hint.modulate = Color(v,v,v,v)


## Handles both controller_connected and controller_disconnected, since
## either one just means "recheck whether any controller is plugged in."
## _arg2 covers the extra controller_name argument that only
## controller_connected sends; controller_disconnected only sends _device.
func _on_controller_status_changed(_device: int, _arg2 = null) -> void:
	_update_controller_hint()

# ---- Player cards ----

func _is_member_ready(steam_id: int) -> bool:
	return Steam.getLobbyMemberData(LobbyManager.lobby_id, steam_id, "ready") == "1"


## Rebuilds the visible member list from scratch. Simple to reason about at
## this size, this screen only ever shows a handful of players. Usernames
## are set immediately, Steam already has that cached for lobby members.
## Avatars arrive async, except for the local player, whose avatar
## SteamManager has likely already fetched, so that one is reused directly
## instead of requesting it all over again.
func _refresh_player_list() -> void:
	for child in _player_list.get_children():
		child.queue_free()
	_player_cards.clear()

	for steam_id in LobbyManager.get_member_steam_ids():
		var card: PlayerCard = PLAYER_CARD_SCENE.instantiate()
		_player_list.add_child(card)
		
		var display_name: String = Steam.getFriendPersonaName(steam_id)
		if steam_id == LobbyManager.get_host_steam_id():
			display_name += " (Host)"
		card.set_username(display_name)
		card.set_ready(_is_member_ready(steam_id))
		print(_is_member_ready(steam_id))
		_player_cards[steam_id] = card
		if steam_id == SteamManager.local_steam_id and SteamManager.local_avatar_texture != null:
			card.set_avatar(SteamManager.local_avatar_texture)
		else:
			Steam.getPlayerAvatar(AVATAR_SIZE, steam_id)
	
	%OnlinePlayers.text = str(_player_cards.size()) + "/x Players In Lobby"


func _on_lobby_data_update(_success, lobby_id: int, member_id: int) -> void:
	if lobby_id != LobbyManager.lobby_id:
		return

	if member_id == lobby_id:
		return

	if _player_cards.has(member_id) and is_instance_valid(_player_cards[member_id]):
		_player_cards[member_id].set_ready(_is_member_ready(member_id))
	var start = false
	for steam_id in LobbyManager.get_member_steam_ids():
		start = true
		if !_is_member_ready(steam_id):
			start=false
	if LobbyManager.get_member_steam_ids().size() > 1 and start:
		print("should be starting game now")


## Fires for every avatar request made anywhere in the game, not just the
## ones this screen started, so this only reacts if the result belongs to a
## card currently being shown here, and only if that card is still alive.
func _on_avatar_loaded(avatar_id: int, width: int, data: PackedByteArray) -> void:
	if not _player_cards.has(avatar_id):
		return

	var card: Node = _player_cards[avatar_id]
	if not is_instance_valid(card):
		return

	var avatar_image: Image = Image.create_from_data(width, width, false, Image.FORMAT_RGBA8, data)
	var avatar_texture: ImageTexture = ImageTexture.create_from_image(avatar_image)
	card.set_avatar(avatar_texture)


# ---- Host controls ----

## Shows Start, Mode, and Map to everyone, but only lets the current host
## interact with them. Left visible rather than hidden for non-hosts so
## everyone can see what the host is choosing once those are wired up.
func _refresh_host_controls() -> void:
	var is_host: bool = LobbyManager.is_local_player_host()
	_mode_button.disabled = not is_host
	_map_button.disabled = not is_host


# ---- Button handlers ----

func _on_copy_join_code_pressed() -> void:
	DisplayServer.clipboard_set(LobbyManager.join_code)
	var original_text: String = %CopyJoinCode.text
	%CopyJoinCode.text = "Copied!"
	await get_tree().create_timer(1.0).timeout
	%CopyJoinCode.text = original_text


func _on_invite_pressed() -> void:
	Steam.activateGameOverlayInviteDialog(LobbyManager.lobby_id)


func _on_ready_toggled(toggled_on:bool) -> void:
	Steam.setLobbyMemberData(LobbyManager.lobby_id, "ready", "1" if toggled_on else "0")


func _on_leave_pressed() -> void:
	LobbyManager.leave_lobby()
	MenuManager.go_back()
