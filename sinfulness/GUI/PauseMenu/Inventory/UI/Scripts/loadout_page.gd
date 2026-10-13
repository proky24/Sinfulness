class_name LoadoutPage extends BookPage
## Loadout tab: the four armor slots with the equipped piece on the left page, and the owned
## pieces for the selected slot on the right page.
##
## Focusing a slot previews its owned pieces; confirming moves focus into that list and
## menu_back returns to the slot list. Equipping is not built yet (no armor sets in the game).

const SLOT_NAMES: Dictionary[ArmorData.Slot, String] = {
	ArmorData.Slot.HELMET: "Helmet",
	ArmorData.Slot.CHESTPLATE: "Chestplate",
	ArmorData.Slot.GAUNTLETS: "Gauntlets",
	ArmorData.Slot.BOOTS: "Boots",
}

@export var slot_scene: PackedScene
@export var helmet_placeholder: Texture2D
@export var chestplate_placeholder: Texture2D
@export var gauntlets_placeholder: Texture2D
@export var boots_placeholder: Texture2D

@onready var _slot_list: VBoxContainer = %SlotList
@onready var _owned_title: Label = %OwnedTitle
@onready var _owned_grid: ItemGrid = %OwnedGrid

var _equipped_slots: Dictionary[ArmorData.Slot, InventorySlotUI] = {}
var _selected_slot: ArmorData.Slot = ArmorData.Slot.HELMET
var _browsing_owned: bool = false


func _ready() -> void:
	super()
	_owned_grid.slot_focused.connect(_on_owned_focused)


func build() -> void:
	for child: Node in _slot_list.get_children():
		_slot_list.remove_child(child)
		child.queue_free()
	_equipped_slots.clear()
	for armor_slot: ArmorData.Slot in SLOT_NAMES:
		_add_slot_row(armor_slot)
	_browsing_owned = false
	_show_owned(ArmorData.Slot.HELMET)
	description.clear()


func set_interactive(enabled: bool) -> void:
	_browsing_owned = false
	_set_slots_interactive(_equipped_slots.values(), enabled)
	_set_slots_interactive(_owned_grid.get_slot_uis(), false)


func go_back() -> bool:
	if not _browsing_owned:
		return false
	_browsing_owned = false
	var slot_ui: InventorySlotUI = _equipped_slots[_selected_slot]
	_set_slots_interactive(_equipped_slots.values(), true)
	slot_ui.grab_focus()
	_set_slots_interactive(_owned_grid.get_slot_uis(), false)
	return true


func _add_slot_row(armor_slot: ArmorData.Slot) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	_slot_list.add_child(row)

	var slot_ui: InventorySlotUI = slot_scene.instantiate() as InventorySlotUI
	row.add_child(slot_ui)
	var equipped: ArmorData = GlobalInventory.get_equipped_armor(armor_slot)
	var data: SlotData = null
	if equipped != null:
		data = SlotData.new()
		data.item_data = equipped
		data.quantity = 1
	slot_ui.set_slot(data, _get_placeholder(armor_slot))
	slot_ui.slot_focused.connect(_on_equipped_focused.bind(armor_slot))
	slot_ui.slot_chosen.connect(_on_equipped_chosen.bind(armor_slot))
	_equipped_slots[armor_slot] = slot_ui

	var label: Label = Label.new()
	label.text = SLOT_NAMES[armor_slot]
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(label)


func _show_owned(armor_slot: ArmorData.Slot) -> void:
	_selected_slot = armor_slot
	_owned_title.text = SLOT_NAMES[armor_slot]
	_owned_grid.filter = func(item: ItemData) -> bool: return (item as ArmorData).slot == armor_slot
	_set_slots_interactive(_owned_grid.fill(), _browsing_owned)


func _set_slots_interactive(slots: Array, enabled: bool) -> void:
	for slot_ui: InventorySlotUI in slots:
		slot_ui.set_interactive(enabled)


func _get_placeholder(armor_slot: ArmorData.Slot) -> Texture2D:
	match armor_slot:
		ArmorData.Slot.HELMET:
			return helmet_placeholder
		ArmorData.Slot.CHESTPLATE:
			return chestplate_placeholder
		ArmorData.Slot.GAUNTLETS:
			return gauntlets_placeholder
		_:
			return boots_placeholder


func _on_equipped_focused(slot_ui: InventorySlotUI, armor_slot: ArmorData.Slot) -> void:
	if armor_slot != _selected_slot:
		_show_owned(armor_slot)
	description.show_item(slot_ui.get_item())


func _on_equipped_chosen(_slot_ui: InventorySlotUI, armor_slot: ArmorData.Slot) -> void:
	var owned: Array[InventorySlotUI] = _owned_grid.get_slot_uis()
	if owned.is_empty():
		return
	_selected_slot = armor_slot
	_browsing_owned = true
	_set_slots_interactive(owned, true)
	owned[0].grab_focus()
	_set_slots_interactive(_equipped_slots.values(), false)


func _on_owned_focused(slot_ui: InventorySlotUI) -> void:
	description.show_item(slot_ui.get_item())
