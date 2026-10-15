@tool
extends Node2D

const PICKUP_MESSAGE_SCENE: PackedScene = preload("res://GUI/PauseMenu/Inventory/Items/Item_Pick_up/PickupMessage.tscn")

@export var item_data: ItemData : set = _set_item_data
@export_range(1, 99) var quantity: int = 1

@onready var area: Area2D = $Area2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

## True once the whole stack was taken, so a second body in the same frame cannot add it again.
var _is_consumed: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_sprite()
	if Engine.is_editor_hint():
		return

	area.body_entered.connect(_on_area_entered)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _item_picked_up() -> void:
	area.body_entered.disconnect(_on_area_entered)
	visible = false
	if audio_player.stream == null:
		queue_free()
		return
	audio_player.play()

	await audio_player.finished
	queue_free()

	pass

func _set_item_data(value: ItemData) -> void:
	item_data = value
	_update_sprite()
	pass

func _on_area_entered(body: Node2D) -> void:
	if _is_consumed or not body is Player or item_data == null:
		return
	var leftover: int = GlobalInventory.add_item(item_data, quantity)
	var picked: int = quantity - leftover
	if picked <= 0:
		return
	_show_message(picked)
	if leftover == 0:
		_is_consumed = true
		_item_picked_up()
	else:
		quantity = leftover

	pass

## Spawns the "{name} x{picked}" message in the parent, so it outlives this pickup.
func _show_message(picked: int) -> void:
	var message: PickupMessage = PICKUP_MESSAGE_SCENE.instantiate() as PickupMessage
	message.setup(item_data, picked)
	message.position = position
	get_parent().add_child(message)

func _update_sprite() -> void:
	if item_data != null and sprite != null:
		sprite.texture = item_data.texture
	pass
