extends Node

const PLAYER_SCENE: PackedScene = preload("res://Entities/Player/Player.tscn")
## Template only. The game works on player_stats, a runtime copy that survives scene reloads.
const PLAYER_STATS_TEMPLATE: PlayerStats = preload("res://Entities/Player/player_stats.tres")

var player: Player
var player_stats: PlayerStats
var player_spawned: bool = false

signal interact_pressed

func _ready() -> void:
	player_stats = PLAYER_STATS_TEMPLATE.duplicate(true) as PlayerStats
	player_stats.setup()
	add_player_instance()
	await get_tree().create_timer(0.3).timeout
	player_spawned = true
	pass
   

func add_player_instance() -> void:
	player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	pass

func set_player_position(position: Vector2) -> void:
	if player != null:
		player.global_position = position
	
func set_as_parent(_n: Node2D) -> void:
	if player.get_parent():
		player.get_parent().remove_child(player)
	_n.add_child(player)
	pass

## Moves the player from the level back under GlobalPlayerManager (counterpart of set_as_parent),
## so a scene reload does not free it.
func reclaim_player() -> void:
	if player.get_parent() == self:
		return
	if player.get_parent():
		player.get_parent().remove_child(player)
	add_child(player)
	pass
