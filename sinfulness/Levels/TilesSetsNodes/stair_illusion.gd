class_name Illusion extends Area2D

@export var decelerate_speed: float = -50.0
var _player: Player

func _ready() -> void: 
	area_entered.connect(_slow_player)
	area_exited.connect(_fasten_player)
	_player = GlobalPlayerManager.player
	
	pass

func _slow_player(_a: Area2D) -> void:
	_player.velocity = _player.direction * decelerate_speed
	pass

func _fasten_player(_a: Area2D) -> void:
	_player.velocity = _player.direction * _player.speed
	pass
