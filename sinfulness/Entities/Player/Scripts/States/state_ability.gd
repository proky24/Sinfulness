class_name StateAbility extends State

@onready var idle: StateIdle = $"../Idle"
@onready var walk: StateWalk = $"../Walk"

## abilities sprites
@onready var cleanse: Ability = %Cleanse
@onready var gods_soldier: Ability = %GodsSoldier
## corrupted abilities
@onready var rage_overflow: Ability = %RageOverflow
@onready var meet_the_end: Ability = %MeetTheEnd
@onready var taste_your_own_hate: Ability = %TasteYourOwnHate

@export_range(0, 1) var stance: int = 0
@export var slot: String
@export var mana_cost: float = 0
@export var cooldown: float = 0
@export var corruption_on_use: float = 0

enum Stances {PURRIFIED, CORRUPTED}

var event: String = ""
var using_ability: bool = false

var player_stats: PlayerStats = null

func _ready() -> void:
	stance = Stances.CORRUPTED

	player_stats = get_node("/root/GlobalPlayerManager").player_stats
	pass 

func enter() -> void:
	PlayerHud.appear()
	player.velocity = Vector2.ZERO

	player.update_animation(event + "_" + str(stance))
	player.animation_player.animation_finished.connect(_on_ability_end)

	using_ability = true

	pass

func _on_ability_end(a: String) -> void:
	using_ability = false
	pass

func can_use(_ability: Ability) -> bool:
	if player_stats.spend_mana(_ability.mana_cost) and _ability.timer.time_left == 0:
		
		pass
	return false

func exit() -> void:
	player.animation_player.animation_finished.disconnect(_on_ability_end)

	## player spend mana
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
