extends Node

## Owns creation, joining, and membership tracking for the current Steam
## lobby. Holds at most one lobby at a time. Screens read lobby state
## through this manager rather than talking to the Steam singleton directly,
## so the lobby data format only needs to be known in one place.

## Value used to identify lobbies belonging to this game
var project_tag: String = ProjectSettings.get_setting("application/config/name")

## Lobby data key holding the project tag value above.
const PROJECT_TAG_KEY: String = "project"

## Lobby data key holding the 4 digit code players can use to join directly.
const JOIN_CODE_KEY: String = "join_code"


## Emitted after a createLobby() request resolves. success is false if Steam
## could not create the lobby, in which case lobby_id and join_code should
## not be used.
signal lobby_created(success: bool)

## Emitted after successfully entering a lobby, whether hosting a new one or
## joining an existing one.
signal lobby_joined()

## Emitted after leaving the current lobby, either voluntarily or because it
## closed. Listeners should treat this as "no longer in a lobby."
signal lobby_left()

## Emitted whenever lobby membership changes, someone joining or leaving.
## Carries no data, listeners should re-read get_member_steam_ids().
signal lobby_members_changed()


## Steam ID64 of the lobby currently joined, or 0 if not in a lobby.
var lobby_id: int = 0

## The 4 digit code for the current lobby, or an empty string if not
## hosting. Only ever set by the host, the join-by-code flow that reads this
## back out for a joining player is not built yet.
var join_code: String = ""


func _ready() -> void:
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)


## True if the local player currently owns the joined lobby. Ownership can
## move if the host leaves and Steam promotes someone else, so this is
## computed fresh each call rather than cached.
func is_local_player_host() -> bool:
	if lobby_id == 0:
		return false
	return Steam.getLobbyOwner(lobby_id) == SteamManager.local_steam_id


## Steam ID64 of the current lobby's owner, or 0 if not in a lobby.
func get_host_steam_id() -> int:
	if lobby_id == 0:
		return 0
	return Steam.getLobbyOwner(lobby_id)


## Steam ID64s of every player currently in the lobby, queried live from
## Steam rather than cached, since membership can change at any time.
func get_member_steam_ids() -> Array[int]:
	var result: Array[int] = []

	if lobby_id == 0:
		return result

	var member_count: int = Steam.getNumLobbyMembers(lobby_id)
	for i in range(member_count):
		result.append(Steam.getLobbyMemberByIndex(lobby_id, i))

	return result


## Requests creation of a new public lobby with the given player cap. Result
## arrives async via lobby_created.
func create_lobby(max_players: int = 4) -> void:
	Steam.createLobby(Steam.LobbyType.LOBBY_TYPE_PUBLIC, max_players)


## Leaves the currently joined lobby, if any, and resets local lobby state.
func leave_lobby() -> void:
	if lobby_id == 0:
		return

	Steam.leaveLobby(lobby_id)
	lobby_id = 0
	join_code = ""
	lobby_left.emit()


func _on_lobby_created(connect_status: int, new_lobby_id: int) -> void:
	if connect_status != Steam.Result.RESULT_OK:
		push_error("LobbyManager: failed to create lobby, status %s" % connect_status)
		lobby_created.emit(false)
		return

	lobby_id = new_lobby_id
	join_code = _generate_join_code()

	if not Steam.setLobbyData(lobby_id, PROJECT_TAG_KEY, project_tag):
		push_warning("LobbyManager: failed to set project tag on lobby %s" % lobby_id)
	if not Steam.setLobbyData(lobby_id, JOIN_CODE_KEY, join_code):
		push_warning("LobbyManager: failed to set join code on lobby %s" % lobby_id)

	lobby_created.emit(true)


func _on_lobby_joined(joined_lobby_id: int, _permissions, _locked, response: int) -> void:
	if response != Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		push_error("LobbyManager: failed to join lobby %s, response %s" % [joined_lobby_id, response])
		return

	lobby_id = joined_lobby_id
	lobby_joined.emit()


func _on_lobby_chat_update(updated_lobby_id: int, _changed_id: int, _making_change_id: int, _chat_state: int) -> void:
	if updated_lobby_id != lobby_id:
		return
	lobby_members_changed.emit()


## Produces a 4 digit numeric string, "0000" through "9999". Not guaranteed
## unique across every currently open lobby, Steam has no built-in concept
## of that. Good enough for a small group of friends typing a code to find
## each other, not meant as a strong identifier.
func _generate_join_code() -> String:
	return "%04d" % (randi() % 10000)
