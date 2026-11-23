class_name SecondPurr extends Ability
## Sunrise Ability

var sunrise_ability
var degrees: int = 0
func _ready() -> void:
	super()

	sunrise_ability = get_tree().get_nodes_in_group("Sunrise_ability")

	print(sunrise_ability)
	pass

func trigger() -> void:
	for c in sunrise_ability:
		if degrees < 360:
			c.shoot(degrees)
			degrees += 45
	pass

func _reset_degrees() -> void:
	degrees = 0
	pass