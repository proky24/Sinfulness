class_name HurtBox extends Area2D
## Deals damage: on touching a HitBox it builds a hit from source_stats and passes it on.

## Emitted when the target actually took damage (not during its stun or after death).
signal hit_landed(target: HitBox, hit: HitData)

## Multiplies the owner's damage (the player's combo sets it per attack).
@export var damage_multiplier: float = 1.0
## The owner's stats, set by the owner in _ready().
var source_stats: Stats

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	area_entered.connect(_area_entered)
	pass

func _process(_delta: float) -> void:
	if monitoring:
		collision_shape.visible = true
	else:
		collision_shape.visible = false
	pass

func _area_entered(a : Area2D) -> void:
	if not a is HitBox:
		return
	if source_stats == null:
		push_warning("HurtBox %s has no source_stats, hit ignored" % get_path())
		return
	var hit: HitData = source_stats.create_hit(damage_multiplier, global_position)
	a.take_damage(hit)
	if hit.applied:
		hit_landed.emit(a, hit)
	pass
