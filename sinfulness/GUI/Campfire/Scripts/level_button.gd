class_name LevelButton extends Button
## Stat
@export var stat: PlayerStats.Stat
## label that displayes how many points are added to the stat
@export var value_label: Label
## true = + false = -
@export var operation: bool = false

@export var campfire_ui: CanvasLayer

var global_player_manager: GlobalPlayerManager = null
var player_stats: PlayerStats = null

func _ready() -> void:
	self.pressed.connect(_on_pressed)
	global_player_manager = get_node("/root/GlobalPlayerManager")
	player_stats = global_player_manager.player_stats

	campfire_ui.closing.connect(_on_campfire_closing)

func _on_campfire_closing() -> void:
	if campfire_ui.confirmed == false and int(value_label.text) > 0 and operation == false:
		player_stats.remove_points(stat, int(value_label.text))
		player_stats.set_orbs(campfire_ui.orbs_on_opening)
		

func _on_pressed() -> void:
	if operation:
		if player_stats.can_level_up():
			value_label.text = str(int(value_label.text) + 1)
			player_stats.level_up(stat, 1)

	else:
		if int(value_label.text) > 0:
			value_label.text = str(int(value_label.text) - 1)
			player_stats.level_up(stat, -1)
