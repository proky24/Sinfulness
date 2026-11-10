class_name StateIdle extends State

@onready var idle: StateIdle = $"."
@onready var walk: StateWalk = $"../Walk"
@onready var attack: StateAttack = $"../Attack"
@onready var block: StateBlock = $"../Block"
@onready var ability: StateAbility = $"../Ability"

func enter() -> void:
	player.update_animation("idle")
	pass

func exit() -> void:
	pass

func init() -> void:
	pass

func process(_delta: float) -> State:
	if player.direction != Vector2.ZERO:
		return walk
	
	player.velocity = Vector2.ZERO
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
		return ability
	elif event.is_action_pressed("take_dmg"):
		player.hit_box.take_damage(HitData.new(15.0))
		GlobalPlayerManager.player_stats.spend_mana(30.0)
	elif event.is_action_pressed("interact"):
		GlobalPlayerManager.interact_pressed.emit()
	return idle
