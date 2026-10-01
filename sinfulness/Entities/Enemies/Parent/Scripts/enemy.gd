class_name Enemy extends CharacterBody2D

signal dir_changed(new_dir: Vector2)
signal enemy_damaged()

@export var hp: int = 5

var direction: Vector2 = Vector2.ZERO
var cardinal_dir: Vector2 = Vector2.DOWN
var player: Player
var invulnerable: bool = false
const dir4 = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var hurt_box: HurtBox = $HurtBox
@onready var enemy_state_machine: Node = $EnemyStateMachine

func _ready() -> void:
	enemy_state_machine.initialize(self)
	pass

func _process(_delta: float) -> void:
	pass

func _physics_process(_delta: float) -> void:
	move_and_slide()
	pass

func set_direction(_new_dir: Vector2) -> bool:
	direction = _new_dir
	if direction == Vector2.ZERO:
		return false
	
	var direction_id : int = int(round(
		(direction * cardinal_dir * 0.1).angle()
		/ TAU * dir4.size() 
	))
	var new_dir = dir4[direction_id]
	
	if new_dir == cardinal_dir:
		return false
	
	cardinal_dir = new_dir
	dir_changed.emit(cardinal_dir)
	if cardinal_dir == Vector2.LEFT:
		sprite.scale.x = -1
	elif cardinal_dir == Vector2.RIGHT:
		sprite.scale.x = 1
	return true

func update_animation(state : String) -> void:
	animation_player.play(state)
	pass
