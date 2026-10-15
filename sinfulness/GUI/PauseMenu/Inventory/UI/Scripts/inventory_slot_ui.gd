class_name InventorySlotUI extends Button
## One slot in the pause-menu book: the item icon and its quantity.
##
## Hovering with the mouse focuses the slot, so mouse and keyboard share one focus path.

signal slot_focused(slot_ui: InventorySlotUI)
signal slot_chosen(slot_ui: InventorySlotUI)

@onready var _icon: TextureRect = $Icon
@onready var _quantity: Label = $Quantity
@onready var _equipped_mark: TextureRect = $EquippedMark
@onready var _audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

var slot_data: SlotData = null


func _ready() -> void:
	focus_entered.connect(_on_focus_entered)
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)


## Shows [param data]. When [param data] is null the slot is empty and shows [param placeholder] faded.
func set_slot(data: SlotData, placeholder: Texture2D = null) -> void:
	slot_data = data
	var item: ItemData = get_item()
	_icon.texture = item.texture if item != null else placeholder
	_icon.modulate.a = 1.0 if item != null else 0.4
	_quantity.text = str(data.quantity) if data != null and data.quantity > 1 else ""


func get_item() -> ItemData:
	return slot_data.item_data if slot_data != null else null


## Shows or hides the small mark in the corner that tells the piece is equipped.
func set_equipped(equipped: bool) -> void:
	_equipped_mark.visible = equipped


func set_interactive(enabled: bool) -> void:
	focus_mode = FOCUS_ALL if enabled else FOCUS_NONE
	mouse_filter = MOUSE_FILTER_STOP if enabled else MOUSE_FILTER_IGNORE


func _on_mouse_entered() -> void:
	if focus_mode != FOCUS_NONE:
		grab_focus()


func _on_focus_entered() -> void:
	slot_focused.emit(self)


func _on_pressed() -> void:
	slot_chosen.emit(self)
	_audio_player.play()
