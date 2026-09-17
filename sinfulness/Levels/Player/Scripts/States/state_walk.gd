class_name StateWalk extends State

@onready var idle: StateIdle = $"../Idle"
@onready var walk: StateWalk = $"."
@onready var attack: Node = $"../Attack"

@export var speed: int = 100

func enter() -> void:
	player.update_animation("walk")
	pass

func exit() -> void:
	pass

func init() -> void:
	pass

func process(delta: float) -> State:
	if player.direction == Vector2.ZERO:
		return idle
	
	player.set_dir()
	player.velocity = player.direction * speed
	return null

func physics_process(delta: float) -> State:
	return null

func _handle_input(event: InputEvent) -> State:
	return null
