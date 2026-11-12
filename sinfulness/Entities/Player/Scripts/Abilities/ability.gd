class_name Ability extends Node

@onready var timer = $Timer

@export_range(0, 1) var stance: int = 0
@export var slot: String
@export var mana_cost: float = 0
@export var cooldown: float = 0
@export var corruption_on_use: float = 0

func _ready() -> void:
    timer.wait_time = cooldown
    pass


func get_power() -> void:

    pass