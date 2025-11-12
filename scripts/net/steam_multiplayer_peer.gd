extends MultiplayerPeerExtension
class_name SteamMultiplayerPeer

var session: SteamSession
var is_server := false
var unique_id := 1
var target_peer := 0
var incoming_packets: Array[PackedByteArray] = []
var packet_senders: Array[int] = []
var connected_peers := {}  # peer_id -> connection_handle

func setup(session_ref: SteamSession, host_mode := true) -> void:
	session = session_ref
	is_server = host_mode
	unique_id = 1 if host_mode else 0  # replace later with actual SteamID mapping
	session.connect("packets_ready", Callable(self, "_on_packets_ready"))

func _poll() -> void:
	for packet_info in session.poll_packets():
		incoming_packets.append(packet_info["payload"])
		packet_senders.append(packet_info["peer_id"])
		emit_signal("peer_packet", packet_info["peer_id"])
		

func _get_available_packet_count() -> int:
	return incoming_packets.size()

func _get_packet(target_buffer: PackedByteArray, buffer_size: int) -> Error:
	if incoming_packets.is_empty():
		return ERR_UNAVAILABLE

	var packet := incoming_packets.pop_front()
	var sender := packet_senders.pop_front()
	var length := min(buffer_size, packet.size())
	target_buffer.resize(length)
	target_buffer.set_data_array(packet.slice(0, length))
	_set_packet_peer(sender)
	return OK


func _put_packet(packet: PackedByteArray) -> int:
	var handle := connected_peers.get(target_peer)
	if handle == null:
		return ERR_UNAVAILABLE
	var err := session.send(handle, packet, transfer_mode != MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	return OK if err == OK else err

		
