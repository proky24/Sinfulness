class_name ThirdCorrupt extends Ability
## Taste your own Hate ability

var hurt_box_default_pos: Vector2
var end_anim_duration: float = 0.35

func trigger() -> void:
	player.make_invulnerable(ability_anim)

	hurt_box_default_pos = player.hurt_box.position

	await get_tree().create_timer(ability_anim).timeout

	player.hurt_box.damage_multiplier = get_power()
	player.hurt_box.monitoring = true
	change_hurt_box_pos()

	get_tree().create_timer(end_anim_duration).timeout.connect(_on_timer_timeout)
	pass

func _on_timer_timeout() -> void:
	player.hurt_box.position = hurt_box_default_pos
	player.hurt_box.damage_multiplier = 1.0
	player.hurt_box.monitoring = false
	player.hurt_box.scale = Vector2(1, 1)
	pass


func change_hurt_box_pos() -> void:
	player.hurt_box.scale = Vector2(2, 2)
	pass
