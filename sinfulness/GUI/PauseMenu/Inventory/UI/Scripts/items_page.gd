class_name ItemsPage extends BookPage
## A page made of ItemGrids and one description panel (Inventory and Potions tabs).
## The focused slot updates the description panel. Confirming a potion drinks it.


func build() -> void:
	for grid: ItemGrid in _get_grids():
		if not grid.slot_focused.is_connected(_on_slot_focused):
			grid.slot_focused.connect(_on_slot_focused)
		if not grid.slot_chosen.is_connected(_on_slot_chosen):
			grid.slot_chosen.connect(_on_slot_chosen)
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


func _on_slot_chosen(slot_ui: InventorySlotUI) -> void:
	var potion: PotionData = slot_ui.get_item() as PotionData
	var grid: ItemGrid = slot_ui.get_parent() as ItemGrid
	if potion == null or grid == null: #or not GlobalInventory.use_item(potion)
		return
	# Deferred: the slot's pressed signal is still running and fill() frees the slot.
	_refill_after_use.call_deferred(grid, slot_ui.get_index())


## Rebuilds [param grid] after a drink and focuses the slot at [param index], or the last one
## when the stack ran out, or any slot on the page when the grid is empty.
func _refill_after_use(grid: ItemGrid, index: int) -> void:
	var slots: Array[InventorySlotUI] = grid.fill()
	for slot: InventorySlotUI in slots:
		slot.set_interactive(true)
	var target: Control = slots[mini(index, slots.size() - 1)] if not slots.is_empty() else get_first_focus()
	if target != null:
		target.grab_focus()
	elif description != null:
		description.clear()
