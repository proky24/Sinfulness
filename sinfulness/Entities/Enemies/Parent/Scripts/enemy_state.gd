class_name EnemyState extends Node

var enemy: Enemy
var state_machine: EnemyStateMachine

func _ready() -> void:
	pass 

func enter() -> void:
	pass

func exit() -> void:
	pass

func init() -> void:
	pass

func process(_delta: float) -> EnemyState:
	return null

func physics_process(_delta: float) -> EnemyState:
	return null

func _handle_input(event: InputEvent) -> EnemyState:
	return null
