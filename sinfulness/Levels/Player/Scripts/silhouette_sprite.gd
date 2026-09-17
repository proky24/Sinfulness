extends Sprite2D

@onready var _silhuouette_sprite: Sprite2D = $SilhouetteSprite

# Set the initial values of the relevant properties
func _ready() -> void:
	_silhuouette_sprite.texture = texture
	_silhuouette_sprite.offset = offset
	_silhuouette_sprite.flip_h = flip_h
	_silhuouette_sprite.hframes = hframes
	_silhuouette_sprite.vframes = vframes
	_silhuouette_sprite.frame = frame
	pass # Replace with function body.


# Set th silhuouette sprite`s properties when they are changes
func _set(property: StringName, value: Variant) -> bool:
	if is_instance_valid(_silhuouette_sprite):
		match property:
			"texture":
				_silhuouette_sprite.texture = value
			"offset":
				_silhuouette_sprite.offset = value
			"flip_h":
				_silhuouette_sprite.flip_h = value
			"hframes":
				_silhuouette_sprite.hframes = value
			"vframes":
				_silhuouette_sprite.vframes = value
			"frame":
				_silhuouette_sprite.frame = value
	return false
