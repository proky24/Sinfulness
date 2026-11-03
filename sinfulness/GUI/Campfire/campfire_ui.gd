extends CanvasLayer

var tween: Tween

func _ready() -> void:
	visible = false
	for c in get_children():
		c.modulate.a = 0.0
	appear()
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		queue_free()
		PauseMenu.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = false

func appear() -> void:
	tween = create_tween()
	visible = true
	for c in get_children():
		tween.parallel().tween_property(c, "modulate:a", 1.0, 0.4)
	for c in get_children():
		tween.tween_callback(_show_child.bind(c))

func _show_child(child: CanvasItem) -> void:
	child.modulate.a = 1.0
	get_children()[0].modulate.a = 0.95
