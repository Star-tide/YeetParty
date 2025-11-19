extends MultiplayerPeerExtension
class_name SteamMultiplayerPeer

var session: SteamSession
var is_server := false
var unique_id := 1
var target_peer := 0
var incoming_packets: Array[PackedByteArray] = []
var packet_senders: Array[int] = []
var connected_peers := {}  # peer_id -> connection_handle
var _transfer_mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE

func setup(session_ref: SteamSession, host_mode := true) -> void:
	session = session_ref
	is_server = host_mode
	unique_id = 1 if host_mode else 0  # replace later with actual SteamID mapping
	session.connect("packets_ready", Callable(self, "_on_packets_ready"))

func _poll() -> void:
	for packet_info in session.poll_packets():
		var payload: PackedByteArray = packet_info.get("payload", PackedByteArray())
		var peer_id: int = int(packet_info.get("peer_id", 0))
		incoming_packets.append(payload)
		packet_senders.append(peer_id)
		emit_signal("peer_packet", peer_id)
		

func _get_available_packet_count() -> int:
	return incoming_packets.size()

func _get_packet(target_buffer, buffer_size: int) -> Error:
	if incoming_packets.is_empty():
		return ERR_UNAVAILABLE

	if not (target_buffer is PackedByteArray):
		return ERR_INVALID_PARAMETER

	var buffer: PackedByteArray = target_buffer
	var packet: PackedByteArray = incoming_packets.pop_front()
	var sender: int = int(packet_senders.pop_front())
	var length: int = min(buffer_size, packet.size())
	buffer.resize(length)
	for i in range(length):
		buffer[i] = packet[i]
	_assign_packet_peer(sender)
	return OK


func _put_packet(packet, _channel: int) -> Error:
	if not (packet is PackedByteArray):
		return ERR_INVALID_PARAMETER

	var payload: PackedByteArray = packet
	var handle: int = int(connected_peers.get(target_peer, 0))
	if handle == 0:
		return ERR_UNAVAILABLE
	var reliable := _transfer_mode != MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	session.send(handle, payload, reliable)
	return OK

func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_transfer_mode = mode

func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _transfer_mode

func _on_packets_ready() -> void:
	# MultiplayerPeerExtension will call _poll(), so this hook is just a placeholder for now.
	pass

func _assign_packet_peer(peer_id: int) -> void:
	if has_method("_set_packet_peer"):
		call("_set_packet_peer", peer_id)
	elif has_method("set_packet_peer"):
		call("set_packet_peer", peer_id)
