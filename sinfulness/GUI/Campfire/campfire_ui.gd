extends CanvasLayer

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact"):
        queue_free()
        PauseMenu.process_mode = Node.PROCESS_MODE_ALWAYS
        get_tree().paused = false