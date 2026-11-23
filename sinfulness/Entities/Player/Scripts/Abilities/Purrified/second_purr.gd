class_name SecondPurr extends Ability
## Sunrise Ability

var sunrise_ability
var degrees: int = 0

var reset_called: bool = false

func _ready() -> void:
	super()

	sunrise_ability = get_tree().get_nodes_in_group("Sunrise_ability")
	pass

func trigger() -> void:
	reset_called = false
	for c in sunrise_ability:
		if degrees < 360:
			c.shoot(degrees)
			degrees += 45
	pass

func reset_degrees() -> void:
	if reset_called == false:
		degrees = 0
		reset_called = true
	pass