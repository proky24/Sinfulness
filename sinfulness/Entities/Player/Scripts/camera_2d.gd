class_name PlayerCamera extends Camera2D

# Player camera: a small look-ahead while walking, zoom and lean while attacking.
#
# Targets: the camera sets its own targets every frame. It reads player.direction
# (8-way look-ahead) and whether the player is in the attack state. The attack
# state only calls start_attack(dir) on every hit and end_attack() when the combo
# is over (AttackComboTimer.timeout). Calling start_attack() again during a combo
# only updates the lean direction, nothing stacks.
#
# Smoothing: offset and zoom follow their targets with frame-rate independent
# exponential smoothing, value = value.lerp(target, 1.0 - exp(-sharpness * delta)).
# No tweens. Leaning out uses look_ahead_sharpness, coming back return_sharpness.
# When input stops, the offset holds for return_delay before it re-centres, so
# taps and short stops don't wobble the view.
#
# The offset is kept in screen space (_screen_offset, px at base_zoom) and applied
# as offset = _screen_offset * base_zoom / zoom. So the player stays where the
# offset puts them on screen while the zoom changes, with no drift. The offset is
# clamped to the camera limits (set by GlobalLevelManager), because Camera2D
# itself lets the offset go past them. limit_smoothed is off: it only works with
# position smoothing, which this camera doesn't use.
#
# Attack: while the player is in the attack state, or the combo is still active
# and the player stands still, the offset target is a small lean toward the
# attack direction. The zoom stays at attack_zoom until the combo is over, also if
# the player walks off meanwhile; walking brings the look-ahead back right away.
#
# Interpolation: physics interpolation is on (project setting). The player moves
# at 60 ticks and Godot draws it interpolated, so the camera must move on the same
# ticks: process_callback is Physics (Godot forces it anyway and warns if it's
# Idle) and offset and zoom are smoothed in _physics_process. Godot then
# interpolates the camera too, so offset and zoom change evenly on any monitor.
# After a teleport (spawn, level change) call reset_physics_interpolation() on
# the player, or it slides from the old position for one tick.
#
# All exports are read every tick, so they can be tuned live in the remote inspector.

@export_group("Tuning")
@export var base_zoom: float = 1.8
@export var attack_zoom: float = 2.0
## Look-ahead in px at base_zoom.
@export var look_ahead_distance: float = 24.0
## Lean toward the attack direction in px at base_zoom.
@export var attack_lean_distance: float = 12.0
@export var look_ahead_sharpness: float = 3.5
@export var return_sharpness: float = 5.5
@export var zoom_in_sharpness: float = 12.0
@export var zoom_out_sharpness: float = 4.5
## Seconds the offset holds after input stops, before it re-centres.
@export var return_delay: float = 0.25

@onready var player: Player = get_parent() as Player

var _screen_offset: Vector2 = Vector2.ZERO
var _zoom_value: float = 1.0
var _attack_dir: Vector2 = Vector2.ZERO
var _combo_active: bool = false
var _idle_time: float = 0.0


func _ready() -> void:
	GlobalLevelManager.tilemap_bounds_changed.connect(update_limits)
	update_limits(GlobalLevelManager.curr_tilemap_bounds)
	_zoom_value = base_zoom
	zoom = Vector2(_zoom_value, _zoom_value)
	pass


func _physics_process(delta: float) -> void:
	_update_zoom(delta)
	_update_offset(delta)
	pass


func update_limits(bounds: Array[Vector2]) -> void:
	if bounds.size() < 2:
		return
	limit_left = int(bounds[0].x)
	limit_top = int(bounds[0].y)
	limit_right = int(bounds[1].x)
	limit_bottom = int(bounds[1].y)
	pass


## Called by the attack state on every hit of a combo.
func start_attack(dir: Vector2) -> void:
	_combo_active = true
	if dir != Vector2.ZERO:
		_attack_dir = dir
	pass


## Called when the combo is over (AttackComboTimer.timeout).
func end_attack() -> void:
	_combo_active = false
	pass


func _update_zoom(delta: float) -> void:
	var target: float = attack_zoom if _combo_active else base_zoom
	var sharpness: float = zoom_in_sharpness if target > _zoom_value else zoom_out_sharpness
	_zoom_value = lerpf(_zoom_value, target, _smooth_weight(sharpness, delta))
	zoom = Vector2(_zoom_value, _zoom_value)
	pass


func _update_offset(delta: float) -> void:
	if player.direction == Vector2.ZERO:
		_idle_time += delta
	else:
		_idle_time = 0.0

	var target: Vector2
	if _is_leaning():
		target = _attack_dir * attack_lean_distance
	elif player.direction != Vector2.ZERO:
		target = player.direction * look_ahead_distance
	elif _idle_time < return_delay:
		target = _screen_offset
	else:
		target = Vector2.ZERO

	var sharpness: float = look_ahead_sharpness if target.length() >= _screen_offset.length() else return_sharpness
	_screen_offset = _screen_offset.lerp(target, _smooth_weight(sharpness, delta))
	offset = _clamp_to_limits(_screen_offset * base_zoom / _zoom_value)
	_screen_offset = offset * _zoom_value / base_zoom
	pass


# Camera2D applies the offset after the limits, so without this the look-ahead
# shows the void past the map edge. Clamping the stored offset too means nothing
# builds up unseen at a wall, so walking back out of a corner reacts at once.
func _clamp_to_limits(value: Vector2) -> Vector2:
	var half_view: Vector2 = get_viewport_rect().size / (2.0 * _zoom_value)
	var low: Vector2 = Vector2(limit_left, limit_top) + half_view
	var high: Vector2 = Vector2(limit_right, limit_bottom) - half_view
	if low.x > high.x or low.y > high.y:
		return value
	var centre: Vector2 = global_position.clamp(low, high)
	return value.clamp(low - centre, high - centre)


func _is_leaning() -> bool:
	if player.state_machine.curr_state is StateAttack:
		return true
	return _combo_active and player.direction == Vector2.ZERO


func _smooth_weight(sharpness: float, delta: float) -> float:
	return 1.0 - exp(-sharpness * delta)
