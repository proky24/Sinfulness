@tool
extends Node2D

@export var item_data: ItemData : set = _set_item_data

@onready var area: Area2D = $Area2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_uptade_sprite()
	if Engine.is_editor_hint():
		return
	
	area.body_entered.connect(_on_area_entered)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _item_picked_up() -> void:
	area.body_entered.disconnect(_on_area_entered)
	audio_player.play()
	visible = false

	await audio_player.finished
	queue_free()

	pass

func _set_item_data(value: ItemData) -> void:
	item_data = value
	_uptade_sprite()
	pass

func _on_area_entered(b) -> void:
	if b is Player:
		if item_data != null:
			if GlobalPlayerManager.INVENTORY_DATA.add_item(item_data) > 0:
				_item_picked_up()
				print("Adding item to inventory: ", item_data.name)

	pass

func _uptade_sprite() -> void:
	if item_data != null and sprite != null:
		sprite.texture = item_data.texture
	pass
