extends CanvasLayer

@onready var timer: Timer = $Timer
@onready var control: Control = $Control

@export var dissapear_time: float = 4.0

var sections = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer.wait_time = dissapear_time
	timer.timeout.connect(dissapear)
	sections = control.get_children()
	
	timer.start()
	pass # Replace with function body.

func appear() -> void:
	var tween = create_tween()
	for s in sections.size():
		for c in sections[s].get_children():
			tween.parallel().tween_property(c, "modulate:a", 1.0, 0.2)
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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
