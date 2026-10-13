class_name ItemGrid extends GridContainer
## A grid of InventorySlotUI filled from GlobalInventory, filtered by item category.

signal slot_focused(slot_ui: InventorySlotUI)
signal slot_chosen(slot_ui: InventorySlotUI)

@export var slot_scene: PackedScene
## Categories shown in this grid (same order as ItemData.Category).
@export_flags("Potion", "Material", "Armor", "Lore", "Key") var category_flags: int = 0
## Shown in the grid when it has no items. Leave empty to show nothing.
@export var empty_text: String = "Empty"

## Optional extra filter set from code: func(item: ItemData) -> bool.
var filter: Callable = Callable()


## Rebuilds the grid from GlobalInventory. Returns the created slots.
func fill() -> Array[InventorySlotUI]:
	clear()
	var slots: Array[InventorySlotUI] = []
	for data: SlotData in GlobalInventory.get_slots(get_categories()):
		if filter.is_valid() and not filter.call(data.item_data):
			continue
		var slot_ui: InventorySlotUI = slot_scene.instantiate() as InventorySlotUI
		add_child(slot_ui)
		slot_ui.set_slot(data)
		slot_ui.slot_focused.connect(_on_slot_focused)
		slot_ui.slot_chosen.connect(_on_slot_chosen)
		slots.append(slot_ui)
	if slots.is_empty() and not empty_text.is_empty():
		var label: Label = Label.new()
		label.text = empty_text
		add_child(label)
	return slots


func clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()


func get_slot_uis() -> Array[InventorySlotUI]:
	var slots: Array[InventorySlotUI] = []
	for child: Node in get_children():
		if child is InventorySlotUI:
			slots.append(child)
	return slots


func get_categories() -> Array[ItemData.Category]:
	var categories: Array[ItemData.Category] = []
	for category: int in ItemData.Category.values():
		if category_flags & (1 << category):
			categories.append(category)
	return categories


func _on_slot_focused(slot_ui: InventorySlotUI) -> void:
	slot_focused.emit(slot_ui)


func _on_slot_chosen(slot_ui: InventorySlotUI) -> void:
	slot_chosen.emit(slot_ui)
