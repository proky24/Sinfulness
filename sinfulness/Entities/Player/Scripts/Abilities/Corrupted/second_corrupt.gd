class_name SecondCorrupt extends Ability
## Meet the End ability

@onready var buffs_timer: Timer = $AbilityBuffsTimer

var in_range: Array[Enemy]
var target: Enemy

func _ready() -> void:
	super()
	buffs_timer.timeout.connect(_on_buff_timer_timeout)
	pass

func trigger() -> void:
	buffs_timer.start()
	
	get_parent().activate_e_1 = false
	
	target = get_nearest_enemy(player.global_position)
	connect_target_signals()

	player_stats.add_corruption(corruption_on_use)
	pass

func get_nearest_enemy(from: Vector2) -> Enemy:
	var nearest: Enemy
	var best_dist: float = INF

	for e in in_range:
		if not is_instance_valid(e) or e.stats.is_dead():
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < best_dist:
			best_dist = d
			nearest = e
	return nearest

func disconnect_target_signals() -> void:
	target.enemy_damaged.disconnect(_on_enemy_damaged)
	target.enemy_destroyed.disconnect(_on_enemy_destroyed)
	pass

func connect_target_signals() -> void:
	target.enemy_damaged.connect(_on_enemy_damaged)
	target.enemy_destroyed.connect(_on_enemy_destroyed)
	pass

func _on_enemy_destroyed() -> void:
	disconnect_target_signals()
	in_range.erase(target)
	target = null
	if buffs_timer.time_left > 0:
		target = get_nearest_enemy(player.global_position)		
				
		if target != null:
			connect_target_signals()
			target.effects_player.play("E_1")
	pass

func _on_enemy_damaged() -> void:
	if target.stats.health < target.stats.get_stat(target.stats.Stat.MAX_HEALTH) * 0.5: #get_power() so bigger stat means bigger percantage)
		target.execute()
	pass	

func _on_buff_timer_timeout() -> void:
	if is_instance_valid(target):
		target.sprite.modulate = Color8(255, 255, 255)
		disconnect_target_signals()

	target = null
	in_range = []
	pass
