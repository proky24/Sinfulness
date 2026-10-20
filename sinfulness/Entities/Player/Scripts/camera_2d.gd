class_name PlayerCamera extends Camera2D

@onready var player: Player = get_parent() as Player


func _ready() -> void:
	GlobalLevelManager.tilemap_bounds_changed.connect(update_limits)
	update_limits(GlobalLevelManager.curr_tilemap_bounds)
	pass

func update_limits(bounds: Array[Vector2]) -> void:
	if bounds.size() < 2:
		return
	limit_left = int(bounds[0].x)
	limit_top = int(bounds[0].y)
	limit_right = int(bounds[1].x)
	limit_bottom = int(bounds[1].y)
	pass

func _process(_delta: float) -> void:
	if player == null:
		return
	
	offset.x = player.velocity.x * 0.5
	var tween = get_tree().create_tween()
	tween.tween_property(self, "offset", offset, 0.5).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pass