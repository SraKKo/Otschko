extends RefCounted

const ENTRIES := [
	{"id": "first_round", "name": "LOC_ACH_FIRST_ROUND", "description": "LOC_ACH_FIRST_ROUND_DESC", "stat": "rounds", "target": 1},
	{"id": "first_win", "name": "LOC_ACH_FIRST_WIN", "description": "LOC_ACH_FIRST_WIN_DESC", "stat": "wins", "target": 1},
	{"id": "ten_rounds", "name": "LOC_ACH_TEN_ROUNDS", "description": "LOC_ACH_TEN_ROUNDS_DESC", "stat": "rounds", "target": 10},
	{"id": "five_wins", "name": "LOC_ACH_FIVE_WINS", "description": "LOC_ACH_FIVE_WINS_DESC", "stat": "wins", "target": 5},
	{"id": "stage_three", "name": "LOC_ACH_STAGE_THREE", "description": "LOC_ACH_STAGE_THREE_DESC", "stat": "best_stage", "target": 3},
	{"id": "split", "name": "LOC_ACH_SPLIT", "description": "LOC_ACH_SPLIT_DESC"},
	{"id": "three_trinkets", "name": "LOC_ACH_TRINKETS", "description": "LOC_ACH_TRINKETS_DESC"},
	{"id": "natural_blackjack", "name": "LOC_ACH_BLACKJACK", "description": "LOC_ACH_BLACKJACK_DESC", "hidden": true},
	{"id": "victory", "name": "LOC_ACH_VICTORY", "description": "LOC_ACH_VICTORY_DESC", "hidden": true},
	{"id": "completion", "name": "LOC_ACH_COMPLETION", "description": "LOC_ACH_COMPLETION_DESC"},
]

static func event_ids(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var stored: Variant = data.get("achievements")
	if not stored is Array: return result
	for entry: Dictionary in ENTRIES:
		if is_event(entry) and entry.id in stored: result.append(entry.id)
	return result

static func is_event(entry: Dictionary) -> bool:
	return entry.id != "completion" and not entry.has("stat")

static func earned(data: Dictionary) -> Array[String]:
	var result := event_ids(data)
	for entry: Dictionary in ENTRIES:
		if entry.has("stat") and value(entry, data) >= entry.target:
			result.append(entry.id)
	if result.size() == ENTRIES.size() - 1: result.append("completion")
	return result

static func value(entry: Dictionary, data: Dictionary) -> int:
	return clampi(int(data.get(entry.stat, 0)), 0, entry.target)
