class_name EnemyStateChase extends EnemyState

@onready var attack: EnemyStateAttack = $"../Attack"

@export var chase_speed: float = 20
@export var turn_rate: float = 0.25
@export var anim_name: String = "wander"

@export_group("AI")
@export var chasing_time: int = 5
@export var next_state: EnemyState
@export var vision_area: EnemyVision
@export var attack_range: AttackDetectArea

var can_see_player: bool = false
var player_in_range: bool = false

var timer: float = 0
var _direction: Vector2

func init() -> void:
    if vision_area:
        vision_area.player_entered.connect(_on_player_entered)
        vision_area.player_exited.connect(_on_player_exited)

        attack_range.player_in_attack_range.connect(_on_attack_range)
        attack_range.player_not_in_attack_range.connect(_on_not_attack_range)
    pass

func enter() -> void:
    timer = chasing_time
    enemy.update_animation(anim_name)
    pass

func process(delta: float) -> EnemyState:
    if player_in_range == true:
        return attack

    var new_dir: Vector2 = enemy.global_position.direction_to(GlobalPlayerManager.player.global_position)

    _direction = _direction.lerp(new_dir, turn_rate)

    enemy.velocity = _direction * chase_speed
    enemy.set_direction(_direction)

    if can_see_player == false:
        timer -= delta
        if timer <= 0:
            return next_state
    else:
        timer = chasing_time
    return null

func _on_player_entered() -> void:
    can_see_player = true
    if state_machine.curr_state is EnemyStateStun:
        return
    state_machine.change_state(self)
    pass

func _on_player_exited() -> void:
    can_see_player = false
    pass

func _on_attack_range() -> void:
    player_in_range = true
    pass

func _on_not_attack_range() -> void:
    player_in_range = false
    pass