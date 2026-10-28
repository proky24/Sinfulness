class_name DisplayedPotion extends TextureRect

signal potion_cycled

@onready var label_count: Label = $Label

var displayed_potion: PotionData = null

func _ready() -> void:
	GlobalInventory.selected_potion_changed.connect(_update_displayed_potion)
	GlobalInventory.inventory_changed.connect(_on_inventory_changed)
	_update_displayed_potion(GlobalInventory.get_selected_potion())

func _update_displayed_potion(potion: PotionData) -> void:
	if potion != null:
		potion_cycled.emit()
		texture = potion.texture
		label_count.text = str(GlobalInventory.get_count(potion))
		displayed_potion = potion
	else:
		self.get_parent().visible = false
		texture = null

func _on_inventory_changed() -> void:
	_update_displayed_potion(GlobalInventory.get_selected_potion())
