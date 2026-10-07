class_name EnemyStateWander extends EnemyState

@export var anim_name: String = "wander"
@export var wander_speed: int = 50

@export_category("AI")
@export var state_animation_dur: float = 0.7
@export var state_cycles_min: int = 1
@export var state_cycles_max: int = 3
@export var next_state: EnemyState

var _timer: float = 0.0
var _direction: Vector2

func _ready() -> void:
	pass 

func enter() -> void:
	_timer = randi_range(state_cycles_min, state_cycles_max) * state_animation_dur
	
	var rand = randi_range(0, 3)
	_direction = enemy.dir4[rand]
	enemy.velocity = _direction * wander_speed
	
	enemy.set_direction(_direction)
	enemy.update_animation(anim_name)
	
	pass

func exit() -> void:
	pass

func init() -> void:
	pass

func process(_delta: float) -> EnemyState:
	_timer -= _delta
	if _timer <= 0:
		return next_state
	return null

func physics_process(_delta: float) -> EnemyState:
	if enemy.is_on_wall():
		_timer = 0
		return next_state
	return null

func _handle_input(event: InputEvent) -> EnemyState:
	return null
