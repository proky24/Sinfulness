class_name StateStun extends State

@onready var idle: StateIdle = $"../Idle"
@onready var camera: PlayerCamera = $"../../Camera2D"
@onready var audio: AudioStreamPlayer2D = $"../../Audio/AudioStreamPlayer2D"

@export var knockback_speed: float = 50
@export var decelerate_speed: float = 10.0

@export_group("SFX")
@export var hit_sfx: AudioStream

var _direction: Vector2 
var animation_finished: bool = false
var stun_duration: float = 0.3
var player_camera_shake: float = 0.0

var attacker: Enemy

func init() -> void:
	player.hit_box.Damaged.connect(_on_player_damaged)
	player.animation_player.animation_finished.connect(_on_animation_finished)
	pass

func enter() -> void:
	player_camera_shake = attacker.stun.global_player_camera_shake

	animation_finished = false
	player.make_invulnerable(stun_duration)

	_direction = player.global_position.direction_to(attacker.global_position)
	player.cardinal_dir = _direction
	player.set_dir()

	camera.trigger_shake(player_camera_shake)

	audio.pitch_scale = randf_range(0.9, 1.1)
	audio.stream = hit_sfx
	audio.play()
	player.update_animation("stun")
	pass

func _on_animation_finished(_anim_name: StringName) -> void:
	animation_finished = true
	pass

func process(_delta: float) -> State:
	player.velocity -= player.velocity * decelerate_speed * _delta

	if animation_finished == true:
		return idle
	return null

func _on_player_damaged(_hit: HitData) -> void:
	state_machine.change_state(self)
	pass
