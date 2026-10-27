extends CanvasLayer
## Health and mana orbs. Shows the player's stats (bind_stats), owns no numbers itself.
## Appears on attack, block and damage, then hides after dissapear_time.

@onready var timer: Timer = $Timer
@onready var control: Control = $Control
@onready var hp_bar: TextureProgressBar = $Control/Node/HPBar
@onready var mana_bar: TextureProgressBar = $Control/Node2/ManaBar

@export var dissapear_time: float = 4.0
## Seconds a bar takes to slide to a new value.
@export var bar_tween_time: float = 0.5

var player : Player = null

var sections = null

var _stats: PlayerStats = null
var _hp_tween: Tween
var _mana_tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer.wait_time = dissapear_time
	timer.timeout.connect(dissapear)
	sections = control.get_children()

	pass # Replace with function body.

## Follows [param stats]: health and mana bars, and appears when the player is damaged.
func bind_stats(stats: PlayerStats) -> void:
	if _stats != null:
		_stats.health_changed.disconnect(_on_health_changed)
		_stats.mana_changed.disconnect(_on_mana_changed)
		_stats.damaged.disconnect(_on_damaged)
	_stats = stats
	_stats.health_changed.connect(_on_health_changed)
	_stats.mana_changed.connect(_on_mana_changed)
	_stats.damaged.connect(_on_damaged)
	hp_bar.value = _to_percent(_stats.health, _stats.get_stat(Stats.Stat.MAX_HEALTH))
	mana_bar.value = _to_percent(_stats.mana, _stats.get_stat(Stats.Stat.MAX_MANA))
	pass

func appear() -> void:
	var tween = create_tween()
	for s in sections.size():
		for c in sections[s].get_children():
			tween.parallel().tween_property(c, "modulate:a", 1.0, 0.1)
	tween.tween_callback(func():
		for s in sections.size():
			for c in sections[s].get_children():
				c.visible = true
	)

func dissapear() -> void:
	var tween = create_tween()
	for s in sections.size():
		for c in sections[s].get_children():
			tween.parallel().tween_property(c, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		for s in sections.size():
			for c in sections[s].get_children():
				c.visible = false
	)
	pass

## Starts (or restarts) the hide timer.
func inactive() -> void:
	timer.start()
	pass

func _on_health_changed(health: float, max_health: float) -> void:
	if _hp_tween != null:
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_property(hp_bar, "value", _to_percent(health, max_health), bar_tween_time)
	pass

func _on_mana_changed(mana: float, max_mana: float) -> void:
	if _mana_tween != null:
		_mana_tween.kill()
	_mana_tween = create_tween()
	_mana_tween.tween_property(mana_bar, "value", _to_percent(mana, max_mana), bar_tween_time)
	pass

func _on_damaged(_amount: float, _is_crit: bool) -> void:
	appear()
	inactive()
	pass

func _to_percent(value: float, max_value: float) -> float:
	if max_value <= 0.0:
		return 0.0
	return value / max_value * 100.0
