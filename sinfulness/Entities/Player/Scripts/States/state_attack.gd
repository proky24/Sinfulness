class_name StateAttack extends State

@onready var idle: StateIdle = $"../Idle"
@onready var walk: StateWalk = $"../Walk"
@onready var attack: Node = $"."
@onready var attack_timer: Timer = $AttackTimer
@onready var attack_combo_timer: Timer = $AttackComboTimer
@onready var animation_player: AnimationPlayer = $"../../AnimationPlayer"
@onready var audio_stream_player: AudioStreamPlayer2D = $"../../Audio/AudioStreamPlayer2D"
@onready var hurt_box: HurtBox = $"../../Interactions/HurtBox"

@export var decalerate_speed: int = 10

var hurt_box_timer: float = 0.15

var attacking: bool = false
var attack_combo: int = 1:
	set(value):
		attack_combo = clampi(value, 1, 3)

func enter() -> void:
	PlayerHud.appear()
	
	if attack_timer.is_stopped() == false:
		return
	
	attack_timer.start()
	attack_timer.timeout.connect(attack_timeout)
	
	if attack_combo_timer.time_left > 0 and attack_combo < 3:
		attack_combo += 1
		attack_combo_timer.stop()
	else:
		attack_combo = 1
	
	attack_combo_timer.start()
	attack_combo_timer.timeout.connect(attack_combo_timeout)
	player.velocity = Vector2.ZERO
	
	player.update_animation("attack_" + str(attack_combo))
	
	attacking = true
	animation_player.animation_finished.connect(disable_attacking)
	
	if attack_combo == 2:
		hurt_box_timer = 0.3
	elif attack_combo == 3:
		hurt_box_timer = 0.45
	await get_tree().create_timer(hurt_box_timer).timeout
	hurt_box.monitoring = true
	
	pass

func exit() -> void:
	animation_player.animation_finished.disconnect(disable_attacking)
	attack_combo_timer.timeout.disconnect(attack_combo_timeout)
	attacking = false
	hurt_box.monitoring = false
	PlayerHud.inactive()
	
	pass

func init() -> void:
	pass

func process(delta: float) -> State:
	player.velocity -= player.velocity * decalerate_speed * delta
	
	if attacking == false:
		if player.direction == Vector2.ZERO:
			return idle
		else:
			return walk
	return null

func disable_attacking(a: String) -> void:
	attacking = false
	pass

func attack_timeout() -> void:
	attack_timer.timeout.disconnect(attack_timeout)
	pass

func attack_combo_timeout() -> void:
	attack_combo = 0
	attack_combo_timer.timeout.disconnect(attack_combo_timeout)
	pass

func physics_process(delta: float) -> State:
	return null

func _handle_input(event: InputEvent) -> State:
	return null
