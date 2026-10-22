extends Node2D

@export var sprite: Texture2D
@export var _scale: Vector2 = Vector2(1, 1)
@export var _energy: float = 1.1
@export var campfire: bool = false
@export var hframes: int = 7

@onready var sprite_node: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var area: Area2D = $Area2D
@onready var label: Label = $Area2D/Label
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var light: PointLight2D = $Sprite2D/PointLight2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

const TORCH_LIT_SFX: AudioStream = preload("res://Assets/Other SFX/Torch/Light Torch 1.wav")
const TORCH_LOOP_SFX: AudioStream = preload("res://Assets/Other SFX/Torch/Torch Loop.wav")

var label_tween: Tween


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	audio_player.pitch_scale = randf_range(0.7, 1.1)
	sprite_node.hframes = hframes
	if sprite != null:
		sprite_node.texture = sprite
	if campfire == true:
		area.monitoring = true
		collision_shape.disabled = false
		area.area_entered.connect(_on_area_entered)
		area.area_exited.connect(_on_area_exited)

		light.enabled = false
		audio_player.stop()
		animation_player.stop()

		sprite_node.frame = 0
	else:
		audio_player.max_distance = 100
		audio_player.volume_db = -20
	pass # Replace with function body.

func _on_area_entered(_a: Area2D) -> void:
	if label_tween != null:
		label_tween.kill()
	label.visible = true
	label.modulate.a = 1.0
	GlobalPlayerManager.interact_pressed.connect(_on_interact_pressed)

func _on_area_exited(_a: Area2D) -> void:
	if label_tween != null:
		label_tween.kill()
	label_tween = create_tween()
	label_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	label_tween.tween_property(label, "modulate:a", 0.0, 0.3)
	label_tween.tween_callback(label.hide)

func _on_interact_pressed() -> void:
	_play_ignition_effects()
	await get_tree().create_timer(0.5).timeout
	_play_loop_effects()

func _play_ignition_effects() -> void:
	_play_sound(TORCH_LIT_SFX, 0)
	light.enabled = true
	animation_player.play()

func _play_loop_effects() -> void:
	_play_sound(TORCH_LOOP_SFX, -5)

func _play_sound(stream: AudioStream, volume_db: float) -> void:
	audio_player.stream = stream
	audio_player.volume_db = volume_db
	audio_player.play()
