class_name StateWalk extends State

@onready var idle: StateIdle = $"../Idle"
@onready var walk: StateWalk = $"."
@onready var attack: Node = $"../Attack"
@onready var block: StateBlock = $"../Block"
@onready var ability: StateAbility = $"../Ability"

@export var speed: int = 100

func enter() -> void:
	player.update_animation("walk")
	pass

func exit() -> void:
	pass

func init() -> void:
	pass

func process(_delta: float) -> State:
	if player.direction == Vector2.ZERO:
		return idle
	
	player.set_dir()
	player.velocity = player.direction * speed
	return null

func physics_process(_delta: float) -> State:
	return null

func _handle_input(event: InputEvent) -> State:
	if event.is_action_pressed("attack"):
		return attack
	elif event.is_action_pressed("block"):
		return block
	elif event.is_action_pressed("switch_stance"):
		if ability.stance == ability.Stances.PURRIFIED:
			ability.stance = ability.Stances.CORRUPTED
		else:
			ability.stance = ability.Stances.PURRIFIED
		return null
	elif event.is_action_pressed("first_ability") or event.is_action_pressed("second_ability") or event.is_action_pressed("third_ability"):
		ability.event = event.as_text()
		for c in ability.children:
			if c.slot == ability.event and c.stance == ability.stance:
				ability.ability_to_use = c
		if ability.can_use(ability.ability_to_use):
			return ability
		return null
	elif event.is_action_pressed("interact"):
		GlobalPlayerManager.interact_pressed.emit()
	return walk
