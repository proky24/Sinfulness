class_name Stats extends Resource

@export_group("Base Stats")
@export var base_max_health: float = 90.0
@export var base_max_corruption: float = 100.0
@export var base_durability: float = 5.0
@export var base_corruption_durability: float = 5.0
@export var base_damage: float = 10.0
@export var base_luck: float = 0.0
@export var base_faith: float = 0.0
@export var base_disgrace: float = 0.0
@export var experience: float = 0.0: set = _on_experience_set



@export_group("Entity type")
enum EntityType { PLAYER, ENEMY }
@export var entity_type: EntityType = EntityType.PLAYER

enum BuffableStats {
    MAX_HEALTH, 
    DURABILITY, 
    CORRUPTION_DURABILITY, 
    DAMAGE, 
    LUCK, 
    FAITH, 
    DISGRACE
}

#const STAT_CURVES: Dictionary[BuffableStats, Curve] = {
#    BuffableStats.MAX_HEALTH: preload("res://Entities/StatSystem/Curves/max_health_curve.tres"),
#    BuffableStats.DURABILITY: preload("res://Entities/StatSystem/Curves/durability_curve.tres"),
#    BuffableStats.CORRUPTION_DURABILITY: preload("res://Entities/StatSystem/Curves/corruption_durability_curve.tres"),
#    BuffableStats.DAMAGE: preload("res://Entities/StatSystem/Curves/damage_curve.tres"),
#    BuffableStats.LUCK: preload("res://Entities/StatSystem/Curves/luck_curve.tres"),
#    BuffableStats.FAITH: preload("res://Entities/StatSystem/Curves/faith_curve.tres"),
#    BuffableStats.DISGRACE: preload("res://Entities/StatSystem/Curves/disgrace_curve.tres")
#}

signal health_changed(new_health: float, current_max_health: float)
signal health_depleted

func _init() -> void:
    if entity_type == EntityType.ENEMY:
        base_corruption_durability = 0.0
        base_faith = 0.0
        base_disgrace = 0.0
    setup_stats.call_deferred()

    pass

var current_max_health: float = base_max_health
var current_durability: float = base_durability
var current_corruption_durability: float = base_corruption_durability
var current_damage: float = base_damage
var current_luck: float = base_luck
var current_faith: float = base_faith
var current_disgrace: float = base_disgrace
var current_corruption: float = 0.0

var health: float = 90.0: set = _on_health_set
var level: int = 1: 
    get(): return floor(max(1.0, sqrt(experience / level_xp_needed) + 0.5))
var level_xp_needed: float = 100.0

var stat_buffs: Array[StatBuff]

func add_buff(buff: StatBuff) -> void:
    stat_buffs.append(buff)
    recalculate_stats.call_deferred()
    pass

func remove_buff(buff: StatBuff) -> void:
    stat_buffs.erase(buff)
    recalculate_stats.call_deferred()
    pass

func _on_health_set(value: float) -> void:
    health = clampf(value, 0.0, current_max_health)
    health_changed.emit(health, current_max_health)

    if health <= 0.0:
        health_depleted.emit()
        pass

func _on_experience_set(value: float) -> void:
    var old_level: int = level
    experience = value

    if old_level != level:
        recalculate_stats()
    pass

func setup_stats() -> void:
    current_max_health = base_max_health
    current_durability = base_durability
    current_corruption_durability = base_corruption_durability
    current_damage = base_damage
    current_luck = base_luck
    current_faith = base_faith
    current_disgrace = base_disgrace
    current_corruption = 0.0

func recalculate_stats() -> void:
    var stat_multipliers: Dictionary = {} #Amount to multiply included stats by
    var stat_addends: Dictionary = {} #Amount to add to included stats

    for buff in stat_buffs:
        var stat_name: String = BuffableStats.keys()[buff.stat].to_lower()
        match buff.buff_type:
            StatBuff.BuffType.ADD:
                if not stat_addends.has(stat_name):
                    stat_addends[stat_name] = 0.0
                stat_addends[stat_name] += buff.buff_amount
            StatBuff.BuffType.MULTIPLY:
                if not stat_multipliers.has(stat_name):
                    stat_multipliers[stat_name] = 1.0
                stat_multipliers[stat_name] *= buff.buff_amount

                if stat_multipliers[stat_name] < 0.0:
                    stat_multipliers[stat_name] = 0.0
    
    #var stat_starting_pos: float = (float(level / 100.0)) - 0.1
    #current_max_health = base_max_health * STAT_CURVES[BuffableStats.MAX_HEALTH].sample(stat_starting_pos)
    #current_durability = base_durability * STAT_CURVES[BuffableStats.DURABILITY].sample(stat_starting_pos)
    #current_corruption_durability = base_corruption_durability * STAT_CURVES[BuffableStats.CORRUPTION_DURABILITY].sample(stat_starting_pos)
    #current_damage = base_damage * STAT_CURVES[BuffableStats.DAMAGE].sample(stat_starting_pos)
    #current_luck = base_luck * STAT_CURVES[BuffableStats.LUCK].sample(stat_starting_pos)
    #current_faith = base_faith * STAT_CURVES[BuffableStats.FAITH].sample(stat_starting_pos)
    #current_disgrace = base_disgrace * STAT_CURVES[BuffableStats.DISGRACE].sample(stat_starting_pos)

    for stat_name in stat_multipliers:
        var curr_property_name: String = str("current_" + stat_name)
        set(curr_property_name, get(curr_property_name) * stat_multipliers[stat_name])

    for stat_name in stat_addends:
        var curr_property_name: String = str("current_" + stat_name)
        set(curr_property_name, get(curr_property_name) + stat_addends[stat_name])
    pass