class_name PotionData extends ItemData
## A potion. Drinking it gives a temporary buff, or an instant effect when duration_seconds is 0.

enum Stat { HEALTH, DAMAGE, DURABILITY, CORRUPTION_DURABILITY, LUCK, FAITH, DISGRACE, CORRUPTION }

@export var stat_changed: Stat = Stat.HEALTH
@export var amount: float = 0.0
## Buff length in seconds (about 60 to 90). 0 means an instant effect, for example Maturation.
@export var duration_seconds: float = 60.0


func _init() -> void:
	category = Category.POTION
	max_stack = 5


func is_instant() -> bool:
	return duration_seconds <= 0.0


## GlobalInventory removes the potion, starts the cooldown and runs the buff timer.
func use(_user: Node) -> bool:
	# Stats system (not built yet):
	# if is_instant():
	# 	_user.stats.apply_instant(stat_changed, amount)   # e.g. Maturation lowers corruption
	# else:
	# 	_user.stats.add_buff(id, stat_changed, amount)    # removed on GlobalInventory.potion_effect_ended
	return true
