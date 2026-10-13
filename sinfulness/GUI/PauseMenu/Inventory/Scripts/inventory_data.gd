class_name InventoryData extends Resource
## A list of item stacks. Each item type has one slot, capped at the item's max stack.

signal changed_inventory

@export var slots: Array[ SlotData ]


## Adds up to [param quantity] of [param item]. Returns how many did NOT fit.
func add_item(item: ItemData, quantity: int = 1) -> int:
	if item == null or quantity <= 0:
		return maxi(quantity, 0)
	var slot: SlotData = _find_slot(item)
	var current: int = slot.quantity if slot != null else 0
	var added: int = mini(item.get_max_stack() - current, quantity)
	if added <= 0:
		return quantity
	if slot == null:
		slot = SlotData.new()
		slot.item_data = item
		slots.append(slot)
	slot.quantity += added
	changed_inventory.emit()
	return quantity - added


## Removes [param quantity] of [param item]. Returns false (and removes nothing) if there are not enough.
func remove_item(item: ItemData, quantity: int = 1) -> bool:
	var slot: SlotData = _find_slot(item)
	if slot == null or quantity <= 0 or slot.quantity < quantity:
		return false
	slot.quantity -= quantity
	if slot.quantity == 0:
		slots.erase(slot)
	changed_inventory.emit()
	return true


func get_count(item: ItemData) -> int:
	var slot: SlotData = _find_slot(item)
	return slot.quantity if slot != null else 0


## Returns the slots whose item is in one of [param categories]. An empty list returns every slot.
func get_slots(categories: Array[ItemData.Category] = []) -> Array[SlotData]:
	var result: Array[SlotData] = []
	for slot: SlotData in slots:
		if not _is_valid(slot):
			continue
		if categories.is_empty() or slot.item_data.category in categories:
			result.append(slot)
	return result


func _find_slot(item: ItemData) -> SlotData:
	if item == null:
		return null
	for slot: SlotData in slots:
		if _is_valid(slot) and slot.item_data.is_same_item(item):
			return slot
	return null


func _is_valid(slot: SlotData) -> bool:
	return slot != null and slot.item_data != null and slot.quantity > 0
