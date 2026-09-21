class_name StateIdle extends State

@onready var idle: StateIdle = $"."
@onready var walk: StateWalk = $"../Walk"
@onready var attack: StateAttack = $"../Attack"
@onready var block: StateBlock = $"../Block"

func enter() -> void:
	player.update_animation("idle")
	pass

func exit() -> void:
	pass

func init() -> void:
	pass

func process(delta: float) -> State:
	if player.direction != Vector2.ZERO:
		return walk
	
	player.velocity = Vector2.ZERO
	return null

func physics_process(delta: float) -> State:
	return null

func _handle_input(event: InputEvent) -> State:
	if event.is_action_pressed("attack"):
		return attack
	elif event.is_action_pressed("block"):
		return block
	return idle
