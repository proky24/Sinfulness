class_name LevelButton extends Button
## Stat
@export var stat: PlayerStats.Stat
## label that displayes how many points are added to the stat
@export var value_label: Label
## true = + false = -
@export var operation: bool = false

var global_player_manager: GlobalPlayerManager = null
var player_stats: PlayerStats = null

var spending_orbs: int = 0

func _ready() -> void:
	self.pressed.connect(_on_pressed)
	global_player_manager = get_node("/root/GlobalPlayerManager")
	player_stats = global_player_manager.player_stats

func _on_pressed() -> void:
	if operation:
		if player_stats.can_level_up():
			value_label.text = str(int(value_label.text) + 1)
			player_stats.level_up(stat, 1)
	else:
		if int(value_label.text) > 0:
			value_label.text = str(int(value_label.text) - 1)
			player_stats.level_up(stat, -1)
