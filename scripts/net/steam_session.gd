extends Node
class_name SteamSession

signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal peer_connected(steam_id: int)
signal peer_disconnected(steam_id: int)
@warning_ignore("unused_signal")
signal packets_ready

const CHANNEL := 0
const MAX_PACKET := 8192
const CONNECTION_STATE_CONNECTING := 1
const CONNECTION_STATE_FINDING_ROUTE := 2
const CONNECTION_STATE_CONNECTED := 3
const CONNECTION_STATE_CLOSED_BY_PEER := 4
const CONNECTION_STATE_PROBLEM_DETECTED := 5

var steam := Engine.get_singleton("Steam")
var relay_required := true
var lobby_id: int = 0
var listen_socket: int = 0
var connection_handles := {}      # handle -> steam_id
var packet_queue: Array[Dictionary] = []
var local_steam_id: int = 0

func _ready() -> void:
	# For printing Singlas sent out by the singleton
	#for sig in steam.get_signal_list():
		#var name := str(sig.get("name", ""))
		#if name.findn("network") != -1:
			#print("Steam signal:", name)

	steam.allowP2PPacketRelay(relay_required)
	local_steam_id = steam.getSteamID() if steam.has_method("getSteamID") else 0
	steam.connect("lobby_created", Callable(self, "_on_lobby_created"))
	steam.connect("lobby_joined", Callable(self, "_on_lobby_joined"))
	steam.connect("network_connection_status_changed", Callable(self, "_on_connection_status"))

func host(max_players := 4) -> void:
	steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, max_players)

func join(target_lobby: int) -> void:
	steam.joinLobby(target_lobby)

func _on_lobby_created(result: int, created_lobby_id: int) -> void:
	if result != Steam.RESULT_OK:
		push_error("Steam lobby creation failed: %s" % str(result))
		return
	lobby_id = created_lobby_id
	steam.setLobbyData(lobby_id, "host_id", str(local_steam_id))
	listen_socket = steam.createListenSocketP2P(CHANNEL, {})
	print("Steam lobby ID:", lobby_id)  # <-- add this line
	emit_signal("lobby_created", lobby_id)

@warning_ignore("unused_parameter")
func _on_lobby_joined(joined_lobby_id: int, permissions: int, locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		push_error("Failed to join lobby %s (response %d)" % [joined_lobby_id, response])
		return
	lobby_id = joined_lobby_id
	emit_signal("lobby_joined", lobby_id)
	var host_str: String = steam.getLobbyData(lobby_id, "host_id")
	if host_str != "":
		var host_id := int(host_str)
		steam.connectP2P(host_id, CHANNEL, {})

func _on_connection_status(connection_handle: int, arg1: Variant, arg2: Variant) -> void:
	var state: int
	var remote_id: int

	if arg1 is Dictionary:
		state = int(arg1.get("connection_state", 0))
		remote_id = int(arg1.get("remote_steam_id", 0))
	elif arg2 is Dictionary:
		state = int(arg2.get("connection_state", 0))
		remote_id = int(arg2.get("remote_steam_id", 0))
	else:
		print("Unexpected payload steam_session.gd 79")
		return  # unexpected payload

	match state:
		CONNECTION_STATE_CONNECTING, CONNECTION_STATE_FINDING_ROUTE:
			steam.acceptConnection(connection_handle)
		CONNECTION_STATE_CONNECTED:
			connection_handles[connection_handle] = remote_id
			emit_signal("peer_connected", remote_id)
		CONNECTION_STATE_CLOSED_BY_PEER, CONNECTION_STATE_PROBLEM_DETECTED:
			connection_handles.erase(connection_handle)
			emit_signal("peer_disconnected", remote_id)


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
