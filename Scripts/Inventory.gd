extends Node
class_name Inventory

var owned: Array[TrinketDef] = []
var equipped: Array[TrinketDef] = []

@export var max_equipped: int = 5

signal owned_changed
signal equipped_changed

func add_trinket(def: TrinketDef) -> void:
	if def == null:
		return
	owned.append(def)
	owned_changed.emit()

func equip(def: TrinketDef) -> bool:
	if def == null:
		return false
	if def not in owned:
		return false
	if def in equipped:
		return false
	if equipped.size() >= max_equipped:
		return false

	equipped.append(def)
	equipped_changed.emit()
	return true

func remove_by_id(trinket_id: String) -> void:
	# usuń z equipped
	for i in range(equipped.size() - 1, -1, -1):
		if equipped[i] != null and equipped[i].id == trinket_id:
			equipped.remove_at(i)
			equipped_changed.emit()

	# usuń z owned
	for i in range(owned.size() - 1, -1, -1):
		if owned[i] != null and owned[i].id == trinket_id:
			owned.remove_at(i)
			owned_changed.emit()

func clear() -> void:
	owned.clear()
	equipped.clear()
	emit_signal("equipped_changed")
