extends Node

# keep your organization & names
const STEAM_PATH := "res://steamIntegration/"
const STEAM_DLL := "res://steamIntegration/windows/steam_api64.dll"
const APPID_SRC := "res://steamIntegration/steam_appid.txt"
const APPID_DEST := "user://steam_appid.txt"

var steam_ok: bool = false

func _ready() -> void:
	# write to your chosen user:// path (your original flow)
	var appid_file = FileAccess.open(APPID_DEST, FileAccess.WRITE)
	if appid_file:
		var src = FileAccess.open(APPID_SRC, FileAccess.READ)
		if src:
			appid_file.store_string(src.get_as_text())
			src.close()
		appid_file.close()

	# also write next to the running EXE when testing locally
	if OS.is_debug_build():
		var exe_dir := OS.get_executable_path().get_base_dir()
		var exe_appid := exe_dir.path_join("steam_appid.txt")
		var src2 = FileAccess.open(APPID_SRC, FileAccess.READ)
		if src2:
			var txt := src2.get_as_text()
			src2.close()
			var f = FileAccess.open(exe_appid, FileAccess.WRITE)
			if f:
				f.store_string(txt)
				f.close()

	# initialize steam
	if Engine.has_singleton("Steam"):
		var steam = Engine.get_singleton("Steam")
		if steam.has_method("steamInit"):
			var init_res = steam.steamInit()
			steam_ok = init_res == true
			print("steamInit: ", init_res)

	# optional: quick sanity output (remove later if noisy)
	call_deferred("_print_core_state")

func _process(_dt: float) -> void:
	if Engine.has_singleton("Steam"):
		var steam = Engine.get_singleton("Steam")
		if steam.has_method("run_callbacks"):
			steam.run_callbacks()

# convenience accessors
func is_logged_on() -> bool:
	if !Engine.has_singleton("Steam"): return false
	var s = Engine.get_singleton("Steam")
	return s.loggedOn() if s.has_method("loggedOn") else false

func get_app_id() -> int:
	if !Engine.has_singleton("Steam"): return 0
	var s = Engine.get_singleton("Steam")
	return s.getAppID() if s.has_method("getAppID") else 0

func get_persona_name() -> String:
	if !Engine.has_singleton("Steam"): return ""
	var s = Engine.get_singleton("Steam")
	return s.getPersonaName() if s.has_method("getPersonaName") else ""

func get_steam_id() -> int:
	if !Engine.has_singleton("Steam"): return 0
	var s = Engine.get_singleton("Steam")
	return s.getSteamID() if s.has_method("getSteamID") else 0

func _print_core_state() -> void:
	if !Engine.has_singleton("Steam"):
		print("No Steam singleton"); return
	print("AppID: ", get_app_id())
	print("IsLoggedOn: ", is_logged_on())
	print("SteamID: ", get_steam_id())
	print("Persona: '", get_persona_name(), "'")
