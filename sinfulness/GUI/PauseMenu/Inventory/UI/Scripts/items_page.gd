class_name ItemsPage extends BookPage
## A page made of ItemGrids and one description panel (Inventory and Potions tabs).
## The focused slot updates the description panel.


func build() -> void:
	for grid: ItemGrid in _get_grids():
		if not grid.slot_focused.is_connected(_on_slot_focused):
			grid.slot_focused.connect(_on_slot_focused)
		grid.fill()
	if description != null:
		description.clear()


func _get_grids() -> Array[ItemGrid]:
	var grids: Array[ItemGrid] = []
	_collect_grids(self, grids)
	return grids


func _collect_grids(node: Node, grids: Array[ItemGrid]) -> void:
	for child: Node in node.get_children():
		if child is ItemGrid:
			grids.append(child)
		else:
			_collect_grids(child, grids)


func _on_slot_focused(slot_ui: InventorySlotUI) -> void:
	if description != null:
		description.show_item(slot_ui.get_item())
