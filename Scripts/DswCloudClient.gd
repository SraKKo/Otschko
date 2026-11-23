extends Node
## Godot equivalent of the supplied Unity CloudSave.cs. Writes start from the Save action.
const SPACE := "51796"
const KEY := "save"
var base_url := "https://dsw-cloud.dsw-ppdg.workers.dev/v1"
var request_count := 0
var post_count := 0

func cloud_user(profile_id: String) -> String:
	for profile in UserSession.profiles:
		if str(profile.id) == profile_id: return str(profile.name)
	return profile_id

func raw_path_for(user: String) -> String:
	return base_url + "/kv/" + SPACE + "/" + user.uri_encode() + "/" + KEY

func path_for(profile_id: String) -> String:
	return raw_path_for(cloud_user(profile_id))

func load_legacy_save(profile_id: String) -> Dictionary:
	return await request(HTTPClient.METHOD_GET, raw_path_for(profile_id))

func load_save(profile_id: String) -> Dictionary:
	return await request(HTTPClient.METHOD_GET, path_for(profile_id))

func save_snapshot(profile_id: String, value: String, expected_version: int) -> Dictionary:
	if expected_version < 0: return {"ok": false, "error": "missing_expected_version"}
	return await request(HTTPClient.METHOD_POST, path_for(profile_id), JSON.stringify({"value": value, "expectedVersion": expected_version}))


func new_license() -> Dictionary:
	return await request(HTTPClient.METHOD_POST, base_url + "/license/" + SPACE + "/new", "{}")

func activate_license(user: String, license: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, base_url + "/license/" + SPACE + "/activate", JSON.stringify({"user": user, "license": license}))

func check_license(user: String, license: String) -> Dictionary:
	return await request(HTTPClient.METHOD_GET, base_url + "/license/" + SPACE + "/check?license=" + license.uri_encode() + "&user=" + user.uri_encode())

func add_premium_chips(profile_id: String, amount: int) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, _premium_path(profile_id) + "/add", JSON.stringify({"amount": amount}))

func load_premium_chips(profile_id: String) -> Dictionary:
	return await request(HTTPClient.METHOD_GET, _premium_path(profile_id))

func _premium_path(profile_id: String) -> String:
	return base_url + "/kv/" + SPACE + "/" + cloud_user(profile_id).uri_encode() + "/premium_chips"

func request(method: int, url: String, body: String = "") -> Dictionary:
	if not UserSession.online: return {"ok": false, "error": "offline"}
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	request_count += 1
	if method == HTTPClient.METHOD_POST: post_count += 1
	var error := http.request(url, PackedStringArray(["Content-Type: application/json"]), method, body)
	if error != OK:
		http.queue_free()
		return {"ok": false, "error": "network", "httpCode": 0}
	var response: Array = await http.request_completed
	http.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "network", "httpCode": response[1]}
	var parsed: Variant = JSON.parse_string(response[3].get_string_from_utf8())
	if not parsed is Dictionary: return {"ok": false, "error": "bad_response", "httpCode": response[1]}
	parsed["httpCode"] = int(response[1])
	if int(response[1]) >= 400: parsed["ok"] = false
	if int(response[1]) == 409 and not parsed.has("error"): parsed["error"] = "version_conflict"
	return parsed
