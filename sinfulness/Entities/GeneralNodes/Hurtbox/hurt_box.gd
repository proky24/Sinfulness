class_name HurtBox extends Area2D

@export var damage: int = 1
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
	if a is HitBox:
		a.take_damage(damage)
	pass
