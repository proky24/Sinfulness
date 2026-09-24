class_name InteractionsHost extends Node2D

@onready var player: Player = $".."

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.dir_changed.connect(update_dir)
	pass # Replace with function body.

func update_dir( new_dir: Vector2 ) -> void:
	match new_dir:
		Vector2.LEFT:
			rotation_degrees = 90
		Vector2.RIGHT:
			rotation_degrees = -90
	pass
