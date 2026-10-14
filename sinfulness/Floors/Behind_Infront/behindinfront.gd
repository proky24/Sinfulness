extends Area2D

@export var player: Player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	pass

func _on_area_entered( a: Area2D ) -> void:
	if player.position.y > self.position.y:
		player.z_index = 1
	else:
		player.z_index = -1
	await get_tree().create_timer(0.2).timeout
	_on_area_entered(a)

func _on_area_exited( a: Area2D ) -> void:
	player.z_index = 1
	pass
