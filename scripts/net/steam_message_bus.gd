extends Node
class_name SteamMessageBus

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal packet_received(peer_id: int, payload: PackedByteArray)

var session: SteamSession
var peer_map := {}           # steam_id -> peer_id
var next_peer_id := 2        # reserve 1 for host
var local_steam_id: int = 0
var is_host := false

func setup(session_ref: SteamSession, host_mode := true) -> void:
	if session_ref == null:
		return
	session = session_ref
	is_host = host_mode
	peer_map.clear()
	next_peer_id = 2
	local_steam_id = session.get_local_steam_id()
	if is_host and local_steam_id != 0:
		peer_map[local_steam_id] = 1
	session.connect("peer_connected", Callable(self, "_on_peer_connected"))
	session.connect("peer_disconnected", Callable(self, "_on_peer_disconnected"))
	session.connect("packets_ready", Callable(self, "_on_packets_ready"))

func send_to_peer(peer_id: int, payload: PackedByteArray, reliable := true) -> void:
	var steam_id := _get_steam_id(peer_id)
	if steam_id == 0:
		return
	var handle: int = session.get_handle_for_peer(steam_id)
	if handle != 0:
		session.send(handle, payload, reliable)

func broadcast(payload: PackedByteArray, reliable := true) -> void:
	for steam_id in peer_map.keys():
		if steam_id == local_steam_id:
			continue
		var handle: int = session.get_handle_for_peer(steam_id)
		if handle != 0:
			session.send(handle, payload, reliable)

func get_peers() -> Array[int]:
	return peer_map.values()

func _get_steam_id(peer_id: int) -> int:
	for steam_id in peer_map.keys():
		if peer_map[steam_id] == peer_id:
			return steam_id
	return 0

func _on_peer_connected(steam_id: int) -> void:
	if steam_id == local_steam_id:
		return
	var peer_id := next_peer_id
	peer_map[steam_id] = peer_id
	next_peer_id += 1
	emit_signal("peer_connected", peer_id)

func _on_peer_disconnected(steam_id: int) -> void:
	var peer_id := int(peer_map.get(steam_id, 0))
	if peer_id == 0:
		return
	peer_map.erase(steam_id)
	emit_signal("peer_disconnected", peer_id)

func _on_packets_ready() -> void:
	for packet_info in session.poll_packets():
		var steam_id := int(packet_info.get("steam_id", 0))
		var payload := int(packet_info.get("payload", PackedByteArray()))
		var peer_id := int(peer_map.get(steam_id, 0))
		if peer_id != 0:
			emit_signal("packet_received", peer_id, payload)
