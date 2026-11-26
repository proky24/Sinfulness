class_name AttackDetectArea extends Area2D

signal player_in_attack_range()
signal player_not_in_attack_range()

func  _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    pass

func _on_body_entered(_b: Node2D) -> void:
    if _b is Player:
        player_in_attack_range.emit()

func _on_body_exited(_b: Node2D) -> void:
    if _b is Player:
        player_not_in_attack_range.emit()