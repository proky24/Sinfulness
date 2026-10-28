class_name PotionData extends ItemData
## A potion. Instant amounts are applied on drinking; buffs last duration_seconds.
## GlobalInventory removes the buffs when the potion's timer ends (both use get_key()).

## Stat buffs active for duration_seconds. Drinking again replaces them (no stacking).
@export var buffs: Array[StatBuff] = []
## Buff length in seconds (about 60 to 90). 0 means an instant potion, for example Maturation.
@export var duration_seconds: float = 60.0

@export_group("Instant")
@export var heal_amount: float = 0.0
@export var mana_amount: float = 0.0
## Negative lowers corruption (Maturation).
@export var corruption_amount: float = 0.0


func _init() -> void:
	category = Category.POTION
	max_stack = 5


func is_instant() -> bool:
	return duration_seconds <= 0.0


## Applies the instant amounts and the buffs to [param user].stats. Returns false when the user has no stats.
func use(user: Node) -> bool:
	print("[PotionData] using potion: %s" % name)
	var stats: Stats = user.get("stats") as Stats if user != null else null
	if stats == null:
		return false
	if heal_amount > 0.0:
		stats.heal(heal_amount)
	var player_stats: PlayerStats = stats as PlayerStats
	if player_stats != null:
		if mana_amount > 0.0:
			player_stats.restore_mana(mana_amount)
		if not is_zero_approx(corruption_amount):
			player_stats.add_corruption(corruption_amount)
	if not is_instant() and not buffs.is_empty():
		stats.add_buffs(buffs, get_key())
	return true
