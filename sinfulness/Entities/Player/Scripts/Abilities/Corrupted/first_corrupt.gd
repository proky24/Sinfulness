class_name FirstCorrupt extends Ability
## Rage Overflow ability

@onready var buffs_timer: Timer = $AbilityBuffsTimer

func trigger() -> void:
    buffs_timer.start()
    pass

func _process(_delta: float) -> void:
    if buffs_timer.time_left > 0:
        pass
    pass