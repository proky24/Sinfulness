class_name EnemyStateMachine extends Node

var states: Array[ EnemyState ]
var prev_state: EnemyState
var curr_state: EnemyState

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	pass 

func _process(delta: float) -> void:
	
	pass

func initialize(_enemy: Enemy) -> void:
	states = []
	
	for c in get_children():
		if c is EnemyState:
			states.append(c)
	
	for s in states:
		s.enemy = _enemy
		s.state_machine = self
		s.init()
	
	if states.size() > 0:
		change_state(states[0])
		process_mode = Node.PROCESS_MODE_INHERIT
	pass

func change_state(new_state: EnemyState) -> void:
	if new_state == null || new_state == curr_state:
		return
	
	if curr_state:
		curr_state.exit()
	
	prev_state = curr_state
	curr_state = new_state
	
	curr_state.enter()
	pass
