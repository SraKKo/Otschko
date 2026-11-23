extends RefCounted

signal tampered

var _mask: int
var _masked: int
var _checksum: int

func _init(initial: int) -> void:
	_mask = Crypto.new().generate_random_bytes(8).decode_s64(0)
	set_value(initial)

func set_value(value: int) -> void:
	_masked = value ^ _mask
	_checksum = hash(Vector2i(value & 0x7fffffff, _mask & 0x7fffffff)) ^ hash(value)

func get_value() -> int:
	var value := _masked ^ _mask
	if _checksum == (hash(Vector2i(value & 0x7fffffff, _mask & 0x7fffffff)) ^ hash(value)):
		return value
	set_value(0)
	tampered.emit()
	return 0

func simulate_tamper() -> void:
	if OS.is_debug_build(): _masked ^= 16
