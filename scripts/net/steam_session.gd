extends Node
class_name SteamSession

signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal peer_connected(steam_id: int)
signal peer_disconnected(steam_id: int)
@warning_ignore("unused_signal")
signal packets_ready
signal lobby_code_assigned(code: String)
signal lobby_code_lookup_succeeded(code: String, lobby_id: int)
signal lobby_code_lookup_failed(code: String)

const CHANNEL := 0
const MAX_PACKET := 8192
const CONNECTION_STATE_CONNECTING := 1
const CONNECTION_STATE_FINDING_ROUTE := 2
const CONNECTION_STATE_CONNECTED := 3
const CONNECTION_STATE_CLOSED_BY_PEER := 4
const CONNECTION_STATE_PROBLEM_DETECTED := 5
const LOBBY_CODE_KEY := "short_code"

var steam := Engine.get_singleton("Steam")
var relay_required := true
var lobby_id: int = 0
var listen_socket: int = 0
var connection_handles := {}      # handle -> steam_id
var packet_queue: Array[Dictionary] = []
var local_steam_id: int = 0
var hosting := false
var lobby_code: String = ""
var pending_lobby_code_lookup: String = ""
var lobby_code_rng := RandomNumberGenerator.new()

func _ready() -> void:
	# For printing Singlas sent out by the singleton
	#for sig in steam.get_signal_list():
		#var name := str(sig.get("name", ""))
		#if name.findn("network") != -1:
			#print("Steam signal:", name)

	steam.allowP2PPacketRelay(relay_required)
	local_steam_id = steam.getSteamID() if steam.has_method("getSteamID") else 0
	lobby_code_rng.randomize()
	steam.connect("lobby_created", Callable(self, "_on_lobby_created"))
	steam.connect("lobby_joined", Callable(self, "_on_lobby_joined"))
	steam.connect("network_connection_status_changed", Callable(self, "_on_connection_status"))
	if steam.has_signal("lobby_match_list"):
		steam.connect("lobby_match_list", Callable(self, "_on_lobby_match_list"))

func host(max_players := 4) -> void:
	hosting = true
	steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, max_players)

func join(target_lobby: int) -> void:
	hosting = false
	steam.joinLobby(target_lobby)

func _on_lobby_created(result: int, created_lobby_id: int) -> void:
	if result != Steam.RESULT_OK:
		push_error("Steam lobby creation failed: %s" % str(result))
		return
	lobby_id = created_lobby_id
	steam.setLobbyData(lobby_id, "host_id", str(local_steam_id))
	_assign_lobby_code()
	listen_socket = steam.createListenSocketP2P(CHANNEL, {})
	print("Steam lobby ID:", lobby_id)  # <-- add this line
	emit_signal("lobby_created", lobby_id)

@warning_ignore("unused_parameter")
func _on_lobby_joined(joined_lobby_id: int, permissions: int, locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		push_error("Failed to join lobby %s (response %d)" % [joined_lobby_id, response])
		return
	lobby_id = joined_lobby_id
	if steam.has_method("getLobbyData"):
		lobby_code = steam.getLobbyData(lobby_id, LOBBY_CODE_KEY)
	emit_signal("lobby_joined", lobby_id)
	var host_str: String = steam.getLobbyData(lobby_id, "host_id")
	if host_str != "":
		var host_id := int(host_str)
		steam.connectP2P(host_id, CHANNEL, {})

func _on_connection_status(connection_handle: int, arg1: Variant, arg2: Variant) -> void:
	var state: int = 0
	var remote_id: int = 0

	if arg1 is Dictionary:
		state = int(arg1.get("connection_state", 0))
		remote_id = int(arg1.get("remote_steam_id", 0))
	elif arg2 is Dictionary:
		state = int(arg2.get("connection_state", 0))
		remote_id = int(arg2.get("remote_steam_id", 0))

	if remote_id == 0 and steam.has_method("getConnectionInfo"):
		var info: Dictionary = steam.getConnectionInfo(connection_handle)
		var identity_value: Variant = info.get("identity", null)
		var identity_id := 0
		if identity_value is Dictionary:
			var identity: Dictionary = identity_value
			if identity.has("steam_id"):
				identity_id = int(identity["steam_id"])
		elif identity_value is int:
			identity_id = identity_value

		if identity_id == local_steam_id:
			return

		print("Connection info:", info)
		if identity_id != 0:
			remote_id = identity_id

	if hosting and remote_id == local_steam_id:
		return

	match state:
		CONNECTION_STATE_CONNECTING, CONNECTION_STATE_FINDING_ROUTE:
			print("Trying to connect…")
			steam.acceptConnection(connection_handle)
		CONNECTION_STATE_CONNECTED:
			print("Peer connected! remote:", remote_id)
			connection_handles[connection_handle] = remote_id
			emit_signal("peer_connected", remote_id)
		CONNECTION_STATE_CLOSED_BY_PEER, CONNECTION_STATE_PROBLEM_DETECTED:
			connection_handles.erase(connection_handle)
			emit_signal("peer_disconnected", remote_id)

func request_lobby_id_for_code(code: String) -> void:
	var normalized := LobbyCode.normalize(code)
	if normalized.is_empty():
		_emit_lobby_code_lookup_failed(code)
		return

	if not steam.has_method("requestLobbyList"):
		_emit_lobby_code_lookup_failed(normalized)
		return

	pending_lobby_code_lookup = normalized
	if steam.has_method("addRequestLobbyListStringFilter"):
		steam.addRequestLobbyListStringFilter(LOBBY_CODE_KEY, pending_lobby_code_lookup, Steam.LOBBY_COMPARISON_EQUAL)
	steam.requestLobbyList()

func get_lobby_code() -> String:
	return lobby_code

func _assign_lobby_code() -> void:
	lobby_code = LobbyCode.generate(LobbyCode.DEFAULT_LENGTH, lobby_code_rng)
	if steam.has_method("setLobbyData"):
		steam.setLobbyData(lobby_id, LOBBY_CODE_KEY, lobby_code)
	print("Lobby short code:", lobby_code)
	emit_signal("lobby_code_assigned", lobby_code)

func _on_lobby_match_list(lobby_count: int) -> void:
	if pending_lobby_code_lookup == "":
		return
	if lobby_count <= 0 or not steam.has_method("getLobbyByIndex"):
		_emit_lobby_code_lookup_failed()
		return

	for i in range(lobby_count):
		var found_lobby_id: int = int(steam.getLobbyByIndex(i))
		if found_lobby_id == 0:
			continue
		var code: String = steam.getLobbyData(found_lobby_id, LOBBY_CODE_KEY)
		if LobbyCode.normalize(code) == pending_lobby_code_lookup:
			var resolved_code := pending_lobby_code_lookup
			pending_lobby_code_lookup = ""
			emit_signal("lobby_code_lookup_succeeded", resolved_code, found_lobby_id)
			return

	_emit_lobby_code_lookup_failed()

func _emit_lobby_code_lookup_failed(failed_code: String = "") -> void:
	var code_to_report := failed_code if failed_code != "" else pending_lobby_code_lookup
	pending_lobby_code_lookup = ""
	emit_signal("lobby_code_lookup_failed", code_to_report)


func send(handle: int, payload: PackedByteArray, reliable := true) -> void:
	var flags := Steam.NETWORKING_SEND_RELIABLE if reliable else Steam.NETWORKING_SEND_UNRELIABLE
	steam.sendMessageToConnection(handle, payload, flags, CHANNEL)
	
func poll_packets() -> Array[Dictionary]:
	var drained := packet_queue.duplicate()
	packet_queue.clear()
	return drained
	
func get_handle_for_peer(steam_id: int) -> int:
	for handle in connection_handles:
		if connection_handles[handle] == steam_id:
			return handle
	return 0
	
func get_local_steam_id() -> int:
	return steam.getSteamID() if steam.has_method("getSteamID") else 0
