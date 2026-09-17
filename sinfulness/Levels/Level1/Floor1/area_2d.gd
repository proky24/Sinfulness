extends Area2D

@export var player: CharacterBody2D

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(a: Area2D) -> void:
	player.z_index = 10
	print("area entered")
	pass

func _on_area_exited(a: Area2D) -> void:
	player.z_index = 0
	print("area exited")
	pass
