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
@onready var _player_list: VBoxContainer = %PlayerCards
@onready var _ready_button: Button = %ReadyButton
@onready var _mode_button: Button = %ModeButton
@onready var _map_button: Button = %MapButton
@onready var _invite_button: Button = %InviteButton
#@onready var _leave_button: Button = %LeaveButton

## Maps a member's Steam ID to the PlayerCard instance currently showing
## them, rebuilt each time _refresh_player_list runs. Used to route a
## delayed avatar_loaded result to the right card once its download
## finishes, even if that arrives after the list has already refreshed.
var _player_cards: Dictionary[int, Node] = {}


func _ready() -> void:
	#_leave_button.pressed.connect(_on_leave_pressed)
	_invite_button.pressed.connect(_on_invite_pressed)

	Steam.avatar_loaded.connect(_on_avatar_loaded)
	LobbyManager.lobby_created.connect(_on_lobby_created)
	LobbyManager.lobby_members_changed.connect(_on_lobby_state_changed)

	if LobbyManager.lobby_id != 0:
		_show_lobby()
	else:
		#_status_label.text = "Creating lobby..."
		#_join_code_label.hide()
		_refresh_host_controls()
		LobbyManager.create_lobby()


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
		var card: Node = PLAYER_CARD_SCENE.instantiate()
		_player_list.add_child(card)

		var display_name: String = Steam.getFriendPersonaName(steam_id)
		if steam_id == LobbyManager.get_host_steam_id():
			display_name += " (Host)"
		card.set_username(display_name)

		_player_cards[steam_id] = card

		if steam_id == SteamManager.local_steam_id and SteamManager.local_avatar_texture != null:
			card.set_avatar(SteamManager.local_avatar_texture)
		else:
			Steam.getPlayerAvatar(AVATAR_SIZE, steam_id)
	
	%OnlinePlayers.text = str(_player_cards.size()) + "/x Players In Lobby"

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


## Shows Start, Mode, and Map to everyone, but only lets the current host
## interact with them. Left visible rather than hidden for non-hosts so
## everyone can see what the host is choosing once those are wired up.
func _refresh_host_controls() -> void:
	var is_host: bool = LobbyManager.is_local_player_host()
	_mode_button.disabled = not is_host
	_map_button.disabled = not is_host


func _on_invite_pressed() -> void:
	Steam.activateGameOverlayInviteDialog(LobbyManager.lobby_id)


func _on_leave_pressed() -> void:
	LobbyManager.leave_lobby()
	MenuManager.go_back()
