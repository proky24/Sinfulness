class_name StatRow extends Label

@export var stat : PlayerStats.Stat 

var _player_stats: PlayerStats = null
var _global_player_manager: GlobalPlayerManager = null

func _ready() -> void:
	_global_player_manager = get_node("/root/GlobalPlayerManager")
	_player_stats = _global_player_manager.player_stats
	update_stat(stat)

	_player_stats.leveled_up.connect(update_stat)
	pass

func update_stat(_stat: PlayerStats.Stat, _stat_points: int = 1) -> void:
	if _stat != stat:
		return
	text = str(int(_player_stats.get_stat(stat)))
	pass