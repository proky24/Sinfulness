class_name StatRow extends Label

@export var stat : PlayerStats.Stat 


func _ready() -> void:
	pass

func update_stat(player_stats: PlayerStats) -> void:
	text = str(int(player_stats.get_stat(stat)))
	pass