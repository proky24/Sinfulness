class_name LevelShower extends Label

@export var stat : PlayerStats.Stat 

var _player_stats: PlayerStats = null
var _global_player_manager: GlobalPlayerManager = null

func _ready() -> void:
	_global_player_manager = get_node("/root/GlobalPlayerManager")
	_player_stats = _global_player_manager.player_stats
	text = "LEVEL " + str(_player_stats.get_level())

	_player_stats.leveled_up.connect(update_level)
	pass

func update_level(_stat: PlayerStats.Stat, _level: int) -> void:
	text = "LEVEL " + str(_player_stats.get_level())
