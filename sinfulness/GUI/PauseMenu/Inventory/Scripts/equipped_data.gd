class_name EquippedData extends Resource
## The armor pieces the player wears, one per armor slot.

signal changed_equipment

@export var pieces: Dictionary[ArmorData.Slot, ArmorData] = {}


## Returns the piece worn in [param slot], or null.
func get_piece(slot: ArmorData.Slot) -> ArmorData:
	return pieces.get(slot)


## Puts [param armor] into [param slot] (null empties it). Returns the piece that was there before.
func set_piece(slot: ArmorData.Slot, armor: ArmorData) -> ArmorData:
	var previous: ArmorData = get_piece(slot)
	if armor == null:
		pieces.erase(slot)
	else:
		pieces[slot] = armor
	if previous != armor:
		changed_equipment.emit()
	return previous


## Returns true when [param armor] is currently worn.
func has_piece(armor: ArmorData) -> bool:
	if armor == null:
		return false
	return armor.is_same_item(get_piece(armor.slot))
