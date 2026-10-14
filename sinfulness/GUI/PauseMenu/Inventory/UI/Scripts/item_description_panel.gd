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


## When [param fit] is true the description is never cut off and the panel's minimum height is
## the whole text, so a container holding the panel sizes it to the text.
func set_fit_text(fit: bool) -> void:
	_description.clip_text = not fit
	_description.size_flags_vertical = SIZE_FILL if fit else SIZE_EXPAND_FILL


## Sets the gap in pixels between wrapped lines of the name and the description.
func set_line_spacing(spacing: int) -> void:
	_name.add_theme_constant_override("line_spacing", spacing)
	_description.add_theme_constant_override("line_spacing", spacing)


## Hides the icon so a long name gets the full width.
func set_icon_visible(icon_visible: bool) -> void:
	_icon.visible = icon_visible


## Shows a short [param message] instead of an item.
func show_message(message: String) -> void:
	clear()
	_description.text = message


func clear() -> void:
	_icon.texture = null
	_name.text = ""
	_description.text = empty_text
