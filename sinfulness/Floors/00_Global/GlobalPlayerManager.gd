extends Node

var player: Player

const INVENTORY_DATA: InventoryData = preload("res://GUI/PauseMenu/Inventory/starting_inventory.tres")

func _ready() -> void:
	print("GlobalPlayerManager: Inventory data loaded: ", INVENTORY_DATA)
