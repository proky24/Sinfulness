extends Node

const PLAYER_SCENE: PackedScene = preload("res://Entities/Player/Player.tscn")

var player: Player
var player_spawned: bool = false   

func _ready() -> void:
    add_player_instance()
    await get_tree().create_timer(0.3).timeout
    player_spawned = true
    pass
   

func add_player_instance() -> void:
    player = PLAYER_SCENE.instantiate() as Player
    add_child(player)
    pass

func set_player_position(position: Vector2) -> void:
    if player != null:
        player.global_position = position
    
func set_as_parent(_n: Node2D) -> void:
    if player.get_parent():
        player.get_parent().remove_child(player)
    _n.add_child(player)
    pass