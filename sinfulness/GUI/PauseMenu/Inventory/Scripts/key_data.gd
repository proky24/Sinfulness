class_name KeyData extends ItemData
## A key that opens something in the world. Unique.

## Matched against doors or chests that need this key.
@export var key_id: StringName = &""


func _init() -> void:
	category = Category.KEY


func get_max_stack() -> int:
	return 1
