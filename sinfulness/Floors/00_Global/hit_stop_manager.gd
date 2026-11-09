extends Node

func stop_time() -> void:
    Engine.time_scale = 0
    await get_tree().create_timer(0.2, true, false, true).timeout
    Engine.time_scale = 1
    pass