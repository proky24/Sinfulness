class_name StateIdle extends State

@onready var idle: StateIdle = $"."
@onready var walk: StateWalk = $"../Walk"
@onready var attack: StateAttack = $"../Attack"
@onready var block: StateBlock = $"../Block"
@onready var taste_your_own_hate: Sprite2D = $"../../AbilitiesSpriteHolder/Corrupted/TasteYourOwnHate"

func enter() -> void:
	player.update_animation("idle")
	pass

func exit() -> void:
	pass

func init() -> void:
	pass

func process(delta: float) -> State:
	if player.direction != Vector2.ZERO:
		return walk
	
	player.velocity = Vector2.ZERO
	return null

func physics_process(delta: float) -> State:
	return null

func _handle_input(event: InputEvent) -> State:
	if event.is_action_pressed("attack"):
		return attack
	elif event.is_action_pressed("block"):
		return block
	elif event.is_action_pressed("take_dmg"):
		player.hit_box.take_damage(15)
	return idle

#func shoot_radial(origin: Vector2, count: int) -> void:
			#for i in count:
				#var angle := (TAU / count) * i
				#var dir := Vector2.RIGHT.rotated(angle)
				#var arrow := player.Sunrise.instantiate()
				#arrow.direction = dir
				#arrow.position = origin
				#get_tree().current_scene.add_child(arrow)
