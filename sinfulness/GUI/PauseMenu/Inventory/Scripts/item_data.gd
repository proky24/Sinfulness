class_name ItemData extends Resource
## Base class for every inventory item. Use one of the subclasses, not ItemData itself.

enum Category { POTION, MATERIAL, ARMOR, LORE, KEY }

## Stable identifier, used to match items and in save files. Must be unique per item.
@export var id: StringName = &""
@export var name: String = ""
@export_multiline var description: String = ""
@export var texture: Texture2D
## How many of this item fit in its single inventory slot.
@export var max_stack: int = 1

## Set by each subclass in _init().
var category: Category = Category.LORE


## Returns how many of this item the inventory can hold.
func get_max_stack() -> int:
	return maxi(max_stack, 1)


## Returns true when [param other] is the same item (same resource or same id).
func is_same_item(other: ItemData) -> bool:
	if other == null:
		return false
	if other == self:
		return true
	return id != &"" and id == other.id


## Stable key of this item (the id, or the resource path when the id is empty).
## Used for potion buff timers and as the buff source in Stats.
func get_key() -> StringName:
	if id != &"":
		return id
	return StringName(resource_path)


## Uses the item on [param user] (the player, can be null). Returns true when one item was consumed.
func use(_user: Node) -> bool:
	return false
