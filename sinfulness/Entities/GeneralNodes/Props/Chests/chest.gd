@tool
class_name Chest extends Prop

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_opened: bool = false

func _ready() -> void:
	super()
	if openable:
		area_2d.area_entered.connect(_on_area_entered)
		area_2d.area_exited.connect(_on_area_exited)
	pass

func _on_interact_pressed() -> void:
	if is_opened == true:
		return
	is_opened = true
	animation_player.play("open_chest")

	if item_data and amount > 0:
		GlobalInventory.add_item(item_data, amount)
	pass

func _on_area_entered(_a: Area2D):
	GlobalPlayerManager.interact_pressed.connect(_on_interact_pressed)
	pass

func _on_area_exited(_a: Area2D):
	GlobalPlayerManager.interact_pressed.disconnect(_on_interact_pressed)
	pass
