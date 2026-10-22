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

func process(_delta: float) -> State:
	return null

func physics_process(_delta: float) -> State:
	return null

func _handle_input(_event: InputEvent) -> State:
	return null
