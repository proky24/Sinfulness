extends TestCase
## Stat system phase 1: Stats, PlayerStats, EnemyStats and StatBuff.
## Player values are set here (PRD section 6), so tuning player_stats.tres does not break the tests.

const PLAYER_STATS_PATH: String = "res://Entities/Player/player_stats.tres"
const ENEMY_STATS_PATH: String = "res://Entities/Enemies/Parent/enemy_stats.tres"
const ITEMS_DIR: String = "res://GUI/PauseMenu/Inventory/Items/"
const HELMET_PATH: String = ITEMS_DIR + "sainted_helmet.tres"

const ADD: StatBuff.BuffType = StatBuff.BuffType.ADD
const MULTIPLY: StatBuff.BuffType = StatBuff.BuffType.MULTIPLY


func test_setup_gives_base_values_and_full_pools() -> void:
	var stats: PlayerStats = _player()
	assert_eq(stats.get_stat(Stats.Stat.MAX_HEALTH), 90.0, "max health")
	assert_eq(stats.get_stat(Stats.Stat.MAX_MANA), 100.0, "max mana")
	assert_eq(stats.get_stat(Stats.Stat.DAMAGE), 10.0, "damage")
	assert_eq(stats.get_stat(Stats.Stat.DURABILITY), 5.0, "durability")
	assert_eq(stats.get_stat(Stats.Stat.CORRUPTION_DURABILITY), 5.0, "corruption durability")
	for stat: Stats.Stat in [Stats.Stat.LUCK, Stats.Stat.FAITH, Stats.Stat.DISGRACE, Stats.Stat.STANCE,
			Stats.Stat.DASH_DISTANCE, Stats.Stat.ATTACK_SPEED, Stats.Stat.CORRUPTION_GAIN]:
		assert_eq(stats.get_stat(stat), 0.0, Stats.Stat.keys()[stat])
	assert_eq(stats.health, 90.0, "full health")
	assert_eq(stats.mana, 100.0, "full mana")
	assert_eq(stats.get_level(), 1)
	assert_eq(stats.orbs, 0)
	assert_eq(stats.corruption, 0.0)


func test_add_is_applied_before_multiply() -> void:
	var stats: PlayerStats = _player()
	var buffs: Array[StatBuff] = [StatBuff.new(Stats.Stat.DAMAGE, MULTIPLY, 1.5), StatBuff.new(Stats.Stat.DAMAGE, ADD, 10.0)]
	stats.add_buffs(buffs, &"test")
	assert_eq(stats.get_stat(Stats.Stat.DAMAGE), 30.0, "(10 + 10) × 1.5")


func test_two_multiply_buffs_multiply() -> void:
	var stats: PlayerStats = _player()
	stats.add_buffs(_buff(Stats.Stat.DAMAGE, MULTIPLY, 1.25), &"a")
	stats.add_buffs(_buff(Stats.Stat.DAMAGE, MULTIPLY, 1.25), &"b")
	assert_eq(stats.get_stat(Stats.Stat.DAMAGE), 15.625, "10 × 1.5625")


func test_same_source_replaces_and_remove_restores() -> void:
	var stats: PlayerStats = _player()
	var original: Array[StatBuff] = _buff(Stats.Stat.DURABILITY, ADD, 5.0)
	stats.add_buffs(original, &"potion")
	stats.add_buffs(_buff(Stats.Stat.DURABILITY, ADD, 7.0), &"potion")
	assert_eq(stats.get_stat(Stats.Stat.DURABILITY), 12.0, "second add replaced the first")
	assert_true(stats.has_buffs(&"potion"))
	assert_eq(original[0].source, &"", "the caller's buff is not changed")
	stats.remove_buffs(&"potion")
	assert_false(stats.has_buffs(&"potion"))
	assert_eq(stats.get_stat(Stats.Stat.DURABILITY), 5.0, "back to the exact base value")


func test_recalculating_twice_changes_nothing() -> void:
	var stats: PlayerStats = _player()
	stats.add_buffs(_buff(Stats.Stat.MAX_HEALTH, MULTIPLY, 1.25), &"vigor")
	stats.add_buffs(_buff(Stats.Stat.DAMAGE, ADD, 3.0), &"armor")
	var before: Array[float] = _all_values(stats)
	var health: float = stats.health
	stats.recalculate()
	stats.recalculate()
	assert_eq(_all_values(stats), before, "no compounding")
	assert_eq(stats.health, health)


func test_level_up_spends_orbs_and_raises_one_stat() -> void:
	var stats: PlayerStats = _player()
	assert_false(stats.level_up(Stats.Stat.DAMAGE), "no orbs")
	stats.add_orbs(2)
	assert_true(stats.level_up(Stats.Stat.DAMAGE))
	assert_eq(stats.orbs, 0, "cost 2 spent")
	assert_eq(stats.get_stat(Stats.Stat.DAMAGE), 11.0)
	assert_eq(stats.get_level(), 2)
	assert_eq(stats.get_stat_level(Stats.Stat.DAMAGE), 2)
	assert_eq(stats.get_stat_level(Stats.Stat.LUCK), 1)
	assert_false(stats.level_up(Stats.Stat.DAMAGE), "5 orbs short of 6")
	stats.add_orbs(100)
	assert_false(stats.level_up(Stats.Stat.STANCE), "equipment-only stat")
	assert_eq(stats.orbs, 100, "refused level-up spends nothing")
	assert_true(stats.level_up(Stats.Stat.MAX_HEALTH))
	assert_eq(stats.get_stat(Stats.Stat.MAX_HEALTH), 96.0)
	assert_eq(stats.health, 96.0, "the bonus also heals")


func test_level_up_cost() -> void:
	var stats: PlayerStats = _player()
	assert_eq(stats.get_level_up_cost(), 2, "level 1")
	stats.points[Stats.Stat.DAMAGE] = 1
	assert_eq(stats.get_level_up_cost(), 6, "level 2")
	stats.points[Stats.Stat.DAMAGE] = 9
	assert_eq(stats.get_level(), 10)
	assert_eq(stats.get_level_up_cost(), 63, "level 10")


func test_durability_reduces_damage() -> void:
	var stats: PlayerStats = _player()
	var hit := HitData.new(15.0)
	assert_eq(stats.take_damage(hit), 15.0 * 100.0 / 105.0, "durability 5")
	assert_true(hit.applied)
	assert_eq(stats.health, 90.0 - 15.0 * 100.0 / 105.0)
	stats.add_buffs(_buff(Stats.Stat.DURABILITY, ADD, 95.0), &"test")
	assert_eq(stats.take_damage(HitData.new(20.0)), 10.0, "durability 100 halves")


func test_crit_chance_from_luck() -> void:
	var stats: PlayerStats = _player()
	assert_eq(stats.get_crit_chance(), 0.05)
	stats.add_buffs(_buff(Stats.Stat.LUCK, ADD, 5.0), &"fortune")
	assert_eq(stats.get_crit_chance(), 0.10)
	stats.add_buffs(_buff(Stats.Stat.LUCK, ADD, 95.0), &"fortune")
	assert_eq(stats.get_crit_chance(), 1.0, "100 % crit")
	var hit: HitData = stats.create_hit(1.4, Vector2(3, 4))
	assert_true(hit.is_crit)
	assert_eq(hit.amount, 10.0 * 1.4 * 1.5)
	assert_eq(hit.source_position, Vector2(3, 4))
	stats.add_buffs(_buff(Stats.Stat.LUCK, ADD, 500.0), &"fortune")
	assert_eq(stats.get_crit_chance(), 1.0, "clamped at 1")
	var enemy: EnemyStats = _enemy()
	assert_eq(enemy.get_crit_chance(), 0.0)
	var enemy_hit: HitData = enemy.create_hit(1.0, Vector2.ZERO)
	assert_false(enemy_hit.is_crit)
	assert_eq(enemy_hit.amount, 8.0)


func test_max_change_keeps_missing_amount() -> void:
	var stats: PlayerStats = _player()
	stats.take_damage(HitData.new(31.5))
	assert_eq(stats.health, 60.0, "30 missing")
	stats.add_buffs(_buff(Stats.Stat.MAX_HEALTH, ADD, 20.0), &"armor")
	assert_eq(stats.health, 80.0, "max 110, still 30 missing")
	stats.remove_buffs(&"armor")
	assert_eq(stats.health, 60.0, "unequip takes the bonus back")
	stats.take_damage(HitData.new(52.5))
	assert_eq(stats.health, 10.0)
	stats.add_buffs(_buff(Stats.Stat.MAX_HEALTH, ADD, -30.0), &"curse")
	assert_eq(stats.get_stat(Stats.Stat.MAX_HEALTH), 60.0)
	assert_eq(stats.health, 1.0, "never below 1")
	assert_false(stats.is_dead())
	stats.spend_mana(30.0)
	stats.add_buffs(_buff(Stats.Stat.MAX_MANA, ADD, 20.0), &"armor")
	assert_eq(stats.mana, 90.0, "max mana 120, still 30 missing")
	stats.remove_buffs(&"armor")
	assert_eq(stats.mana, 70.0)


func test_health_depleted_fires_once() -> void:
	var stats: PlayerStats = _player()
	var count: Array[int] = [0]
	stats.health_depleted.connect(func() -> void: count[0] += 1)
	stats.take_damage(HitData.new(1000.0))
	assert_true(stats.is_dead())
	var late_hit := HitData.new(10.0)
	assert_eq(stats.take_damage(late_hit), 0.0, "a dead target takes nothing")
	assert_false(late_hit.applied)
	stats.heal(50.0)
	assert_eq(stats.health, 0.0, "heal does not revive")
	assert_eq(count[0], 1, "emitted once")
	stats.restore_all()
	assert_eq(stats.health, 90.0)
	assert_eq(stats.mana, 100.0)
	stats.take_damage(HitData.new(1000.0))
	assert_eq(count[0], 2, "once per death")


func test_spend_mana_refuses_when_short() -> void:
	var stats: PlayerStats = _player()
	assert_true(stats.spend_mana(30.0))
	assert_eq(stats.mana, 70.0)
	assert_false(stats.spend_mana(80.0))
	assert_eq(stats.mana, 70.0, "nothing spent")
	stats.restore_mana(stats.mana_per_hit)
	assert_eq(stats.mana, 75.0)
	stats.restore_mana(1000.0)
	assert_eq(stats.mana, 100.0, "clamped to max")


func test_corruption_is_reduced_and_clamped() -> void:
	var stats: PlayerStats = _player()
	var changes: Array[float] = []
	stats.corruption_changed.connect(func(value: float, _max: float) -> void: changes.append(value))
	stats.add_corruption(21.0)
	assert_eq(stats.corruption, 20.0, "21 × 100 / 105")
	stats.add_buffs(_buff(Stats.Stat.CORRUPTION_GAIN, ADD, 0.5), &"decayed")
	stats.add_corruption(21.0)
	assert_eq(stats.corruption, 50.0, "+20 × 1.5")
	stats.add_corruption(-10.0)
	assert_eq(stats.corruption, 40.0, "negative applied as it is")
	stats.add_corruption(1000.0)
	assert_eq(stats.corruption, 100.0, "clamped to 100")
	stats.add_corruption(-1000.0)
	assert_eq(stats.corruption, 0.0, "clamped to 0")
	assert_eq(changes.size(), 5)


func test_apply_equipment_adds_armor_stats() -> void:
	var stats: PlayerStats = _player()
	var helmet: ArmorData = load(HELMET_PATH)
	assert_not_null(helmet)
	if helmet == null:
		return
	var pieces: Array[ArmorData] = [helmet]
	stats.apply_equipment(pieces)
	assert_eq(stats.get_stat(Stats.Stat.MAX_HEALTH), 90.0 + helmet.health)
	assert_eq(stats.get_stat(Stats.Stat.DURABILITY), 5.0 + helmet.durability)
	assert_eq(stats.get_stat(Stats.Stat.STANCE), helmet.stance)
	var none: Array[ArmorData] = []
	stats.apply_equipment(none)
	assert_false(stats.has_buffs(PlayerStats.EQUIPMENT_SOURCE))
	assert_eq(stats.get_stat(Stats.Stat.MAX_HEALTH), 90.0)
	assert_eq(stats.health, 90.0, "equip and unequip never heals")


func test_duplicated_enemy_stats_do_not_share_health() -> void:
	var template: EnemyStats = load(ENEMY_STATS_PATH)
	assert_not_null(template)
	if template == null:
		return
	assert_eq(template.base_max_health, 30.0)
	assert_eq(template.base_damage, 8.0)
	assert_eq(template.base_durability, 0.0)
	assert_eq(template.orb_reward, 2)
	var a: EnemyStats = template.duplicate(true)
	var b: EnemyStats = template.duplicate(true)
	a.setup()
	b.setup()
	a.take_damage(HitData.new(10.0))
	assert_eq(a.health, 20.0)
	assert_eq(b.health, 30.0)
	assert_eq(template.health, 0.0, "the template is never set up")


func test_global_player_manager_holds_a_ready_copy() -> void:
	var manager: Node = get_autoload("GlobalPlayerManager")
	assert_not_null(manager)
	if manager == null:
		return
	var stats: PlayerStats = manager.get("player_stats")
	assert_not_null(stats, "player_stats")
	if stats == null:
		return
	assert_true(stats != load(PLAYER_STATS_PATH), "a runtime copy, not the template")
	assert_true(stats.get_stat(Stats.Stat.MAX_HEALTH) > 0.0)
	assert_eq(stats.health, stats.get_stat(Stats.Stat.MAX_HEALTH), "full health")
	assert_eq(stats.mana, stats.get_stat(Stats.Stat.MAX_MANA), "full mana")


# -- Potions -------------------------------------------------------------------


## Stand-in for the Player: PotionData.use() only needs user.stats.
class FakeUser extends Node:
	var stats: Stats


func test_each_potion_changes_its_stat() -> void:
	_check_potion("potion.tres", Stats.Stat.DAMAGE, 12.5)
	_check_potion("fortune_teller_potion.tres", Stats.Stat.LUCK, 5.0)
	_check_potion("turtle_potion.tres", Stats.Stat.DURABILITY, 30.0)
	_check_potion("vigor_potion.tres", Stats.Stat.MAX_HEALTH, 112.5)
	_check_potion("saint_potion.tres", Stats.Stat.FAITH, 5.0)
	_check_potion("decayed_potion.tres", Stats.Stat.DISGRACE, 5.0)


func test_instant_potions() -> void:
	var user := FakeUser.new()
	user.stats = _player()
	var stats: PlayerStats = user.stats
	var maturation: PotionData = load(ITEMS_DIR + "maturation_potion.tres")
	var mana_potion: PotionData = load(ITEMS_DIR + "mana_potion.tres")
	assert_true(maturation.is_instant() and mana_potion.is_instant())
	stats.add_corruption(31.5)
	assert_eq(stats.corruption, 30.0)
	assert_true(maturation.use(user))
	assert_eq(stats.corruption, 20.0, "Maturation -10")
	stats.spend_mana(50.0)
	assert_true(mana_potion.use(user))
	assert_eq(stats.mana, 80.0, "Mana Potion +30")
	assert_true(mana_potion.use(user))
	assert_eq(stats.mana, 100.0, "clamped to max")
	assert_false(stats.has_buffs(maturation.get_key()), "instant potions add no buffs")
	user.free()


func test_redrinking_does_not_stack() -> void:
	var user := FakeUser.new()
	user.stats = _player()
	var berserk: PotionData = load(ITEMS_DIR + "potion.tres")
	berserk.use(user)
	berserk.use(user)
	assert_eq(user.stats.get_stat(Stats.Stat.DAMAGE), 12.5, "still × 1.25")
	user.free()


func test_vigor_heals_and_takes_it_back() -> void:
	var user := FakeUser.new()
	user.stats = _player()
	var stats: PlayerStats = user.stats
	var vigor: PotionData = load(ITEMS_DIR + "vigor_potion.tres")
	vigor.use(user)
	assert_eq(stats.health, 112.5, "heals by the bonus")
	stats.take_damage(HitData.new(102.5 * 105.0 / 100.0))
	assert_eq(stats.health, 10.0)
	stats.remove_buffs(vigor.get_key())
	assert_eq(stats.get_stat(Stats.Stat.MAX_HEALTH), 90.0)
	assert_eq(stats.health, 1.0, "the bonus is taken back, never below 1")
	user.free()


func test_potion_without_stats_is_refused() -> void:
	var berserk: PotionData = load(ITEMS_DIR + "potion.tres")
	assert_false(berserk.use(null))
	var user := FakeUser.new()
	assert_false(berserk.use(user), "user.stats is null")
	var plain := Node.new()
	assert_false(berserk.use(plain), "no stats property")
	user.free()
	plain.free()


func test_potion_data() -> void:
	for file: String in ["potion.tres", "fortune_teller_potion.tres", "turtle_potion.tres", "vigor_potion.tres",
			"saint_potion.tres", "decayed_potion.tres", "maturation_potion.tres", "mana_potion.tres"]:
		var potion: PotionData = load(ITEMS_DIR + file)
		assert_not_null(potion, file)
		if potion == null:
			continue
		assert_eq(potion.get_max_stack(), 5, file + " max stack")
		assert_true(potion.id != &"", file + " id")
		assert_not_null(potion.texture, file + " icon")
		assert_eq(potion.duration_seconds, 0.0 if file in ["maturation_potion.tres", "mana_potion.tres"] else 60.0, file + " duration")


func _check_potion(file: String, stat: Stats.Stat, expected: float) -> void:
	var potion: PotionData = load(ITEMS_DIR + file)
	assert_not_null(potion, file)
	if potion == null:
		return
	var user := FakeUser.new()
	user.stats = _player()
	assert_true(potion.use(user), file)
	assert_eq(user.stats.get_stat(stat), expected, file)
	assert_true(user.stats.has_buffs(potion.get_key()), file + " buff source is the potion key")
	user.free()


# -- Helpers -------------------------------------------------------------------


func _player() -> PlayerStats:
	var stats := PlayerStats.new()
	stats.base_max_health = 90.0
	stats.base_max_mana = 100.0
	stats.base_damage = 10.0
	stats.base_durability = 5.0
	stats.base_corruption_durability = 5.0
	stats.base_luck = 0.0
	stats.base_crit_chance = 0.05
	stats.crit_chance_per_luck = 0.01
	stats.crit_multiplier = 1.5
	stats.durability_scale = 100.0
	stats.max_health_per_point = 6.0
	stats.damage_per_point = 1.0
	stats.level_cost_base = 2.0
	stats.level_cost_exponent = 1.5
	stats.mana_per_hit = 5.0
	stats.setup()
	return stats


func _enemy() -> EnemyStats:
	var stats := EnemyStats.new()
	stats.base_max_health = 30.0
	stats.base_damage = 8.0
	stats.base_durability = 0.0
	stats.crit_chance = 0.0
	stats.setup()
	return stats


func _buff(stat: Stats.Stat, type: StatBuff.BuffType, amount: float) -> Array[StatBuff]:
	var buffs: Array[StatBuff] = [StatBuff.new(stat, type, amount)]
	return buffs


func _all_values(stats: Stats) -> Array[float]:
	var values: Array[float] = []
	for stat: Stats.Stat in Stats.Stat.values():
		values.append(stats.get_stat(stat))
	return values
