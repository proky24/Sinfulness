class_name HitData extends RefCounted
## One hit, made by Stats.create_hit() and passed from a HurtBox to a HitBox.

var amount: float = 0.0
var is_crit: bool = false
## Corruption the target gains when the hit is applied (only the player gains it).
var corruption: float = 0.0
var source_position: Vector2 = Vector2.ZERO
## Set to true by the receiver when damage was actually taken.
var applied: bool = false


func _init(_amount: float = 0.0, _is_crit: bool = false, _corruption: float = 0.0, _source_position: Vector2 = Vector2.ZERO) -> void:
	amount = _amount
	is_crit = _is_crit
	corruption = _corruption
	source_position = _source_position
