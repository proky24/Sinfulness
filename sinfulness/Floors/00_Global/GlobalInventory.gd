extends Node
## The player's shared inventory and equipped armor, kept for the whole game.
##
## The pause-menu tabs only filter this inventory by category. The game always works on
## runtime copies, so the .tres files in the project are never changed while playing.
## Buff timers are child Timers, so they pause together with the tree.

signal inventory_changed
signal equipment_changed
signal potion_used(potion: PotionData)
signal potion_effect_ended(potion: PotionData)
signal selected_potion_changed(potion: PotionData)

@export var starting_inventory: InventoryData
@export var starting_equipment: EquippedData

## True during a boss fight: armor cannot be changed. Cleared by notify_player_died().
var loadout_locked: bool:
	get:
		return _boss_fight_active

var _inventory: InventoryData
var _equipped: EquippedData
var _boss_fight_active: bool = false
var _selected_potion: PotionData = null
var _buff_timers: Dictionary[StringName, Timer] = {}


func _ready() -> void:
	set_inventory(starting_inventory if starting_inventory != null else InventoryData.new())
	set_equipped(starting_equipment if starting_equipment != null else EquippedData.new())


# -- Inventory -----------------------------------------------------------------


## Replaces the inventory with a copy of [param data] (used at start and when loading a save).
func set_inventory(data: InventoryData) -> void:
	if _inventory != null and _inventory.changed_inventory.is_connected(_on_inventory_changed):
		_inventory.changed_inventory.disconnect(_on_inventory_changed)
	_inventory = data.duplicate(true) as InventoryData
	_inventory.changed_inventory.connect(_on_inventory_changed)
	_on_inventory_changed()


## Adds up to [param quantity] of [param item]. Returns how many did NOT fit, so a pickup can stay in the world.
func add_item(item: ItemData, quantity: int = 1) -> int:
	if item is ArmorData and _equipped.has_piece(item):
		return maxi(quantity, 0)
	return _inventory.add_item(item, quantity)


func remove_item(item: ItemData, quantity: int = 1) -> bool:
	return _inventory.remove_item(item, quantity)


func get_count(item: ItemData) -> int:
	return _inventory.get_count(item)


## Returns the slots whose item is in one of [param categories]. An empty list returns every slot.
func get_slots(categories: Array[ItemData.Category] = []) -> Array[SlotData]:
	return _inventory.get_slots(categories)


## Uses [param item] from the menu. Potions are refused during a boss fight. Returns true when it was used.
func use_item(item: ItemData) -> bool:
	if item is PotionData and _boss_fight_active:
		return false
	return _use(item)


# -- Potions -------------------------------------------------------------------


## Quick use (key 1). Allowed during boss fights. Returns true when a potion was drunk.
func use_selected_potion() -> bool:
	if _selected_potion == null:
		return false
	return _use(_selected_potion)


## Selects the next potion type the player owns (key 2). Returns the new selection.
func cycle_potion() -> PotionData:
	var potions: Array[PotionData] = _get_owned_potions()
	if potions.is_empty():
		_select_potion(null)
	else:
		var index: int = potions.find(_selected_potion)
		_select_potion(potions[(index + 1) % potions.size()])
	return _selected_potion


func get_selected_potion() -> PotionData:
	return _selected_potion


func is_buff_active(potion: PotionData) -> bool:
	return _buff_timers.has(potion.get_key())


func get_buff_time_left(potion: PotionData) -> float:
	var timer: Timer = _buff_timers.get(potion.get_key())
	return timer.time_left if timer != null else 0.0


# -- Armor ---------------------------------------------------------------------


## Replaces the equipped armor with a copy of [param data] (used at start and when loading a save).
func set_equipped(data: EquippedData) -> void:
	if _equipped != null and _equipped.changed_equipment.is_connected(_on_equipment_changed):
		_equipped.changed_equipment.disconnect(_on_equipment_changed)
	_equipped = data.duplicate(true) as EquippedData
	_equipped.changed_equipment.connect(_on_equipment_changed)
	_apply_equipment_to_stats()
	equipment_changed.emit()


func get_equipped_armor(slot: ArmorData.Slot) -> ArmorData:
	return _equipped.get_piece(slot)


## Moves [param armor] from the inventory into its slot; the old piece goes back to the inventory.
## Returns false while the loadout is locked or when the piece is not owned.
func equip_armor(armor: ArmorData) -> bool:
	if _boss_fight_active or armor == null or get_count(armor) <= 0:
		return false
	_inventory.remove_item(armor, 1)
	var previous: ArmorData = _equipped.set_piece(armor.slot, armor)
	if previous != null:
		_inventory.add_item(previous, 1)
	return true


## Moves the piece in [param slot] back to the inventory. Returns false while locked or when the slot is empty.
func unequip_armor(slot: ArmorData.Slot) -> bool:
	if _boss_fight_active or _equipped.get_piece(slot) == null:
		return false
	var previous: ArmorData = _equipped.set_piece(slot, null)
	_inventory.add_item(previous, 1)
	return true


# -- Boss fight locks ----------------------------------------------------------


func set_boss_fight_active(active: bool) -> void:
	_boss_fight_active = active


## Called when the player dies; ends the boss-fight lock so the loadout can change again.
func notify_player_died() -> void:
	_boss_fight_active = false

# -- Private -------------------------------------------------------------------


func _use(item: ItemData) -> bool:
	if item == null or get_count(item) <= 0:
		return false
	var potion: PotionData = item as PotionData
	if potion != null and not potion.is_instant() and is_buff_active(potion):
		return false
	if not item.use(GlobalPlayerManager.player):
		return false
	_inventory.remove_item(item, 1)
	if potion != null:
		if not potion.is_instant():
			_start_buff(potion)
		#print("[GlobalInventory] potion used: %s" % potion.name)
		potion_used.emit(potion)
		pass
	return true


func _start_buff(potion: PotionData) -> void:
	var key: StringName = potion.get_key()
	var timer: Timer = _buff_timers.get(key)
	if timer == null:
		timer = Timer.new()
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(_on_buff_timeout.bind(key, potion))
		_buff_timers[key] = timer
	timer.start(potion.duration_seconds)


func _on_buff_timeout(key: StringName, potion: PotionData) -> void:
	var timer: Timer = _buff_timers.get(key)
	_buff_timers.erase(key)
	if timer != null:
		timer.queue_free()
	if GlobalPlayerManager.player_stats != null:
		GlobalPlayerManager.player_stats.remove_buffs(key)
	print("[GlobalInventory] potion effect ended: %s" % potion.name)
	potion_effect_ended.emit(potion)


func _on_inventory_changed() -> void:
	if _selected_potion == null or get_count(_selected_potion) <= 0:
		var potions: Array[PotionData] = _get_owned_potions()
		_select_potion(potions[0] if not potions.is_empty() else null)
	inventory_changed.emit()


func _on_equipment_changed() -> void:
	_apply_equipment_to_stats()
	equipment_changed.emit()


## Sends the worn pieces to the player's stats (rebuilds the "equipment" ADD buffs).
func _apply_equipment_to_stats() -> void:
	if GlobalPlayerManager.player_stats == null:
		return
	var pieces: Array[ArmorData] = []
	for armor_slot: ArmorData.Slot in ArmorData.Slot.values():
		var piece: ArmorData = _equipped.get_piece(armor_slot)
		if piece != null:
			pieces.append(piece)
	GlobalPlayerManager.player_stats.apply_equipment(pieces)


func _select_potion(potion: PotionData) -> void:
	if potion == _selected_potion:
		return
	_selected_potion = potion
	selected_potion_changed.emit(potion)


func _get_owned_potions() -> Array[PotionData]:
	var potions: Array[PotionData] = []
	for slot: SlotData in get_slots([ItemData.Category.POTION]):
		potions.append(slot.item_data as PotionData)
	return potions
