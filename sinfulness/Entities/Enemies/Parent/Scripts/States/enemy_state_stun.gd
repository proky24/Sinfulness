class_name EnemyStunState extends EnemyState

@export var anim_name: String = "stun"
@export var knockback_speed: float = 50.0
@export var decelerate_speed: float = 10.0

@export_category("AI")
@export var next_state: EnemyState

var _direction: Vector2
var animation_finished: bool = false

func _ready() -> void:
	pass 

func enter() -> void:
	animation_finished = false
	enemy.invulnerable = true
	
	_direction = -enemy.global_position.direction_to(enemy.player.global_position)
	
	enemy.set_direction(_direction)
	enemy.velocity = _direction * knockback_speed
	
	enemy.update_animation(anim_name)
	enemy.animation_player.animation_finished.connect(_on_animation_finished)
	pass

func exit() -> void:
	enemy.invulnerable = false
	enemy.animation_player.animation_finished.disconnect(_on_animation_finished)
	pass

func init() -> void:
	enemy.enemy_damaged.connect(_on_enemy_damaged)
	pass

func process(_delta: float) -> EnemyState:
	if animation_finished == true:
		return next_state
	enemy.velocity -= enemy.velocity * decelerate_speed * _delta 
	return null

func physics_process(_delta: float) -> EnemyState:
	return null

func _handle_input(event: InputEvent) -> EnemyState:
	return null

func _on_enemy_damaged() -> void:
	state_machine.change_state(self)
	pass

func _on_animation_finished(_a: String) -> void:
	animation_finished = true
	pass
