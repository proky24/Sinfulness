class_name FirstPurr extends Ability
## Cleanse ability

func trigger() -> void:
    var corruption_to_erase: float = roundf(player_stats.corruption * (get_power() / (get_power() + 10)))

    var to_heal: float = (player_stats.get_stat(Stats.Stat.MAX_HEALTH) / 100) * ( get_power() + player_stats.get_stat_level(faith))
    player_stats.add_corruption(-corruption_to_erase)
    player_stats.heal(to_heal)
    pass