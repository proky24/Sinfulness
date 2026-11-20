class_name Ability extends Node

@onready var timer = $Timer

@export_range(0, 1) var stance: int = 0
@export var slot: String
@export var mana_cost: float = 0
@export var cooldown: float = 0
@export var corruption_on_use: float = 0
@export var ability_to_call: Node = null
@export var buff_timer_latency: float = 0.0

var player_stats: PlayerStats = null
var faith = null
var disgrace = null

var player: Player

func _ready() -> void:
	timer.wait_time = cooldown
	
	player_stats = get_node("/root/GlobalPlayerManager").player_stats
	player = get_node("/root/GlobalPlayerManager").player

	faith = Stats.Stat.FAITH
	disgrace = Stats.Stat.DISGRACE
	pass


func get_power() -> float:
	var multiplication: float = 0.0
	if stance == 0:
		multiplication = player_stats.get_stat(faith)
	else:
		multiplication = player_stats.get_stat(disgrace)
	return multiplication
	pass
