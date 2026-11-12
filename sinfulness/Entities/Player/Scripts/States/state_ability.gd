class_name StateAbility extends State

@onready var idle: StateIdle = $"../Idle"
@onready var walk: StateWalk = $"../Walk"

enum Stances {PURRIFIED, CORRUPTED}
var stance: int = 0

var event: String = ""
var using_ability: bool = false

var player_stats: PlayerStats = null

var children: Array = []
var ability_to_use: Ability

func _ready() -> void:
	player_stats = get_node("/root/GlobalPlayerManager").player_stats
	children = get_children()
	pass 

func enter() -> void:
	PlayerHud.appear()
	player.velocity = Vector2.ZERO

	activate(ability_to_use)
	ability_to_use = null

	player.animation_player.animation_finished.connect(_on_ability_end)

	using_ability = true
	pass

func _on_ability_end(_a: String) -> void:
	using_ability = false
	pass

func can_use(_ability: Ability) -> bool:
	if player_stats.mana > _ability.mana_cost and _ability.timer.is_stopped():
		if _ability.slot == "E" and _ability.stance == 1: # Meet The end
			# find enemy nearby
			pass
		return true
	return false

func activate(_ability: Ability) -> void:
	_ability.timer.start()
	player.update_animation(event + "_" + str(stance))
	_ability.get_power()

	player_stats.spend_mana(_ability.mana_cost)
	pass

func exit() -> void:
	player.animation_player.animation_finished.disconnect(_on_ability_end)

	pass

func init() -> void:
	pass

func process(_delta: float) -> State:
	if using_ability == false:
		if player.direction == Vector2.ZERO:
			return idle
		return walk
	return null

func physics_process(_delta: float) -> State:
	return null
