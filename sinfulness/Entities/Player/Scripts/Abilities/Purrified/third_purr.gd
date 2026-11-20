class_name ThirdPurr extends Ability
## Gods Soldier ability

func trigger() -> void:
    player_stats.add_corruption(-player_stats.corruption)
    pass