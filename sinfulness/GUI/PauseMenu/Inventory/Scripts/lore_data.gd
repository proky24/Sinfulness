class_name LoreData extends ItemData
## A story item (scroll, note). Its full text is shown when selected. Unique.

@export_multiline var text: String = ""


func _init() -> void:
	category = Category.LORE


func get_max_stack() -> int:
	return 1
