extends PointLight2D

var _energy: float = 0
var _scale: Vector2 = Vector2.ZERO

func _ready() -> void:
	_scale = get_parent().get_parent()._scale
	_energy = get_parent().get_parent()._energy

	flicker()
	pass 


func flicker() -> void:
	if _energy == 0 and _scale == Vector2.ZERO:
		energy = randf() * 0.1 + 0.9
		scale = Vector2(1, 1) * energy	
	else:
		energy = randf() * 0.1 + 0.9 * _energy
		scale = Vector2(1, 1) * energy * _scale
	await get_tree().create_timer(0.2).timeout
	flicker()
	pass
