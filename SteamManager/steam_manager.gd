extends Node

## Owns Steamworks initialization and basic local player identity.
##
## Autoloaded as a script rather than a scene, since this holds no exported
## node references and needs nothing assigned in the editor. Initializes
## Steam as early as possible, before any menu screen becomes visible, so
## Steam overlay and launch arguments behave correctly. Runs Steam's callback
## pump every frame once initialized, per GodotSteam's recommended pattern.


## Emitted once after steamInitEx() resolves, whether it succeeded or not.
## success is false if the Steam client isn't running, the app ID is wrong,
## or any other init failure occurred. message is the human readable reason,
## useful for the connecting screen to display on failure.
signal steam_initialized(success: bool, message: String)

## Emitted after the local player's avatar texture has finished downloading
## and been converted to a usable ImageTexture.
signal avatar_ready(texture: ImageTexture)

## Emitted after a getNumberOfCurrentPlayers() request resolves. success is
## false if Steam could not fulfill the request, in which case player_count
## should not be used.
signal player_count_received(success: bool, player_count: int)


## True once steamInitEx() has reported success. Callbacks are only pumped
## in _process() while this is true.
var is_steam_initialized: bool = false

## Steam ID64 of the local player. Zero until initialization succeeds.
var local_steam_id: int = 0

## Local player's current display name. Empty until initialization succeeds.
var local_steam_name: String = ""

## Local player's avatar, once avatar_ready has fired. Null until then.
var local_avatar_texture: ImageTexture = null

## Reason Steam failed to initialize, if it did. Empty string if
## initialization succeeded or has not been attempted yet.
var init_failure_message: String = ""

func _ready() -> void:
	Steam.avatar_loaded.connect(_on_avatar_loaded)
	Steam.number_of_current_players.connect(_on_number_of_current_players)
	_initialize_steam()


func _process(_delta: float) -> void:
	if is_steam_initialized:
		Steam.run_callbacks()


## Attempts to bring up the Steamworks API. app_id is picked up from
## steam_appid.txt during editor testing, so it does not need to be passed
## explicitly here. embed_callbacks is left false since run_callbacks() is
## handled manually in _process() instead.
func _initialize_steam() -> void:
	var init_result: Dictionary = Steam.steamInitEx()

	if init_result["status"] != Steam.STEAM_API_INIT_RESULT_OK:
		is_steam_initialized = false
		init_failure_message = init_result["verbal"]
		push_error("SteamManager: init failed, status %s, %s" % [init_result["status"], init_result["verbal"]])
		steam_initialized.emit(false, init_result["verbal"])
		return

	is_steam_initialized = true
	local_steam_id = Steam.getSteamID()
	local_steam_name = Steam.getPersonaName()

	steam_initialized.emit(true, init_result["verbal"])

	# Size 2 requests the medium (64x64) avatar. Result arrives async via the
	# avatar_loaded signal, not as a return value from this call.
	Steam.getPlayerAvatar(2, local_steam_id)

## Asks Steam for the current number of players across the whole game, both
## online and offline. Result arrives async via player_count_received, not as
## a return value from this call.
func request_player_count() -> void:
	if not is_steam_initialized:
		player_count_received.emit(false, 0)
		return

	Steam.getNumberOfCurrentPlayers()

func _on_number_of_current_players(success: int, players: int) -> void:
	player_count_received.emit(success == 1, players)

## Fires whenever an avatar finishes downloading, for any Steam ID that has
## been requested, not only the local player. Ignores avatars for anyone
## other than the local player for now, since this manager only tracks local
## identity, not friends or lobby members.
func _on_avatar_loaded(avatar_id: int, width: int, data: PackedByteArray) -> void:
	if avatar_id != local_steam_id:
		return

	var avatar_image: Image = Image.create_from_data(width, width, false, Image.FORMAT_RGBA8, data)
	local_avatar_texture = ImageTexture.create_from_image(avatar_image)

	avatar_ready.emit(local_avatar_texture)
