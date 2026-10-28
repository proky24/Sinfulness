extends TestCase
## Phase 1: data classes, stacking rules and the GlobalInventory API.

const ITEMS_DIR: String = "res://GUI/PauseMenu/Inventory/Items/"
const STARTING_INVENTORY_PATH: String = "res://GUI/PauseMenu/Inventory/starting_inventory.tres"

var berserk: PotionData = load(ITEMS_DIR + "potion.tres")
var maturation: PotionData = load(ITEMS_DIR + "maturation_potion.tres")
var aspen: MaterialData = load(ITEMS_DIR + "mushroom.tres")
var chanterelle: MaterialData = load(ITEMS_DIR + "chanterelle.tres")
var scroll: LoreData = load(ITEMS_DIR + "torn_scroll.tres")
var key: KeyData = load(ITEMS_DIR + "rusty_key.tres")
var helmet: ArmorData = load(ITEMS_DIR + "sainted_helmet.tres")
var chestplate: ArmorData = load(ITEMS_DIR + "decayed_chestplate.tres")
var gauntlets: ArmorData = load(ITEMS_DIR + "sainted_gauntlets.tres")
var boots: ArmorData = load(ITEMS_DIR + "decayed_boots.tres")


func test_items_load_as_subclasses() -> void:
	assert_not_null(berserk, "potion.tres converted to PotionData")
	assert_not_null(aspen, "mushroom.tres converted to MaterialData")
	for item: ItemData in [maturation, chanterelle, scroll, key, helmet, chestplate, gauntlets, boots]:
		assert_not_null(item)
	assert_eq(berserk.category, ItemData.Category.POTION)
	assert_eq(aspen.category, ItemData.Category.MATERIAL)
	assert_eq(scroll.category, ItemData.Category.LORE)
	assert_eq(key.category, ItemData.Category.KEY)
	assert_eq(helmet.category, ItemData.Category.ARMOR)
	assert_eq(berserk.get_max_stack(), 5, "potion stack")
	assert_eq(aspen.get_max_stack(), 99, "material stack")
	assert_eq(scroll.get_max_stack(), 1, "lore is unique")
	assert_true(maturation.is_instant(), "Maturation has duration 0")
	assert_false(berserk.is_instant())
	assert_eq([helmet.slot, chestplate.slot, gauntlets.slot, boots.slot],
		[ArmorData.Slot.HELMET, ArmorData.Slot.CHESTPLATE, ArmorData.Slot.GAUNTLETS, ArmorData.Slot.BOOTS])
	assert_eq([helmet.armor_set, chestplate.armor_set], [ArmorData.ArmorSet.SAINTED, ArmorData.ArmorSet.DECAYED])


func test_stacking_merges_into_one_slot() -> void:
	var inventory := InventoryData.new()
	assert_eq(inventory.add_item(berserk, 2), 0)
	assert_eq(inventory.add_item(berserk, 2), 0)
	assert_eq(inventory.slots.size(), 1, "one slot per item type")
	assert_eq(inventory.get_count(berserk), 4)


func test_adding_past_cap_returns_leftover() -> void:
	var inventory := InventoryData.new()
	inventory.add_item(berserk, 4)
	assert_eq(inventory.add_item(berserk, 3), 2, "potion cap 5")
	assert_eq(inventory.get_count(berserk), 5)
	assert_eq(inventory.add_item(aspen, 120), 21, "material cap 99")
	assert_eq(inventory.get_count(aspen), 99)
	assert_eq(inventory.add_item(aspen, 1), 1, "full stack refuses everything")


func test_unique_items_refuse_second_copy() -> void:
	var inventory := InventoryData.new()
	assert_eq(inventory.add_item(scroll), 0)
	assert_eq(inventory.add_item(scroll), 1, "lore")
	assert_eq(inventory.add_item(key, 2), 1, "key")
	assert_eq(inventory.add_item(helmet), 0)
	assert_eq(inventory.add_item(helmet), 1, "armor")
	assert_eq(inventory.get_count(scroll), 1)


func test_get_slots_filters_by_category() -> void:
	var inventory: InventoryData = (load(STARTING_INVENTORY_PATH) as InventoryData).duplicate(true)
	assert_eq(inventory.get_slots([ItemData.Category.LORE, ItemData.Category.KEY]).size(), 2, "Inventory tab")
	assert_eq(inventory.get_slots([ItemData.Category.POTION, ItemData.Category.MATERIAL]).size(), 9, "Potions tab (7 potions, 2 materials)")
	assert_eq(inventory.get_slots([ItemData.Category.ARMOR]).size(), 4, "Loadout tab")
	assert_eq(inventory.get_slots().size(), 15, "no filter")
	for slot: SlotData in inventory.get_slots([ItemData.Category.POTION]):
		assert_true(slot.item_data is PotionData)


func test_removing_to_zero_deletes_slot() -> void:
	var inventory := InventoryData.new()
	inventory.add_item(berserk, 3)
	assert_false(inventory.remove_item(berserk, 4), "cannot remove more than owned")
	assert_eq(inventory.get_count(berserk), 3, "failed remove changes nothing")
	assert_true(inventory.remove_item(berserk, 3))
	assert_eq(inventory.slots.size(), 0, "slot deleted at zero")
	assert_false(inventory.remove_item(berserk), "nothing left")


func test_inventory_changed_fires() -> void:
	_reset_global(InventoryData.new())
	var fired: Array[int] = [0]
	var on_changed: Callable = func() -> void: fired[0] += 1
	GlobalInventory.inventory_changed.connect(on_changed)
	GlobalInventory.add_item(berserk, 5)
	assert_eq(fired[0], 1, "after add")
	GlobalInventory.add_item(berserk, 1)
	assert_eq(fired[0], 1, "a refused add does not fire")
	GlobalInventory.remove_item(berserk, 2)
	assert_eq(fired[0], 2, "after remove")
	GlobalInventory.inventory_changed.disconnect(on_changed)
	_restore_global()


func test_runtime_copy_leaves_resource_untouched() -> void:
	var source: InventoryData = load(STARTING_INVENTORY_PATH)
	var source_berserk: int = source.get_count(berserk)
	_reset_global(source)
	GlobalInventory.remove_item(berserk, 1)
	GlobalInventory.add_item(aspen, 5)
	assert_eq(source.get_count(berserk), source_berserk, "the .tres stays unchanged")
	assert_eq(GlobalInventory.get_count(berserk), source_berserk - 1)
	_restore_global()


func test_equipped_armor_counts_as_owned() -> void:
	_reset_global(InventoryData.new())
	GlobalInventory.add_item(helmet)
	assert_true(GlobalInventory.equip_armor(helmet))
	assert_eq(GlobalInventory.get_count(helmet), 0, "moved out of the inventory")
	assert_eq(GlobalInventory.get_equipped_armor(ArmorData.Slot.HELMET), helmet)
	assert_eq(GlobalInventory.add_item(helmet), 1, "a second copy is refused")
	_restore_global()


func test_potion_use_cooldown_and_boss_lock() -> void:
	_reset_global(InventoryData.new())
	var short_berserk: PotionData = berserk.duplicate()
	short_berserk.duration_seconds = 0.2
	GlobalInventory.add_item(short_berserk, 2)
	GlobalInventory.add_item(maturation, 2)
	assert_eq(GlobalInventory.get_selected_potion(), short_berserk, "first owned potion is selected")

	assert_true(GlobalInventory.use_selected_potion())
	assert_eq(GlobalInventory.get_count(short_berserk), 1)
	assert_true(GlobalInventory.is_buff_active(short_berserk))
	assert_false(GlobalInventory.use_selected_potion(), "an active potion cannot be drunk again")
	assert_eq(GlobalInventory.get_count(short_berserk), 1, "no bottle wasted")
	assert_true(GlobalInventory.use_item(maturation), "a different potion can be drunk right away")
	await wait_seconds(0.3)

	GlobalInventory.set_boss_fight_active(true)
	assert_true(GlobalInventory.loadout_locked)
	assert_false(GlobalInventory.use_item(short_berserk), "menu drinking blocked in boss fight")
	assert_true(GlobalInventory.use_selected_potion(), "quick key still works in boss fight")
	assert_eq(GlobalInventory.get_selected_potion(), maturation, "selection moves on when berserk runs out")
	GlobalInventory.notify_player_died()
	assert_false(GlobalInventory.loadout_locked)

	assert_eq(GlobalInventory.cycle_potion(), maturation, "only one potion type left")
	await wait_seconds(0.3)  # let the berserk buff end before the next test
	_restore_global()


func test_active_potion_is_not_drunk_again() -> void:
	_reset_global(InventoryData.new())
	var short_berserk: PotionData = berserk.duplicate()
	short_berserk.duration_seconds = 0.3
	GlobalInventory.add_item(short_berserk, 2)
	assert_true(GlobalInventory.use_item(short_berserk))
	await wait_seconds(0.1)
	var before: float = GlobalInventory.get_buff_time_left(short_berserk)
	assert_false(GlobalInventory.use_item(short_berserk), "refused while active")
	assert_eq(GlobalInventory.get_count(short_berserk), 1, "no bottle wasted")
	assert_true(GlobalInventory.get_buff_time_left(short_berserk) <= before, "timer not restarted")
	await wait_seconds(0.4)
	assert_true(GlobalInventory.use_item(short_berserk), "can drink again after it ends")
	await wait_seconds(0.4)  # let the buff end before the next test
	_restore_global()


func test_potion_buff_ends_with_its_timer() -> void:
	await wait_seconds(0.3)  # let the previous test's cooldown run out
	_reset_global(InventoryData.new())
	var stats: PlayerStats = GlobalPlayerManager.player_stats
	var turtle: PotionData = (load(ITEMS_DIR + "turtle_potion.tres") as PotionData).duplicate()
	turtle.duration_seconds = 0.3
	var durability: float = stats.get_stat(Stats.Stat.DURABILITY)
	GlobalInventory.add_item(turtle, 1)
	assert_true(GlobalInventory.use_item(turtle))
	assert_eq(stats.get_stat(Stats.Stat.DURABILITY), durability + 25.0, "Turtle +25 durability")
	assert_true(stats.has_buffs(turtle.get_key()))
	await wait_seconds(0.5)
	assert_false(GlobalInventory.is_buff_active(turtle))
	assert_false(stats.has_buffs(turtle.get_key()), "buff removed when the timer ends")
	assert_eq(stats.get_stat(Stats.Stat.DURABILITY), durability)
	_restore_global()


func test_armor_changes_stats_and_does_not_heal() -> void:
	_reset_global(InventoryData.new())
	var stats: PlayerStats = GlobalPlayerManager.player_stats
	var max_health: float = stats.get_stat(Stats.Stat.MAX_HEALTH)
	var durability: float = stats.get_stat(Stats.Stat.DURABILITY)
	stats.take_damage(HitData.new(21.0))
	var health: float = stats.health
	GlobalInventory.add_item(helmet)
	assert_true(GlobalInventory.equip_armor(helmet))
	assert_eq(stats.get_stat(Stats.Stat.MAX_HEALTH), max_health + helmet.health, "helmet health")
	assert_eq(stats.get_stat(Stats.Stat.DURABILITY), durability + helmet.durability, "helmet durability")
	assert_eq(stats.health, health + helmet.health, "same missing amount")
	assert_true(GlobalInventory.unequip_armor(ArmorData.Slot.HELMET))
	assert_eq(stats.get_stat(Stats.Stat.MAX_HEALTH), max_health)
	assert_eq(stats.health, health, "equip and unequip does not heal")
	assert_false(stats.has_buffs(PlayerStats.EQUIPMENT_SOURCE))
	stats.restore_all()
	_restore_global()


func _reset_global(inventory: InventoryData) -> void:
	GlobalInventory.notify_player_died()
	GlobalInventory.set_equipped(EquippedData.new())
	GlobalInventory.set_inventory(inventory)


func _restore_global() -> void:
	_reset_global(GlobalInventory.starting_inventory)
