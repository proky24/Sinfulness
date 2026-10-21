extends Node2D

@export var sprite: Texture2D
@export var _scale: Vector2 = Vector2(1, 1)
@export var _energy: float = 1.0
@export var campfire: bool = false

@onready var sprite_node: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D
@onready var label: Label = $Area2D/Label

var label_tween: Tween


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if sprite != null:
		sprite_node.texture = sprite
	if campfire == true:
		area.monitoring = true
		area.area_entered.connect(_on_area_entered)
		area.area_exited.connect(_on_area_exited)
	pass # Replace with function body.

func _on_area_entered(_a: Area2D) -> void:
	if label_tween != null:
		label_tween.kill()
	label.visible = true
	label.modulate.a = 1.0

func _on_area_exited(_a: Area2D) -> void:
	if label_tween != null:
		label_tween.kill()
	label_tween = create_tween()
	label_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	label_tween.tween_property(label, "modulate:a", 0.0, 0.3)
	label_tween.tween_callback(label.hide)
