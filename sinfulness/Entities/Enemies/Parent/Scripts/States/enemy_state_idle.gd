class_name EnemyStateIdle extends EnemyState

@export var anim_name: String = "idle"
@export_category("AI")
@export var state_dur_min: float = 0.5
@export var state_dur_max: float = 1.5
@export var after_idle_state: EnemyState

var _timer: float = 0.0


func _ready() -> void:
	pass 

func enter() -> void:
	enemy.velocity = Vector2.ZERO
	enemy.update_animation(anim_name)
	
	_timer = randf_range(state_dur_min, state_dur_max)
	
	pass

func exit() -> void:
	pass

func init() -> void:
	pass

func process(_delta: float) -> EnemyState:
	_timer -= _delta
	if _timer <= 0:
		return after_idle_state
	return null

func physics_process(_delta: float) -> EnemyState:
	return null

func _handle_input(event: InputEvent) -> EnemyState:
	return null
