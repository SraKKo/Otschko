extends Node

const GRACE_SECONDS := 7 * 24 * 60 * 60
const Integrity := preload("res://Scripts/SaveIntegrity.gd")
const ALLOWED_HOSTS := ["itch.io", "itch.zone", "localhost", "127.0.0.1"]

var client: Node
var verification_mode := false
var authorized := false
var bypass := false
var offline := false
var simulate_network_persisted := true

func _ready() -> void:
	client = preload("res://Scripts/DswCloudClient.gd").new()
	add_child(client)
	bypass = UserSession.legacy_check
	for arg in OS.get_cmdline_user_args():
		if OS.is_debug_build() and (arg.begins_with("--verify-users=") or arg.begins_with("--verify-cloud=") or arg.begins_with("--verify-localization=")):
			bypass = true
			simulate_network_persisted = false
		if arg.begins_with("--drm-api-url=http://127.0.0.1:") and OS.is_debug_build():
			client.base_url = arg.trim_prefix("--drm-api-url=")
	verification_mode = OS.is_debug_build() and client.base_url.begins_with("http://127.0.0.1:") and "--verify-drm" in OS.get_cmdline_user_args()
	if simulate_network_persisted and not bypass:
		var settings: Variant = UserSession._read_json(UserSession.profiles_dir.path_join("simulated-network.json"))
		if settings is Dictionary and settings.get("offline") == true:
			UserSession.online = false
			UserSession.network_changed.emit(false)

func begin_session() -> void:
	authorized = bypass
	offline = false

func end_session() -> void:
	authorized = false
	offline = false

static func host_allowed(host: String) -> bool:
	var normalized := host.to_lower().trim_suffix(".")
	for domain: String in ALLOWED_HOSTS:
		if normalized == domain: return true
		if domain != "localhost" and domain != "127.0.0.1" and normalized.ends_with("." + domain): return true
	return false

func site_allowed() -> bool:
	if not OS.has_feature("web"): return true
	return host_allowed(str(JavaScriptBridge.eval("window.location.hostname")))

func _path(id: String) -> String:
	return UserSession.profiles_dir.path_join(id + ".license.json")

func _scope(profile: Dictionary) -> String:
	return "license:%s:%s" % [profile.id, profile.name]

func _cached(profile: Dictionary) -> Dictionary:
	return Integrity.unseal(_scope(profile), UserSession._read_json(_path(str(profile.id))))

func active_key() -> String:
	if not authorized or UserSession.primary.is_empty(): return ""
	return str(_cached(UserSession.primary).get("key", ""))

func _store(profile: Dictionary, key: String, checked: int) -> bool:
	return UserSession._write_json(_path(str(profile.id)), Integrity.seal(_scope(profile), {"key": key, "checked": checked}))

func check(profile: Dictionary) -> Dictionary:
	var saved := _cached(profile)
	var key := str(saved.get("key", ""))
	if key.is_empty(): return {"error": "missing_license"}
	var result: Dictionary = await client.check_license(str(profile.name), key)
	if result.get("ok") == true and result.get("valid") == true:
		var stored := _store(profile, key, int(Time.get_unix_time_from_system()))
		return {"allowed": true, "stored": stored}
	if result.get("error") in ["network", "offline"] or int(result.get("httpCode", 0)) >= 500:
		var age := int(Time.get_unix_time_from_system()) - int(saved.get("checked", 0))
		if age >= 0 and age < GRACE_SECONDS: return {"allowed": true, "offline": true}
		return {"error": "offline_expired"}
	if result.get("ok") == true and result.get("valid") == false:
		_store(profile, key, 0)
		return {"error": "invalid_license"}
	if result.get("error") == "invalid_license":
		_store(profile, key, 0)
	return result

func activate(profile: Dictionary, key: String) -> Dictionary:
	var cached := _cached(profile)
	var result: Dictionary = await client.activate_license(str(profile.name), key)
	if result.get("ok") != true:
		# Recover when the activation succeeded but its response was lost.
		if result.get("error") != "already_activated": return result
		var ownership: Dictionary = await client.check_license(str(profile.name), key)
		if ownership.get("ok") != true or ownership.get("valid") != true: return result
	var previous := int(cached.get("checked", 0)) if cached.get("key") == key else 0
	if not _store(profile, key, previous): return {"error": "local_license"}
	return await check(profile)

func message(result: Dictionary) -> String:
	match result.get("error", ""):
		"missing_license": return "LOC_LICENSE_MISSING"
		"invalid_license": return "LOC_LICENSE_INVALID"
		"already_activated": return "LOC_LICENSE_TAKEN"
		"network", "offline": return "LOC_LICENSE_OFFLINE"
		"offline_expired": return "LOC_LICENSE_EXPIRED"
		"local_license": return "LOC_LICENSE_SAVE_ERROR"
		_: return "LOC_LICENSE_SERVICE_ERROR"
