class_name StateWalk extends State

@onready var idle: StateIdle = $"../Idle"
@onready var walk: StateWalk = $"."
@onready var attack: Node = $"../Attack"
@onready var block: StateBlock = $"../Block"

@export var speed: int = 100

func enter() -> void:
	player.update_animation("walk")
	pass

func exit() -> void:
	pass

func init() -> void:
	pass

func process(_delta: float) -> State:
	if player.direction == Vector2.ZERO:
		return idle
	
	player.set_dir()
	player.velocity = player.direction * speed
	return null

func physics_process(_delta: float) -> State:
	return null

func _handle_input(event: InputEvent) -> State:
	if event.is_action_pressed("attack"):
		return attack
	elif event.is_action_pressed("block"):
		return block
	elif event.is_action_pressed("interact"):
		GlobalPlayerManager.interact_pressed.emit()
	return walk
