class_name StateAbility extends State

@onready var idle: StateIdle = $"../Idle"
@onready var walk: StateWalk = $"../Walk"

## abilities sprites
@onready var cleanse_sprite: Sprite2D = %Cleanse
@onready var gods_soldier_sprite: Sprite2D = %GodsSoldier
## corrupted abilities
@onready var rage_overflow_sprite: Sprite2D = %RageOverflow
@onready var meet_the_end_sprite: Sprite2D = %MeetTheEnd
@onready var taste_your_own_hate_sprite: Sprite2D = %TasteYourOwnHate

enum Stances {PURRIFIED, CORRUPTED}
var stance 

var event: String = ""
var using_ability: bool = false


func _ready() -> void:
	stance = Stances.CORRUPTED
	pass 

func enter() -> void:
	player.velocity = Vector2.ZERO

	player.update_animation(event + "_" + str(stance))
	player.animation_player.animation_finished.connect(_on_ability_end)

	using_ability = true

	pass

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

func _on_ability_end(a: String) -> void:
	using_ability = false
	pass
