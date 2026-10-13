class_name BookPage extends Control
## Base class for a page of the pause-menu book. The menu calls build() after the page turn.
##
## If the page has a node with the unique name DescriptionHolder, an ItemDescriptionPanel
## from description_scene is placed inside it and is available as [member description].

@export var description_scene: PackedScene
## Text the description panel shows when nothing is selected.
@export var description_empty_text: String = ""

var description: ItemDescriptionPanel = null


func _ready() -> void:
	var holder: Control = get_node_or_null("%DescriptionHolder") as Control
	if holder != null and description_scene != null:
		description = description_scene.instantiate() as ItemDescriptionPanel
		description.empty_text = description_empty_text
		holder.add_child(description)
		description.set_anchors_and_offsets_preset(PRESET_FULL_RECT)


## Fills the page from GlobalInventory. Override in subclasses.
func build() -> void:
	pass


## Returns the control that gets focus when the page opens, or null when nothing on the page can be focused.
func get_first_focus() -> Control:
	for slot_ui: InventorySlotUI in get_slot_uis():
		if slot_ui.focus_mode != FOCUS_NONE:
			return slot_ui
	return null


## Turns focus and mouse input of the page's slots on or off.
func set_interactive(enabled: bool) -> void:
	for slot_ui: InventorySlotUI in get_slot_uis():
		slot_ui.set_interactive(enabled)


## Handles menu_back inside the page. Returns true when handled, false to go back to the tab list.
func go_back() -> bool:
	return false


func get_slot_uis() -> Array[InventorySlotUI]:
	var slots: Array[InventorySlotUI] = []
	_collect_slots(self, slots)
	return slots


func _collect_slots(node: Node, slots: Array[InventorySlotUI]) -> void:
	for child: Node in node.get_children():
		if child is InventorySlotUI:
			slots.append(child)
		else:
			_collect_slots(child, slots)
