class_name BookTab extends TextureRect
## A bookmark tab of the pause-menu book. Focus it with the keyboard or mouse, confirm to open its page.

signal tab_chosen(tab: BookTab)

@export var selected_texture: Texture2D
## Page shown for this tab. Leave empty for tabs that have no content yet.
@export var page_scene: PackedScene
@export var tab_page: int = 0

var _normal_texture: Texture2D
var _is_active: bool = false


func _ready() -> void:
	_normal_texture = texture
	focus_entered.connect(_refresh_texture)
	focus_exited.connect(_refresh_texture)
	mouse_entered.connect(_on_mouse_entered)
	set_interactive(false)


func set_interactive(enabled: bool) -> void:
	focus_mode = FOCUS_ALL if enabled else FOCUS_NONE
	mouse_filter = MOUSE_FILTER_STOP if enabled else MOUSE_FILTER_IGNORE


## Marks this tab as the one whose page is open, so it stays highlighted.
func set_active(active: bool) -> void:
	_is_active = active
	_refresh_texture()


func _gui_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	var clicked: bool = mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if clicked or event.is_action_pressed("ui_accept"):
		accept_event()
		tab_chosen.emit(self)


func _refresh_texture() -> void:
	texture = selected_texture if (has_focus() or _is_active) and selected_texture != null else _normal_texture


func _on_mouse_entered() -> void:
	if focus_mode != FOCUS_NONE:
		grab_focus()
