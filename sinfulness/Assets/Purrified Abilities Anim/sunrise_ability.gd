class_name Sunrise extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hurt_box: HurtBox = $HurtBox

var parent: Node

func _ready() -> void:
    parent = get_parent()
    animation_player.animation_finished.connect(_on_animation_finished)


func shoot(_degrees: int) -> void:
    position = GlobalPlayerManager.player.global_position
    visible = true
    process_mode = Node.PROCESS_MODE_INHERIT

    rotation_degrees = _degrees
    animation_player.play("shoot")
    pass

func _on_animation_finished(_a: String) -> void:
    hurt_box.monitoring = false
    get_parent().reset_degrees()
    pass