extends Node
class_name TrinketDB

var trinkets: Array[TrinketDef] = [
	preload("res://Trinkets/slow_timer.tres"),
	preload("res://Trinkets/lucky_draw.tres"),
	preload("res://Trinkets/nervous_dealer.tres"),
	preload("res://Trinkets/lazy_dealer.tres"),
	preload("res://Trinkets/double_or_nothing.tres"),
	preload("res://Trinkets/golden_chip.tres"),
	preload("res://Trinkets/overheat.tres"),
]

func get_by_id(id: String) -> TrinketDef:
	for t in trinkets:
		if t != null and t.id == id:
			return t
	return null
