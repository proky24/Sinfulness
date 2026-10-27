class_name Stats extends Resource
## Stats shared by the player and enemies. Use PlayerStats or EnemyStats, not Stats itself.
##
## Always work on a runtime copy (duplicate(true)) and call setup() once.
## Final value = (base + get_stat_bonus() + ADD buffs) × MULTIPLY buffs, never below 0.
## Subclasses override _get_base_value(), _get_points(), get_stat_bonus() and get_crit_chance().

signal health_changed(health: float, max_health: float)
## Emitted once when health reaches 0.
signal health_depleted
signal damaged(amount: float, is_crit: bool)
signal stats_changed

enum Stat {
	MAX_HEALTH,
	MAX_MANA,
	DAMAGE,
	DURABILITY,
	CORRUPTION_DURABILITY,
	LUCK,
	FAITH,
	DISGRACE,
	STANCE,
	DASH_DISTANCE,
	ATTACK_SPEED,
	CORRUPTION_GAIN,
}

@export_group("Base stats")
@export var base_max_health: float = 90.0
@export var base_damage: float = 10.0
@export var base_durability: float = 5.0

@export_group("Combat")
## Durability equal to this value halves incoming damage.
@export var durability_scale: float = 100.0
@export_range(0.0, 1.0) var crit_chance: float = 0.0
@export var crit_multiplier: float = 1.5

var health: float = 0.0

var _buffs: Array[StatBuff] = []
var _values: Dictionary[Stat, float] = {}
var _depleted: bool = false


## Computes every stat and fills health. Call once on the runtime copy.
func setup() -> void:
	recalculate()
	_depleted = false
	_set_health(get_stat(Stat.MAX_HEALTH))


func get_stat(stat: Stat) -> float:
	return _values.get(stat, 0.0)


## Adds copies of [param buffs] under [param source]. Earlier buffs from the same source are replaced.
func add_buffs(buffs: Array[StatBuff], source: StringName) -> void:
	_erase_buffs(source)
	for buff: StatBuff in buffs:
		if buff == null:
			continue
		var copy: StatBuff = buff.duplicate() as StatBuff
		copy.source = source
		_buffs.append(copy)
	recalculate()


## Removes every buff from [param source].
func remove_buffs(source: StringName) -> void:
	if _erase_buffs(source):
		recalculate()


func has_buffs(source: StringName) -> bool:
	for buff: StatBuff in _buffs:
		if buff.source == source:
			return true
	return false


## Recomputes every stat from base values, points and buffs. A max health change keeps the missing amount.
func recalculate() -> void:
	var old_values: Dictionary = _values.duplicate()
	var addends: Dictionary[Stat, float] = {}
	var multipliers: Dictionary[Stat, float] = {}
	for buff: StatBuff in _buffs:
		match buff.buff_type:
			StatBuff.BuffType.ADD:
				addends[buff.stat] = addends.get(buff.stat, 0.0) + buff.amount
			StatBuff.BuffType.MULTIPLY:
				multipliers[buff.stat] = multipliers.get(buff.stat, 1.0) * buff.amount
	for stat: Stat in Stat.values():
		var value: float = _get_base_value(stat) + get_stat_bonus(stat, _get_points(stat)) + addends.get(stat, 0.0)
		_values[stat] = maxf(value * multipliers.get(stat, 1.0), 0.0)
	if not old_values.is_empty():
		_keep_missing_amounts(old_values)
	stats_changed.emit()


## Rolls a crit and returns a hit worth this entity's damage × [param multiplier].
func create_hit(multiplier: float, source_position: Vector2) -> HitData:
	var is_crit: bool = randf() < get_crit_chance()
	var amount: float = get_stat(Stat.DAMAGE) * multiplier
	if is_crit:
		amount *= crit_multiplier
	return HitData.new(amount, is_crit, _get_hit_corruption(), source_position)


## Applies [param hit] reduced by durability. Returns the damage taken and sets hit.applied.
func take_damage(hit: HitData) -> float:
	if hit == null or is_dead() or hit.amount <= 0.0:
		return 0.0
	var taken: float = _reduce_by(hit.amount, get_stat(Stat.DURABILITY))
	hit.applied = true
	damaged.emit(taken, hit.is_crit)
	_set_health(health - taken)
	return taken


func heal(amount: float) -> void:
	if amount <= 0.0 or is_dead():
		return
	_set_health(health + amount)


func is_dead() -> bool:
	return health <= 0.0


## Chance 0..1 that a hit is a crit.
func get_crit_chance() -> float:
	return clampf(crit_chance, 0.0, 1.0)


## Bonus [param stat] gets from [param _points] level-up points. Linear: the only place for soft caps later.
func get_stat_bonus(_stat: Stat, _points: int) -> float:
	return 0.0


# -- Virtual -------------------------------------------------------------------


func _get_base_value(stat: Stat) -> float:
	match stat:
		Stat.MAX_HEALTH:
			return base_max_health
		Stat.DAMAGE:
			return base_damage
		Stat.DURABILITY:
			return base_durability
	return 0.0


func _get_points(_stat: Stat) -> int:
	return 0


func _get_hit_corruption() -> float:
	return 0.0


## Called after recalculate() when the stats existed before. Keeps health's missing amount, never below 1.
func _keep_missing_amounts(old_values: Dictionary) -> void:
	var max_health: float = get_stat(Stat.MAX_HEALTH)
	var change: float = max_health - float(old_values.get(Stat.MAX_HEALTH, 0.0))
	if is_zero_approx(change) or is_dead():
		return
	_set_health(maxf(health + change, minf(1.0, max_health)))


# -- Private -------------------------------------------------------------------


## [param amount] × durability_scale / (durability_scale + resistance). 100 resistance halves it.
func _reduce_by(amount: float, resistance: float) -> float:
	if durability_scale <= 0.0:
		return amount
	return amount * durability_scale / (durability_scale + maxf(resistance, 0.0))


func _set_health(value: float) -> void:
	var max_health: float = get_stat(Stat.MAX_HEALTH)
	health = clampf(value, 0.0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0.0 and not _depleted:
		_depleted = true
		health_depleted.emit()


func _erase_buffs(source: StringName) -> bool:
	var erased: bool = false
	for i: int in range(_buffs.size() - 1, -1, -1):
		if _buffs[i].source == source:
			_buffs.remove_at(i)
			erased = true
	return erased
