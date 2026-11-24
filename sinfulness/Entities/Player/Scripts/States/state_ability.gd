class_name StateAbility extends State

@onready var idle: StateIdle = $"../Idle"
@onready var walk: StateWalk = $"../Walk"
@onready var e_1range: Area2D = %E_1Range
var in_range_for_e_1: Array[Enemy]
var activate_e_1: bool = false

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
	e_1range.body_entered.connect(_on_range_e_1_entered)
	e_1range.body_exited.connect(_on_range_e_1_exited)
	pass 

func enter() -> void:
	PlayerHud.appear()
	player.velocity = Vector2.ZERO

	activate(ability_to_use)
	ability_to_use = null

	if activate_e_1 == false:
		player.animation_player.animation_finished.connect(_on_ability_end)
	using_ability = true
	pass

func _on_ability_end(_a: String) -> void:
	using_ability = false
	pass

func can_use(_ability: Ability) -> bool:
	if player_stats.mana >= _ability.mana_cost and _ability.timer.is_stopped():
		if _ability.slot == "E" and _ability.stance == 1: # Meet The end
			if in_range_for_e_1.is_empty():
				return false
			else:
				activate_e_1 = true
				return true
		return true
	return false

func activate(_ability: Ability) -> void:
	_ability.timer.start()
	if activate_e_1 == true:
		in_range_for_e_1[0].effects_player.play("E_1")
		in_range_for_e_1[0].effects_player.animation_finished.connect(_on_ability_end)
		_ability.in_range = in_range_for_e_1
	else:
		player.update_animation(event + "_" + str(stance))
	_ability.trigger()

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

func _on_range_e_1_entered(a: Node2D) -> void:
	if a is Enemy:
		in_range_for_e_1.append(a)
	pass

func _on_range_e_1_exited(a: Node2D) -> void:
	if a is Enemy and in_range_for_e_1.has(a):
		in_range_for_e_1.erase(a)
	pass
