class_name EnemyStats extends Stats
## An enemy's stats. Each enemy works on its own duplicate, so enemies sharing a .tres do not share health.

@export_group("Rewards")
## Orbs the player gets for the kill.
@export var orb_reward: int = 2

@export_group("Combat")
## Corruption put into this enemy's outgoing hits (for later enemy attacks).
@export var corruption_per_hit: float = 0.0


func _get_hit_corruption() -> float:
	return corruption_per_hit
