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

var spending_orbs: int = 0
var points: int = 0

func _ready() -> void:
	self.pressed.connect(_on_pressed)
	global_player_manager = get_node("/root/GlobalPlayerManager")
	player_stats = global_player_manager.player_stats

	campfire_ui.closing.connect(_on_campfire_closing)


func _on_campfire_closing() -> void:
	if campfire_ui.confirmed == false and points > 0:
		if operation:
			player_stats.remove_points(stat, points)
			player_stats.add_orbs(spending_orbs)

			player_stats.orbs_changed.emit(player_stats.orbs)

func _on_pressed() -> void:
	if operation:
		if player_stats.can_level_up():
			value_label.text = str(int(value_label.text) + 1)
			spending_orbs += player_stats.get_level_up_cost()
			player_stats.level_up(stat, 1)

			points += 1
	else:
		if int(value_label.text) > 0:
			value_label.text = str(int(value_label.text) - 1)
			var refund: int = roundi(player_stats.level_cost_base * pow(player_stats.get_level() - 1, player_stats.level_cost_exponent))
			spending_orbs -= refund
			player_stats.level_up(stat, -1)

			points -= 1