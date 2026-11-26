class_name EnemyStateAttack extends EnemyState

@onready var idle: EnemyStateIdle = $"../Idle"
@onready var wander: EnemyStateWander = $"../Wander"
@onready var aniamtion_player: AnimationPlayer = $"../../AnimationPlayer"

@onready var attack_timer: Timer = $AttackTimer
@onready var attack_combo_timer: Timer = $AttackComboTimer
@onready var hurt_box: HurtBox = $"../../HurtBox"

@export var attack_detect_area: Area2D
@export var decelarate_speed: float = 10.0
@export var combo_multipliers: Array[float] = [1.1, 1.15, 1.2]
var attack_combo: int:
    set(value):
        attack_combo = clampi(value, 1, 3)

var attacking: bool = false
var player_in_range: bool = false

func init() -> void:
    attack_detect_area.player_in_attack_range.connect(_on_player_in_range)
    attack_detect_area.player_not_in_attack_range.connect(_on_player_not_in_range)
    pass

func _ready() -> void:
    super()
    pass

func enter() -> void:
    if player_in_range == false:
        return
    
    if attack_timer.is_stopped() == false:
        return

    attack_timer.start()

    if attack_combo_timer.time_left > 0 and attack_combo < 3:
        attack_combo += 1
        attack_combo_timer.stop()
    else:
        attack_combo = 0
    attack_combo_timer.start()
    attack_combo_timer.timeout.connect(_on_attack_combo_timer_end)
    
    enemy.velocity = Vector2.ZERO

    attacking = true

    enemy.update_animation("attack_" + str(attack_combo))
    aniamtion_player.animation_finished.connect(_disable_attacking)

    pass

func process(_delta: float) -> EnemyState:
    enemy.velocity -= enemy.direction * decelarate_speed * _delta

    if attacking == false:
        if enemy.direction == Vector2.ZERO:
            return idle
        else:
            return wander
    return null

func _on_attack_combo_timer_end() -> void:
    attack_combo = 0
    attack_combo_timer.timeout.disconnect(_on_attack_combo_timer_end)
    pass

func _disable_attacking() -> void:
    attacking = false
    pass

func _on_player_in_range() -> void:
    player_in_range = true
    if state_machine.curr_state is EnemyStateStun:
        return
    state_machine.change_state(self)
    pass

func _on_player_not_in_range() -> void:
    player_in_range = false
    pass