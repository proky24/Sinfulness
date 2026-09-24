class_name Player extends CharacterBody2D

const Sunrise = preload("res://Assets/Purrified Abilities Anim/sunrise_ability.tscn")

var direction: Vector2 = Vector2.ZERO
var cardinal_dir: Vector2 = Vector2.DOWN
var speed: float = 75.0
var hp: int = 10:
	set(value):
		hp = clampi(value, 10, 90)

@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

signal dir_changed( new_dir: Vector2 )

func _ready() -> void:
	state_machine.initialize(self)
	pass

func _process(delta: float) -> void:
	direction = Vector2(
		Input.get_axis("left", "right"),
		Input.get_axis("forward", "backwords")
	).normalized()
	
	pass

func _physics_process(delta: float) -> void:
	move_and_slide()
	pass

func set_dir() -> bool:
	var new_dir: Vector2 = cardinal_dir
	if direction == Vector2.ZERO:
		return false
	
	if direction.y == 0:
		new_dir = Vector2.LEFT if direction.x < 0 else Vector2.RIGHT
	elif direction.x == 0:
		new_dir = Vector2.UP if direction.y < 0 else Vector2.DOWN
	
	if new_dir == cardinal_dir:
		return false
	
	cardinal_dir = new_dir
	dir_changed.emit(cardinal_dir)
	if cardinal_dir == Vector2.LEFT:
		sprite.scale.x = -1
	elif cardinal_dir == Vector2.RIGHT:
		sprite.scale.x = 1
	return true
	pass

#func animation_direction() -> string:
	#if cardinal_dir == Vector2.DOWN:
		#return "down"
	#elif cardinal_dir == Vector2.UP:
		#return "up"
	#pass

func update_animation(state : String) -> void:
	animation_player.play(state)
	pass
	
func take_damage(dmg: int) -> void:
	
	pass
