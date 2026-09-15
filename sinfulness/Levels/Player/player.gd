extends CharacterBody2D

var direction: Vector2 = Vector2.ZERO
var speed: float = 75.0
func _process(delta: float) -> void:
	direction = Vector2(
		Input.get_axis("left", "right"),
		Input.get_axis("forward", "backwords")
	).normalized()
	
	velocity = direction * speed

func _physics_process(delta: float) -> void:
	move_and_slide()
	
