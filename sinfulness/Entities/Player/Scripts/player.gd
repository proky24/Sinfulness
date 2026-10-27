class_name Player extends CharacterBody2D

var direction: Vector2 = Vector2.ZERO
var cardinal_dir: Vector2 = Vector2.DOWN
var speed: float = 75.0
## The player's stats live in GlobalPlayerManager, so they survive scene reloads.
var stats: PlayerStats:
	get:
		return GlobalPlayerManager.player_stats

@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_box: HitBox = $Interactions/HitBox
@onready var hurt_box: HurtBox = $Interactions/HurtBox


signal dir_changed( new_dir: Vector2 )

func _ready() -> void:
	GlobalPlayerManager.player = self
	state_machine.initialize(self)
	PlayerHud.player = self
	PlayerHud.bind_stats(stats)

	hurt_box.source_stats = stats
	hit_box.Damaged.connect(take_damage)
	hurt_box.hit_landed.connect(_on_hit_landed)
	stats.health_depleted.connect(_on_health_depleted)
	pass

func _process(_delta: float) -> void:
	direction = Vector2(
		Input.get_axis("left", "right"),
		Input.get_axis("forward", "backwards")
	).normalized()
	
	pass

func _physics_process(_delta: float) -> void:
	move_and_slide()
	pass

## Potion keys. The player is pausable, so they do nothing while the menu pauses the tree.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use_potion"):
		GlobalInventory.use_selected_potion()
	elif event.is_action_pressed("cycle_potion"):
		GlobalInventory.cycle_potion()
	pass

func set_dir() -> bool:
	var new_dir: Vector2 = cardinal_dir
	if direction == Vector2.ZERO:
		return false
	
	if direction.y == 0:
		new_dir = Vector2.LEFT if direction.x < 0 else Vector2.RIGHT
	elif direction.x == 0:
		new_dir = Vector2.UP if direction.y < 0 else Vector2.DOWN
	
	if new_dir == cardinal_dir:
		return false
	
	cardinal_dir = new_dir
	dir_changed.emit(cardinal_dir)
	if cardinal_dir == Vector2.LEFT:
		sprite.scale.x = -1
	elif cardinal_dir == Vector2.RIGHT:
		sprite.scale.x = 1
	return true

#func animation_direction() -> string:
	#if cardinal_dir == Vector2.DOWN:
		#return "down"
	#elif cardinal_dir == Vector2.UP:
		#return "up"
	#pass

func update_animation(state : String) -> void:
	animation_player.play(state)
	pass
	
func take_damage(hit: HitData) -> void:
	stats.take_damage(hit)
	pass

func _on_hit_landed(_target: HitBox, _hit: HitData) -> void:
	stats.restore_mana(stats.mana_per_hit)
	pass

func _on_health_depleted() -> void:
	_die.call_deferred()
	pass

## Placeholder death until the death state exists: reload the floor at the spawn with full
## health and mana. Orbs, points, corruption and potion buffs are kept.
func _die() -> void:
	GlobalInventory.notify_player_died()
	GlobalPlayerManager.reclaim_player()
	stats.restore_all()
	GlobalPlayerManager.player_spawned = false
	get_tree().reload_current_scene()
	pass
