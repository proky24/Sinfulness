class_name ItemDescriptionPanel extends VBoxContainer
## Shows the icon, name and description of the focused item. Lore items show their full text.

## Shown when no item is selected.
@export var empty_text: String = ""

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _description: Label = %Description


func _ready() -> void:
	clear()


func show_item(item: ItemData) -> void:
	if item == null:
		clear()
		return
	_icon.texture = item.texture
	_name.text = item.name
	var lore: LoreData = item as LoreData
	_description.text = lore.text if lore != null and not lore.text.is_empty() else item.description


func clear() -> void:
	_icon.texture = null
	_name.text = ""
	_description.text = empty_text
