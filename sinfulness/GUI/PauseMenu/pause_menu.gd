extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_paused = false

func _ready() -> void:
    hide_pause_menu()
    pass

func hide_pause_menu() -> void:
    is_paused = false
    get_tree().paused = false
    visible = false
    pass

func show_pause_menu() -> void:
    is_paused = true
    get_tree().paused = true  
    visible = true  
    animation_player.play("open_menu")
    animation_player.speed_scale = 1.3

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause_menu"):
        if is_paused:
            hide_pause_menu()
        else:
            show_pause_menu()