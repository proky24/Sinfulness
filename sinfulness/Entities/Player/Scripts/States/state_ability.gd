class_name StateAbility extends State

@onready var idle: StateIdle = $"../Idle"
@onready var walk: StateWalk = $"../Walk"

## abilities sprites
@onready var cleanse_sprite: Sprite2D = $AbilitiesSpriteHolder/Purrified/Cleanse
@onready var gods_soldier_sprite: Sprite2D = $AbilitiesSpriteHolder/Purrified/GodsSoldier
## corrupted abilities
@onready var rage_overflow_sprite: Sprite2D = $AbilitiesSpriteHolder/Corrupted/RageOverflow
@onready var meet_the_end_sprite: Sprite2D = $AbilitiesSpriteHolder/Corrupted/MeetTheEnd
@onready var taste_your_own_hate_sprite: Sprite2D = $AbilitiesSpriteHolder/Corrupted/TasteYourOwnHate

enum Stances {PURRIFIED, CORRUPTED}
var stance 
func _ready() -> void:
	pass 

func enter() -> void:
	pass

func exit() -> void:
	pass

func init() -> void:
	pass

func process(_delta: float) -> State:
	return null

func physics_process(_delta: float) -> State:
	return null