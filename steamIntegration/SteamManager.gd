extends Node

# (Optional) helpers so the rest of your game doesn’t touch the singleton directly
func is_logged_on() -> bool:
	if !Engine.has_singleton("Steam"): return false
	var s := Engine.get_singleton("Steam")
	return s.loggedOn() if s.has_method("loggedOn") else false

func persona_name() -> String:
	if !Engine.has_singleton("Steam"): return ""
	var s := Engine.get_singleton("Steam")
	return s.getPersonaName() if s.has_method("getPersonaName") else ""

func app_id() -> int:
	if !Engine.has_singleton("Steam"): return 0
	var s := Engine.get_singleton("Steam")
	return s.getAppID() if s.has_method("getAppID") else 0
