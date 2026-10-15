class_name PickupMessage extends Node2D
## World-space "{name} x{amount}" text shown after a pickup. Slides up while fading out, then frees itself.
##
## Set the text with setup() and the position before adding it to the tree; the animation starts in _ready().

## How far the text rises, in pixels.
@export var rise_distance: float = 12.0
## Total time of the slide and fade, in seconds.
@export var duration: float = 0.8

@onready var label: Label = $Label

var _text: String = ""
var _start_position: Vector2


func setup(item: ItemData, amount: int) -> void:
	_text = "%s x%d" % [item.name, amount]


func _ready() -> void:
	label.text = _text
	label.size = label.get_minimum_size()
	label.position = (-label.size / 2.0).round()
	_start_position = position.round()
	position = _start_position

	var tween: Tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_method(_set_rise, 0.0, rise_distance, duration)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(queue_free)


## Moves in whole pixels so the text stays crisp.
func _set_rise(offset: float) -> void:
	position = _start_position - Vector2(0.0, roundf(offset))
