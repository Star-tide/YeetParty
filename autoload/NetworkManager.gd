extends Node

const STEAM_PATH := "res://steamIntegration/"
const STEAM_DLL := "res://steamIntegration/windows/steam_api64.dll"
const APPID_SRC := "res://steamIntegration/steam_appid.txt"
const APPID_DEST := "user://steam_appid.txt"

const STEAM_MANAGER_SCN := "res://steamIntegration/SteamManager.gd"
const STEAM_SESSION := preload("res://scripts/net/steam_session.gd")
const STEAM_BUS := preload("res://scripts/net/steam_message_bus.gd")

var _steam_ok: bool = false
var _steam_manager: Node = null
var _enet_peer: ENetMultiplayerPeer = null
var current_backend := "steam"
var steam_session: SteamSession = null
var steam_bus: SteamMessageBus = null

func _ready() -> void:
	# Your existing write (kept as-is)
	var appid_file := FileAccess.open(APPID_DEST, FileAccess.WRITE)
	if appid_file:
		var src := FileAccess.open(APPID_SRC, FileAccess.READ)
		if src:
			appid_file.store_string(src.get_as_text())
			src.close()
		appid_file.close()

	# Optional: also drop next to running EXE when debugging locally
	if OS.is_debug_build():
		var exe_dir := OS.get_executable_path().get_base_dir()
		var exe_appid := exe_dir.path_join("steam_appid.txt")
		var src2 := FileAccess.open(APPID_SRC, FileAccess.READ)
		if src2:
			var txt := src2.get_as_text()
			src2.close()
			var f := FileAccess.open(exe_appid, FileAccess.WRITE)
			if f:
				f.store_string(txt)
				f.close()

	# Decide: Steam or ENet
	_try_init_steam()
	if _steam_ok:
		current_backend = "steam"
		steam_session = STEAM_SESSION.new()
		add_child(steam_session)
		steam_bus = STEAM_BUS.new()
		add_child(steam_bus)
		steam_bus.setup(steam_session, true) # just prepares signals/maps
		steam_bus.connect("peer_connected", Callable(self, "_on_steam_peer_connected"))
		_start_steam_manager()
	else:
		_init_enet_fallback()
		current_backend = "enet"

	# (Optional) quick print so you can see which path was chosen
	print("Network path: ", "Steam" if _steam_ok else "ENet fallback")

func host_game(max_players := 4) -> void:
	if _steam_ok and steam_session:
		steam_session.host(max_players)
	else:
		_init_enet_fallback()

func join_game(target: Variant) -> void:
	if _steam_ok and steam_session:
		if typeof(target) == TYPE_INT:
			steam_session.join(target) #lobby ID
		elif typeof(target) == TYPE_STRING:
			enet_join(target)
			
func _process(_dt: float) -> void:
	if _steam_ok and Engine.has_singleton("Steam"):
		var s := Engine.get_singleton("Steam")
		if s.has_method("run_callbacks"):
			s.run_callbacks()

# -------------------- Steam path --------------------
func _try_init_steam() -> void:
	_steam_ok = false
	if !Engine.has_singleton("Steam"):
		return
	var s := Engine.get_singleton("Steam")
	if s.has_method("steamInit"):
		var init_res = s.steamInit()
		_steam_ok = (init_res == true)
		print("steamInit: ", init_res)
		if _steam_ok:
			# quick sanity
			var logged_on = s.loggedOn() if s.has_method("loggedOn") else false
			print("AppID: ", s.getAppID() if s.has_method("getAppID") else 0)
			print("IsLoggedOn: ", logged_on)
			print("Persona: ", s.getPersonaName() if s.has_method("getPersonaName") else "")

func _on_steam_peer_connected(peer_id: int) -> void:
	print("NetworkManager saw peer", peer_id)
	emit_signal("steam_peer_connected", peer_id)

func _start_steam_manager() -> void:
	var SteamManager := load(STEAM_MANAGER_SCN)
	if SteamManager:
		_steam_manager = SteamManager.new()
		add_child(_steam_manager)

# -------------------- ENet fallback (DRM-free) --------------------
func _init_enet_fallback(port: int = 19000, max_clients: int = 16) -> void:
	_enet_peer = ENetMultiplayerPeer.new()
	var err := _enet_peer.create_server(port, max_clients)
	if err != OK:
		push_error("ENet server failed: " + str(err))
		return
	get_tree().get_multiplayer().multiplayer_peer = _enet_peer
	print("ENet server listening on port ", port)

# Optional: call this from your UI to join instead of host
func enet_join(address: String, port: int = 19000) -> void:
	_enet_peer = ENetMultiplayerPeer.new()
	var err := _enet_peer.create_client(address, port)
	if err != OK:
		push_error("ENet client failed: " + str(err))
		return
	get_tree().get_multiplayer().multiplayer_peer = _enet_peer
	print("ENet client connecting to %s:%d" % [address, port])
