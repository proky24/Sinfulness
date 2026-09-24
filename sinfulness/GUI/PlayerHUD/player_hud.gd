extends CanvasLayer

@onready var timer: Timer = $Timer
@onready var control: Control = $Control
@onready var hp_bar: TextureProgressBar = $Control/Node/HPBar
@onready var mana_bar: TextureProgressBar = $Control/Node2/ManaBar

@export var dissapear_time: float = 4.0

var player : Player = null

var sections = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer.wait_time = dissapear_time
	timer.timeout.connect(dissapear)
	sections = control.get_children()

	
	#timer.start()
	pass # Replace with function body.

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
	timer.timeout.disconnect(dissapear)
	pass

func inactive() -> void:
	timer.start()
	timer.timeout.connect(dissapear)
	pass

func player_damaged() -> void:
	player.hit_box.Damaged.connect(update_hp)
	pass

func update_hp(damage: int) -> void:
	var tween = create_tween()
	var new_hp = hp_bar.value - damage
	tween.tween_property(hp_bar, "value", new_hp, 0.5)
	
	if new_hp <= 10:
		print("you died")
		get_tree().reload_current_scene()
	pass
