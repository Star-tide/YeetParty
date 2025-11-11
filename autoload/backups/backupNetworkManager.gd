extends Node

const STEAM_PATH := "res://steamIntegration/"
const STEAM_DLL := "res://steamIntegration/windows/steam_api64.dll"
const APPID_SRC := "res://steamIntegration/steam_appid.txt"
const APPID_DEST := "user://steam_appid.txt"

func _ready():
	# Ensure steam_appid.txt exists where Steam expects it (working dir)
	var appid_file = FileAccess.open(APPID_DEST, FileAccess.WRITE)
	if appid_file:
		var src = FileAccess.open(APPID_SRC, FileAccess.READ)
		if src:
			appid_file.store_string(src.get_as_text())
			src.close()
		appid_file.close()
	if Engine.has_singleton("Steam"):
		var steam := Engine.get_singleton("Steam")
		if steam.has_method("steamInit"):
			var init_res = steam.steamInit()
			print("steamInit: ", init_res)  # should show status 1 on success
	call_deferred("_check_steam")

func _check_steam():
	if !Engine.has_singleton("Steam"):
		print("No Steam singleton")
		return

	var steam = Engine.get_singleton("Steam")

	# Print core state
	print("AppID: ", steam.getAppID() if steam.has_method("getAppID") else "(method missing)")
	print("PersonaState: ", steam.getPersonaState() if steam.has_method("getPersonaState") else "(method missing)")
	print("SteamID: ", steam.getSteamID() if steam.has_method("getSteamID") else "(method missing)")
	print("Persona (immediate): '", steam.getPersonaName() if steam.has_method("getPersonaName") else "", "'")

	# Re-check after a short wait to allow callbacks to populate
	await get_tree().create_timer(0.5).timeout
	if steam.has_method("getPersonaName"):
		print("IsLoggedOn: ", steam.loggedOn() if steam.has_method("loggedOn") else false)
		print("Persona (after 500ms): '", steam.getPersonaName(), "'")

	# Attempt to preload Steam
	print("Has Steam singleton? ", Engine.has_singleton("Steam"))
	if Engine.has_singleton("Steam"):
		if steam.has_method("isSteamRunning"):
			print("Steam running? ", steam.isSteamRunning())
			if steam.isSteamRunning() and steam.has_method("getPersonaName"):
				print("Persona: ", steam.getPersonaName())

func _process(_dt: float) -> void:
	if Engine.has_singleton("Steam"):
		Engine.get_singleton("Steam").run_callbacks()
