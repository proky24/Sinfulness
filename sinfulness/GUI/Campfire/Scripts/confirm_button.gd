class_name ConfirmButton extends Button

@export var campfire_ui: CanvasLayer

func _ready() -> void:
	self.pressed.connect(_on_pressed)
	pass

func _on_pressed() -> void:
	campfire_ui.confirmed = true
	campfire_ui.close()
	pass