class_name PlayerStateMachine extends Node

var states: Array[ State ]
var prev_state: State
var curr_state: State

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	pass 

func initialize() -> void:
	states = []
	
	for c in get_children():
		if c is State:
			states.append(c)
	
	pass

func change_state(new_state: State) -> void:
	if new_state == null || new_state == curr_state:
		return
	
	if curr_state:
		curr_state.exit()
	
	prev_state = curr_state
	curr_state = new_state
	
	curr_state.enter()
	pass

func _process(delta: float) -> void:
	pass
