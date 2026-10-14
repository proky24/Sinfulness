class_name LoadoutPage extends BookPage
## Loadout tab, in two stages.
##
## Stage 1: the four armor slots with the equipped piece on the left page; the right page previews
## the owned pieces for the focused slot and describes the equipped one. Confirming a slot opens stage 2.
## Stage 2: the left page lists every owned piece for that slot (the equipped one is marked and named below the list) and the
## right page describes the highlighted piece and compares the loadout stats. Confirming equips the
## piece, or unequips it when it is already equipped. menu_back returns to stage 1.

const SLOT_NAMES: Dictionary[ArmorData.Slot, String] = {
	ArmorData.Slot.HELMET: "Helmet",
	ArmorData.Slot.CHESTPLATE: "Chestplate",
	ArmorData.Slot.GAUNTLETS: "Gauntlets",
	ArmorData.Slot.BOOTS: "Boots",
}
## ArmorData stats compared in stage 2, in display order.
const STAT_NAMES: Dictionary[StringName, String] = {
	&"health": "Health",
	&"damage": "Damage",
	&"durability": "Durability",
	&"corruption_durability": "Corr. res.",
	&"disgrace": "Disgrace",
	&"corruption_gain": "Corr. gain",
	&"stance": "Stance",
	&"dash_distance_modifier": "Dash",
	&"attack_speed_modifier": "Atk speed",
}
## Stats stored as fractions (0.05) and shown as percent (5%).
const PERCENT_STATS: Array[StringName] = [&"corruption_gain", &"dash_distance_modifier", &"attack_speed_modifier"]

@export var slot_scene: PackedScene
@export var helmet_placeholder: Texture2D
@export var chestplate_placeholder: Texture2D
@export var gauntlets_placeholder: Texture2D
@export var boots_placeholder: Texture2D
## Shown on the right page when a slot is confirmed but the player owns no piece for it.
@export var no_pieces_text: String = "Nothing for this slot."
## Shown under the owned pieces in stage 2; %s is the name of the equipped piece.
@export var equipped_text: String = "Equipped: %s"
## Shown under the owned pieces in stage 2 when the slot is empty.
@export var nothing_equipped_text: String = "Nothing equipped."
## Gap between wrapped lines of the description, smaller than the theme's so the stats fit.
@export var description_line_spacing: int = 1

@onready var _title: Label = %Title
@onready var _slot_list: VBoxContainer = %SlotList
@onready var _piece_grid: GridContainer = %PieceGrid
@onready var _equipped_label: Label = %EquippedLabel
@onready var _owned_title: Label = %OwnedTitle
@onready var _owned_grid: ItemGrid = %OwnedGrid
@onready var _stat_list: VBoxContainer = %StatList

var _equipped_slots: Dictionary[ArmorData.Slot, InventorySlotUI] = {}
var _selected_slot: ArmorData.Slot = ArmorData.Slot.HELMET
var _choosing_piece: bool = false
var _slots_title: String = ""


func _ready() -> void:
	super()
	_slots_title = _title.text
	# DescriptionHolder is a VBoxContainer: the panel takes the height of its text and the
	# stats follow right below it instead of being pushed to the bottom of the page.
	description.set_fit_text(true)
	description.set_line_spacing(description_line_spacing)


func build() -> void:
	_clear_children(_slot_list)
	_equipped_slots.clear()
	for armor_slot: ArmorData.Slot in SLOT_NAMES:
		_add_slot_row(armor_slot)
	_set_stage(false)
	_show_owned(ArmorData.Slot.HELMET)
	description.clear()


func set_interactive(enabled: bool) -> void:
	_set_slots_interactive(_equipped_slots.values(), enabled and not _choosing_piece)
	_set_slots_interactive(_piece_grid.get_children(), enabled and _choosing_piece)


func go_back() -> bool:
	if not _choosing_piece:
		return false
	_close_pieces()
	return true


# -- Stage 1: slots ------------------------------------------------------------


func _add_slot_row(armor_slot: ArmorData.Slot) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	_slot_list.add_child(row)

	var slot_ui: InventorySlotUI = slot_scene.instantiate() as InventorySlotUI
	row.add_child(slot_ui)
	slot_ui.slot_focused.connect(_on_equipped_focused.bind(armor_slot))
	slot_ui.slot_chosen.connect(_on_equipped_chosen.bind(armor_slot))
	_equipped_slots[armor_slot] = slot_ui
	_refresh_slot_row(armor_slot)

	var label: Label = Label.new()
	label.text = SLOT_NAMES[armor_slot]
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(label)


func _refresh_slot_row(armor_slot: ArmorData.Slot) -> void:
	var equipped: ArmorData = GlobalInventory.get_equipped_armor(armor_slot)
	_equipped_slots[armor_slot].set_slot(_make_slot_data(equipped), _get_placeholder(armor_slot))


func _show_owned(armor_slot: ArmorData.Slot) -> void:
	_selected_slot = armor_slot
	_owned_title.text = SLOT_NAMES[armor_slot]
	_owned_grid.filter = func(item: ItemData) -> bool: return (item as ArmorData).slot == armor_slot
	_set_slots_interactive(_owned_grid.fill(), false)


func _on_equipped_focused(slot_ui: InventorySlotUI, armor_slot: ArmorData.Slot) -> void:
	if armor_slot != _selected_slot:
		_show_owned(armor_slot)
	description.show_item(slot_ui.get_item())


func _on_equipped_chosen(_slot_ui: InventorySlotUI, armor_slot: ArmorData.Slot) -> void:
	_open_pieces(armor_slot)


# -- Stage 2: owned pieces -----------------------------------------------------


func _open_pieces(armor_slot: ArmorData.Slot) -> void:
	var pieces: Array[ArmorData] = _get_owned_pieces(armor_slot)
	if pieces.is_empty():
		description.show_message(no_pieces_text)
		return
	_selected_slot = armor_slot
	_clear_children(_piece_grid)
	for piece: ArmorData in pieces:
		var slot_ui: InventorySlotUI = slot_scene.instantiate() as InventorySlotUI
		_piece_grid.add_child(slot_ui)
		slot_ui.set_slot(_make_slot_data(piece))
		slot_ui.slot_focused.connect(_on_piece_focused)
		slot_ui.slot_chosen.connect(_on_piece_chosen)
	_refresh_equipped_marks()
	_set_stage(true)
	# The equipped piece is listed first, so the cursor starts on it (or on the first piece).
	(_piece_grid.get_child(0) as InventorySlotUI).grab_focus()


func _close_pieces() -> void:
	_refresh_slot_row(_selected_slot)
	_show_owned(_selected_slot)
	_set_stage(false)
	_equipped_slots[_selected_slot].grab_focus()
	_clear_children(_piece_grid)


## Owned pieces for [param armor_slot]: the equipped one first, then the ones in the inventory.
func _get_owned_pieces(armor_slot: ArmorData.Slot) -> Array[ArmorData]:
	var pieces: Array[ArmorData] = []
	var equipped: ArmorData = GlobalInventory.get_equipped_armor(armor_slot)
	if equipped != null:
		pieces.append(equipped)
	# Typed on purpose: an untyped literal is rejected by get_slots() when called through the autoload.
	var categories: Array[ItemData.Category] = [ItemData.Category.ARMOR]
	for data: SlotData in GlobalInventory.get_slots(categories):
		var armor: ArmorData = data.item_data as ArmorData
		if armor.slot == armor_slot:
			pieces.append(armor)
	return pieces


func _refresh_equipped_marks() -> void:
	var equipped: ArmorData = GlobalInventory.get_equipped_armor(_selected_slot)
	for slot_ui: InventorySlotUI in _piece_grid.get_children():
		slot_ui.set_equipped(slot_ui.get_item().is_same_item(equipped))
	_equipped_label.text = equipped_text % equipped.name if equipped != null else nothing_equipped_text


func _on_piece_focused(slot_ui: InventorySlotUI) -> void:
	_show_piece(slot_ui.get_item() as ArmorData)


func _on_piece_chosen(slot_ui: InventorySlotUI) -> void:
	var piece: ArmorData = slot_ui.get_item() as ArmorData
	if piece.is_same_item(GlobalInventory.get_equipped_armor(piece.slot)):
		GlobalInventory.unequip_armor(piece.slot)
	else:
		GlobalInventory.equip_armor(piece)
	_refresh_equipped_marks()
	_show_piece(piece)


## Describes [param piece] and lists every stat it or the equipped piece changes, as the loadout
## total now and after equipping [param piece].
func _show_piece(piece: ArmorData) -> void:
	description.show_item(piece)
	_clear_children(_stat_list)
	var equipped: ArmorData = GlobalInventory.get_equipped_armor(piece.slot)
	for stat: StringName in STAT_NAMES:
		var piece_value: float = piece.get(stat)
		var equipped_value: float = equipped.get(stat) if equipped != null else 0.0
		if is_zero_approx(piece_value) and is_zero_approx(equipped_value):
			continue
		var current: float = _get_loadout_total(stat)
		_add_stat_row(stat, current, current - equipped_value + piece_value)


func _add_stat_row(stat: StringName, current: float, after: float) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	_stat_list.add_child(row)

	var name_label: Label = Label.new()
	name_label.text = STAT_NAMES[stat]
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)

	var value_label: Label = Label.new()
	value_label.text = "%s > %s" % [_format_stat(stat, current), _format_stat(stat, after)]
	row.add_child(value_label)


func _get_loadout_total(stat: StringName) -> float:
	var total: float = 0.0
	for armor_slot: ArmorData.Slot in SLOT_NAMES:
		var equipped: ArmorData = GlobalInventory.get_equipped_armor(armor_slot)
		if equipped != null:
			total += equipped.get(stat)
	return total


func _format_stat(stat: StringName, value: float) -> String:
	if stat in PERCENT_STATS:
		return "%d%%" % roundi(value * 100.0)
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return "%.1f" % value


# -- Helpers -------------------------------------------------------------------


## Switches between stage 1 (slots) and stage 2 (owned pieces of the selected slot).
func _set_stage(choosing_piece: bool) -> void:
	_choosing_piece = choosing_piece
	_title.text = SLOT_NAMES[_selected_slot] if choosing_piece else _slots_title
	_slot_list.visible = not choosing_piece
	_piece_grid.visible = choosing_piece
	_equipped_label.visible = choosing_piece
	_owned_title.visible = not choosing_piece
	_owned_grid.visible = not choosing_piece
	_stat_list.visible = choosing_piece
	# The highlighted slot on the left already shows the icon; without it long names fit on one line.
	description.set_icon_visible(not choosing_piece)
	_set_slots_interactive(_equipped_slots.values(), not choosing_piece)
	_set_slots_interactive(_piece_grid.get_children(), choosing_piece)


func _make_slot_data(armor: ArmorData) -> SlotData:
	if armor == null:
		return null
	var data: SlotData = SlotData.new()
	data.item_data = armor
	data.quantity = 1
	return data


func _set_slots_interactive(slots: Array, enabled: bool) -> void:
	for slot_ui: InventorySlotUI in slots:
		slot_ui.set_interactive(enabled)


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


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
