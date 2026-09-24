class_name StateBlock extends State

@onready var idle: StateIdle = $"../Idle"
@onready var walk: StateWalk = $"../Walk"
@onready var attack: StateAttack = $"../Attack"
@onready var block: StateBlock = $"."
@onready var animation_player: AnimationPlayer = $"../../AnimationPlayer"
@onready var block_timer: Timer = $BlockTimer

@export var decalerate_speed: int = 10

var blocking = false

func enter() -> void:
	if block_timer.time_left > 0:
		return
	block_timer.start()
	
	PlayerHud.appear()
	
	player.velocity = Vector2.ZERO
	
	player.update_animation("block")
	blocking = true
	
	animation_player.animation_finished.connect(disable_blocking)
	pass

func exit() -> void:
	PlayerHud.inactive()
	animation_player.animation_finished.disconnect(disable_blocking)
	blocking = false
	pass

func init() -> void:
	pass

func process(delta: float) -> State:
	player.velocity -= player.velocity * decalerate_speed * delta
	
	if blocking == false:
		if player.direction == Vector2.ZERO:
			return idle
		else:
			return walk
	return null

func disable_blocking(a: String) -> void:
	blocking = false
	pass

func physics_process(delta: float) -> State:
	return null

func _handle_input(event: InputEvent) -> State:
	return null
