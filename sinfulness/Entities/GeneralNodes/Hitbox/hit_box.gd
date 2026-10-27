class_name HitBox extends Area2D
## Receives damage. The owner connects Damaged and sets hit.applied when damage was taken.

signal Damaged( hit: HitData )

func take_damage( hit: HitData ) -> void:
	Damaged.emit( hit )
