extends Node2D

func _ready() -> void:
    visible = false
    if GlobalPlayerManager.player_spawned == false:
        GlobalPlayerManager.set_player_position(global_position)
        GlobalPlayerManager.player_spawned = true