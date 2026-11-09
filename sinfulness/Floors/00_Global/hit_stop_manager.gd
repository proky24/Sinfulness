extends Node

func stop_time(duration: float) -> void:
    Engine.time_scale = 0
    await get_tree().create_timer(duration, true, false, true).timeout
    Engine.time_scale = 1
    pass