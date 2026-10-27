class_name PlayerStats extends Stats
## The player's stats, leveling, mana and corruption. GlobalPlayerManager holds the runtime copy.
##
## Leveling works like Elden Ring: level_up() spends orbs and adds one point to one stat.
## Player level = 1 + all points spent.

signal mana_changed(mana: float, max_mana: float)
signal corruption_changed(corruption: float, max_corruption: float)
signal orbs_changed(orbs: int)
signal leveled_up(stat: Stats.Stat, new_level: int)

const LEVELABLE_STATS: Array[Stat] = [
	Stat.MAX_HEALTH,
	Stat.MAX_MANA,
	Stat.DAMAGE,
	Stat.DURABILITY,
	Stat.CORRUPTION_DURABILITY,
	Stat.LUCK,
	Stat.FAITH,
	Stat.DISGRACE,
]
const EQUIPMENT_SOURCE: StringName = &"equipment"

@export_group("Base stats")
@export var base_max_mana: float = 100.0
@export var base_corruption_durability: float = 5.0
@export var base_luck: float = 0.0
@export var base_faith: float = 0.0
@export var base_disgrace: float = 0.0

@export_group("Per point")
@export var max_health_per_point: float = 6.0
@export var max_mana_per_point: float = 5.0
@export var damage_per_point: float = 1.0
@export var durability_per_point: float = 2.0
@export var corruption_durability_per_point: float = 2.0
## 1 luck = +1 % crit chance with the default crit_chance_per_luck.
@export var luck_per_point: float = 1.0
@export var faith_per_point: float = 1.0
@export var disgrace_per_point: float = 1.0

@export_group("Crit")
@export var base_crit_chance: float = 0.05
@export var crit_chance_per_luck: float = 0.01

@export_group("Mana")
## Mana gained for each hit that damages an enemy.
@export var mana_per_hit: float = 5.0

@export_group("Leveling")
## Cost = round(level_cost_base × level ^ level_cost_exponent).
@export var level_cost_base: float = 2.0
@export var level_cost_exponent: float = 1.5

@export_group("Corruption")
@export var max_corruption: float = 100.0

var points: Dictionary[Stat, int] = {}
var orbs: int = 0
var mana: float = 0.0
var corruption: float = 0.0


## Computes every stat and fills health and mana.
func setup() -> void:
	super.setup()
	_set_mana(get_stat(Stat.MAX_MANA))
	corruption_changed.emit(corruption, max_corruption)
	orbs_changed.emit(orbs)


func get_stat_bonus(stat: Stat, stat_points: int) -> float:
	return stat_points * _get_per_point(stat)


func get_level() -> int:
	var level: int = 1
	for stat_points: int in points.values():
		level += stat_points
	return level


func get_stat_level(stat: Stat) -> int:
	return 1 + _get_points(stat)


## Orbs needed for the next level.
func get_level_up_cost() -> int:
	return roundi(level_cost_base * pow(get_level(), level_cost_exponent))


func can_level_up() -> bool:
	return orbs >= get_level_up_cost()


## Spends orbs and adds one point to [param stat]. Only LEVELABLE_STATS. Returns true on success.
func level_up(stat: Stat) -> bool:
	if not stat in LEVELABLE_STATS or not can_level_up():
		return false
	orbs -= get_level_up_cost()
	points[stat] = _get_points(stat) + 1
	recalculate()
	orbs_changed.emit(orbs)
	leveled_up.emit(stat, get_stat_level(stat))
	return true


func add_orbs(amount: int) -> void:
	if amount <= 0:
		return
	orbs += amount
	orbs_changed.emit(orbs)


## Spends [param amount] mana. Returns false and spends nothing when there is not enough.
func spend_mana(amount: float) -> bool:
	if amount < 0.0 or mana < amount:
		return false
	_set_mana(mana - amount)
	return true


func restore_mana(amount: float) -> void:
	if amount <= 0.0:
		return
	_set_mana(mana + amount)


## Positive amounts are reduced by corruption durability and scaled by corruption gain.
## Negative amounts (Maturation) are applied as they are.
func add_corruption(amount: float) -> void:
	if amount > 0.0:
		amount = _reduce_by(amount, get_stat(Stat.CORRUPTION_DURABILITY)) * (1.0 + get_stat(Stat.CORRUPTION_GAIN))
	var new_corruption: float = clampf(corruption + amount, 0.0, max_corruption)
	if is_equal_approx(new_corruption, corruption):
		return
	corruption = new_corruption
	corruption_changed.emit(corruption, max_corruption)


## Full health and mana (used by the placeholder death). Orbs, points, corruption and buffs stay.
func restore_all() -> void:
	_depleted = false
	_set_health(get_stat(Stat.MAX_HEALTH))
	_set_mana(get_stat(Stat.MAX_MANA))


## Rebuilds the equipment buffs (all ADD) from the worn [param pieces].
func apply_equipment(pieces: Array[ArmorData]) -> void:
	var buffs: Array[StatBuff] = []
	for piece: ArmorData in pieces:
		if piece == null:
			continue
		_append_add(buffs, Stat.MAX_HEALTH, piece.health)
		_append_add(buffs, Stat.DAMAGE, piece.damage)
		_append_add(buffs, Stat.DURABILITY, piece.durability)
		_append_add(buffs, Stat.CORRUPTION_DURABILITY, piece.corruption_durability)
		_append_add(buffs, Stat.DISGRACE, piece.disgrace)
		_append_add(buffs, Stat.CORRUPTION_GAIN, piece.corruption_gain)
		_append_add(buffs, Stat.STANCE, piece.stance)
		_append_add(buffs, Stat.DASH_DISTANCE, piece.dash_distance_modifier)
		_append_add(buffs, Stat.ATTACK_SPEED, piece.attack_speed_modifier)
	add_buffs(buffs, EQUIPMENT_SOURCE)


## 0.05 + luck × 0.01 by default, clamped to 0..1.
func get_crit_chance() -> float:
	return clampf(base_crit_chance + get_stat(Stat.LUCK) * crit_chance_per_luck, 0.0, 1.0)


# -- Virtual -------------------------------------------------------------------


func _get_base_value(stat: Stat) -> float:
	match stat:
		Stat.MAX_MANA:
			return base_max_mana
		Stat.CORRUPTION_DURABILITY:
			return base_corruption_durability
		Stat.LUCK:
			return base_luck
		Stat.FAITH:
			return base_faith
		Stat.DISGRACE:
			return base_disgrace
	return super._get_base_value(stat)


func _get_points(stat: Stat) -> int:
	return points.get(stat, 0)


## Keeps the missing health (never below 1) and the missing mana when a max changes.
func _keep_missing_amounts(old_values: Dictionary) -> void:
	super._keep_missing_amounts(old_values)
	var change: float = get_stat(Stat.MAX_MANA) - float(old_values.get(Stat.MAX_MANA, 0.0))
	if not is_zero_approx(change):
		_set_mana(mana + change)


# -- Private -------------------------------------------------------------------


func _get_per_point(stat: Stat) -> float:
	match stat:
		Stat.MAX_HEALTH:
			return max_health_per_point
		Stat.MAX_MANA:
			return max_mana_per_point
		Stat.DAMAGE:
			return damage_per_point
		Stat.DURABILITY:
			return durability_per_point
		Stat.CORRUPTION_DURABILITY:
			return corruption_durability_per_point
		Stat.LUCK:
			return luck_per_point
		Stat.FAITH:
			return faith_per_point
		Stat.DISGRACE:
			return disgrace_per_point
	return 0.0


func _set_mana(value: float) -> void:
	var max_mana: float = get_stat(Stat.MAX_MANA)
	mana = clampf(value, 0.0, max_mana)
	mana_changed.emit(mana, max_mana)


func _append_add(buffs: Array[StatBuff], stat: Stat, amount: float) -> void:
	if not is_zero_approx(amount):
		buffs.append(StatBuff.new(stat, StatBuff.BuffType.ADD, amount))
