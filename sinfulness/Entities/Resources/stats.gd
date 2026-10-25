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

enum EntityType { PLAYER, ENEMY }
@export var entity_type: EntityType = EntityType.PLAYER

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

func recalculate_stats() -> void:
    pass