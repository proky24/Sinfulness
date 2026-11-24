class_name SecondCorrupt extends Ability
## Meet the End ability

@onready var range_area: Area2D = %E_1Range
@onready var buffs_timer: Timer = $AbilityBuffsTimer

var in_range: Array[Enemy]
var target: Enemy
func _ready() -> void:
	super()
	pass

func trigger() -> void:
	buffs_timer.start()
	buffs_timer.timeout.connect(_on_buff_timer_timeout)

	get_parent().activate_e_1 = false

	target = in_range[0]
	target.enemy_damaged.connect(_on_enemy_damaged)
	target.enemy_destroyed.connect(_on_enemy_destroyed)
	pass

func _on_enemy_destroyed() -> void:
	in_range.remove_at(0)
	if in_range.size() > 0 and buffs_timer.time_left > 0:
		
		target = in_range[0]
		target.effects_player.play("E_1")
	pass

func _on_enemy_damaged() -> void:
	print(target.stats.health)
	print((target.stats.health / 10) * 5)
	if target.stats.health < ( (target.stats.health / 10) * 5): #get_power() so bigger stat means bigger percantage)
		target.stats.health = 0
		target.enemy_destroyed.emit()
	pass

func _on_buff_timer_timeout() -> void:
	if is_instance_valid(target):
		target.sprite.modulate = Color8(255, 255, 255)
	target = null
	in_range = []
	pass
