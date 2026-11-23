class_name Sunrise extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
var parent: Node

func _ready() -> void:
    parent = get_parent()


func shoot(_degrees: int) -> void:
    position = GlobalPlayerManager.player.global_position
    visible = true
    process_mode = Node.PROCESS_MODE_INHERIT

    rotation_degrees = _degrees
    animation_player.play("shoot")
    pass