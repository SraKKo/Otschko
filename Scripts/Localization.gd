extends Node

signal changed

const LANGUAGES := ["pl", "en"]
var language := "pl"
var placeholders := RegEx.new()

func _ready() -> void:
	placeholders.compile("\\{([a-z_]+)\\}")
	if OS.is_debug_build() and "--pseudo-locale" in OS.get_cmdline_user_args():
		TranslationServer.pseudolocalization_enabled = true

func set_language(code: String) -> void:
	language = code if code in LANGUAGES else "pl"
	TranslationServer.set_locale(language)
	changed.emit()

func message(key: String, values: Dictionary = {}) -> String:
	if not TranslationServer.pseudolocalization_enabled or values.is_empty():
		return tr(key).format(values)
	# Names and other player data should survive the expanded-text test intact.
	var original := String(TranslationServer.get_translation_object(language).get_message(key))
	var args: Array = []
	for match_item in placeholders.search_all(original):
		args.append(values.get(match_item.get_string(1), match_item.get_string()))
	var masked := placeholders.sub(original.replace("%", "%%"), "%s", true)
	return String(TranslationServer.pseudolocalize(masked)) % args

func rounds_played(rounds: int) -> String:
	return tr_n("LOC_ROUNDS_PLAYED", "LOC_ROUNDS_PLAYED_MANY", rounds) % number(rounds)

func number(value: int) -> String:
	var digits := str(value)
	var start := 1 if value < 0 else 0
	var separator := " " if language == "pl" else ","
	for position in range(digits.length() - 3, start, -3):
		digits = digits.insert(position, separator)
	return digits

func decimal(value: float, places: int) -> String:
	var formatted := ("%." + str(places) + "f") % value
	return formatted.replace(".", ",") if language == "pl" else formatted

func date_time(timestamp: int) -> String:
	var date := Time.get_datetime_dict_from_unix_time(timestamp)
	var clock := "%02d:%02d:%02d" % [date.hour, date.minute, date.second]
	if language == "pl":
		return "%02d.%02d.%04d %s" % [date.day, date.month, date.year, clock]
	return "%02d/%02d/%04d %s" % [date.month, date.day, date.year, clock]
