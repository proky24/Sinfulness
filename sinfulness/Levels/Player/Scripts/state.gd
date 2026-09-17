class_name State extends Node

static var player: Player
static var state_machine: PlayerStateMachine

func _ready() -> void:
	pass 

func enter() -> void:
	pass

func exit() -> void:
	pass

func init() -> void:
	pass

func process(delta: float) -> State:
	return null

func physics_process(delta: float) -> State:
	return null

func _handle_input(event: InputEvent) -> State:
	return null
