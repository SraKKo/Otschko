extends RefCounted

const SECRET := "otshcko-save-v2-6874db0e5ef794b51796"

static func seal(scope: String, data: Dictionary) -> Dictionary:
	var payload := JSON.stringify(data)
	return {"payload": payload, "hmac": _signature(scope, payload).hex_encode()}

static func unseal(scope: String, envelope: Variant) -> Dictionary:
	if not envelope is Dictionary: return {}
	var payload: Variant = envelope.get("payload")
	var tag: Variant = envelope.get("hmac")
	if not payload is String or not tag is String or tag.length() != 64 or not tag.is_valid_hex_number(): return {}
	if not Crypto.new().constant_time_compare(tag.hex_decode(), _signature(scope, payload)): return {}
	var data: Variant = JSON.parse_string(payload)
	return data if data is Dictionary else {}

static func _signature(scope: String, payload: String) -> PackedByteArray:
	var hmac := HMACContext.new()
	hmac.start(HashingContext.HASH_SHA256, SECRET.to_utf8_buffer())
	hmac.update((scope + "|" + payload).to_utf8_buffer())
	return hmac.finish()
