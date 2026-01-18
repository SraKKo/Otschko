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
	preload("res://Trinkets/blood_money.tres"),
	preload("res://Trinkets/calculated_risk.tres"),
	preload("res://Trinkets/frozen_clock.tres"),
	preload("res://Trinkets/glass_chip.tres"),
	preload("res://Trinkets/interest_chip.tres"),
	preload("res://Trinkets/mirror_hands.tres"),
	preload("res://Trinkets/tax_evasion.tres"),
]

func get_by_id(id: String) -> TrinketDef:
	for t in trinkets:
		if t != null and t.id == id:
			return t
	return null
