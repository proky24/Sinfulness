class_name FirstCorrupt extends Ability
## Rage Overflow ability

@onready var buffs_timer: Timer = $AbilityBuffsTimer
@onready var attack_state: StateAttack = $"../../Attack"

var add_corruption: float = 5.00

var damage_multiplier: float = 0.00
var damage_percentage: Array[float] = [1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0]

var reps: int = 0

func _ready() -> void:
	super()
	buffs_timer.timeout.connect(_on_timer_timeout)
	pass

func trigger() -> void:
	await get_tree().create_timer(ability_anim).timeout
	buffs_timer.start()

	player.hurt_box.hit_landed.connect(_on_hit_landed)

	player_stats.add_corruption(corruption_on_use)

	pass

func _on_hit_landed(_target: HitBox, _hit: HitData) -> void:
	if buffs_timer.time_left > 0:
		player_stats.add_corruption(add_corruption)

		var damage = player_stats.get_stat(Stats.Stat.DAMAGE)
		damage_multiplier = damage * ((damage / (damage * damage_percentage[reps] )) / 2)
		attack_state.rage_overflow_dmg_mult = damage_multiplier

		if reps < damage_percentage.size() - 1:
			reps += 1
	pass

func _on_timer_timeout() -> void:
	player.hurt_box.hit_landed.disconnect(_on_hit_landed)

	reps = 0

	attack_state.rage_overflow_dmg_mult = 1.00
	pass
