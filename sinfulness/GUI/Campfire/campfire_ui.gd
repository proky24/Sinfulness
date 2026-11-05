extends CanvasLayer
## Campfire level-up screen. Opens and closes with the same book animation and sounds as the
## pause menu; F (interact) or Esc (menu_back) closes it.
##
## States: OPENING (book opening, input ignored), OPEN and CLOSING (book closing, input ignored).
## The animations are built here; their keys and times are copied from PauseMenu.tscn.

enum ScreenState { OPENING, OPEN, CLOSING }

signal closing()

## Same value as MENU_SPEED in pause_menu.gd, so both books animate at the same speed.
const ANIMATION_SPEED: float = 1.3
const OPEN_ANIMATION: StringName = &"open_menu"
const CLOSE_ANIMATION: StringName = &"close_menu"
const RESET_ANIMATION: StringName = &"RESET"
const ANIMATION_LENGTH: float = 0.6
const RESET_LENGTH: float = 0.001
const BOOK_FRAMES: int = 8
const BOOK_FRAME_SIZE: Vector2 = Vector2(256, 240)
## Region key times of open_menu and close_menu in PauseMenu.tscn (close has one key at 0.40350556).
const OPEN_FRAME_TIMES: Array[float] = [0.0, 0.066666655, 0.13333334, 0.2, 0.26666668, 0.33333334, 0.39999998, 0.46666667]
const CLOSE_FRAME_TIMES: Array[float] = [0.0, 0.066666655, 0.13333334, 0.2, 0.26666668, 0.33333334, 0.40350556, 0.46666667]
const CONTENT_SHOW_TIME: float = 0.46666667
const OPEN_SOUND_TIME: float = 0.0
const OPEN_SOUND_START_OFFSET: float = 0.19981866
const CLOSE_SOUND_TIME: float = 0.26666668
const BOOK_REGION_PATH: NodePath = ^"Book:texture:region"
const CONTENT_VISIBLE_PATH: NodePath = ^"Content:visible"
## Relative to the AnimationPlayer's root node (Root), as in the pause menu.
const SOUND_PLAYER_PATH: NodePath = ^"../AnimationPlayer/AudioStreamPlayer2D"
const OPEN_SOUND: AudioStream = preload("res://Assets/UI SFX/PauseMenuSFX/book-opening.wav")
const CLOSE_SOUND: AudioStream = preload("res://Assets/UI SFX/PauseMenuSFX/book-closing.wav")

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var content: Control = $Root/Content
## Campfire stats summary labels and values.
## Orbs and orbs needed
@onready var orbs_value: Label = $Root/Content/LeftPage/LeftColumn/OrbsSummary/TrueOrbsRow/TrueOrbsValue
@onready var orbs_needed_value: Label = $Root/Content/LeftPage/LeftColumn/OrbsSummary/OrbsNeededRow/OrbsNeededValue

var _state: ScreenState = ScreenState.OPENING
var global_player_manager: GlobalPlayerManager = null
var _player_stats: PlayerStats = null
var confirmed: bool = false

func _ready() -> void:
	_add_animation_library()
	animation_player.animation_finished.connect(_on_animation_finished)
	content.visible = false
	_state = ScreenState.OPENING
	animation_player.speed_scale = ANIMATION_SPEED
	animation_player.play(OPEN_ANIMATION)

	global_player_manager = get_node("/root/GlobalPlayerManager")
	_player_stats = global_player_manager.player_stats
	_player_stats.orbs_changed.connect(_on_orbs_changed)
	_player_stats.level_up_cost_changed.connect(_on_orbs_needed_changed)
	

func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed("interact") or event.is_action_pressed("menu_back") or event.is_action_pressed("pause_menu")):
		return
	get_viewport().set_input_as_handled()
	if _state != ScreenState.OPEN:
		return
	_state = ScreenState.CLOSING
	content.visible = false
	animation_player.play(CLOSE_ANIMATION)
	closing.emit()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == OPEN_ANIMATION and _state == ScreenState.OPENING:
		_state = ScreenState.OPEN
		load_orbs()
	elif animation_name == CLOSE_ANIMATION and _state == ScreenState.CLOSING:
		PauseMenu.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = false
		queue_free()

func load_orbs() -> void:
	if _player_stats == null:
		return
	orbs_value.text = str(_player_stats.orbs)
	orbs_needed_value.text = str(_player_stats.get_level_up_cost())

func _on_orbs_changed(orbs: int) -> void:
	orbs_value.text = str(orbs)

func _on_orbs_needed_changed(new_cost: int) -> void:
	orbs_needed_value.text = str(new_cost)

# -- Animations ----------------------------------------------------------------


func _add_animation_library() -> void:
	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation(RESET_ANIMATION, _create_reset_animation())
	library.add_animation(OPEN_ANIMATION, _create_open_animation())
	library.add_animation(CLOSE_ANIMATION, _create_close_animation())
	animation_player.add_animation_library(&"", library)


func _create_reset_animation() -> Animation:
	var animation: Animation = Animation.new()
	animation.length = RESET_LENGTH
	var region_track: int = _add_discrete_track(animation, BOOK_REGION_PATH)
	animation.track_insert_key(region_track, 0.0, _frame_region(0))
	var visible_track: int = _add_discrete_track(animation, CONTENT_VISIBLE_PATH)
	animation.track_insert_key(visible_track, 0.0, false)
	return animation


func _create_open_animation() -> Animation:
	var animation: Animation = Animation.new()
	animation.length = ANIMATION_LENGTH
	_add_region_track(animation, OPEN_FRAME_TIMES, false)
	var visible_track: int = _add_discrete_track(animation, CONTENT_VISIBLE_PATH)
	animation.track_insert_key(visible_track, 0.0, false)
	animation.track_insert_key(visible_track, CONTENT_SHOW_TIME, true)
	_add_sound_track(animation, OPEN_SOUND_TIME, OPEN_SOUND, OPEN_SOUND_START_OFFSET)
	return animation


func _create_close_animation() -> Animation:
	var animation: Animation = Animation.new()
	animation.length = ANIMATION_LENGTH
	_add_region_track(animation, CLOSE_FRAME_TIMES, true)
	var visible_track: int = _add_discrete_track(animation, CONTENT_VISIBLE_PATH)
	animation.track_insert_key(visible_track, 0.0, false)
	_add_sound_track(animation, CLOSE_SOUND_TIME, CLOSE_SOUND, 0.0)
	return animation


## Steps the Book's own AtlasTexture through the eight Spellbook_Opening frames; reversed for closing.
func _add_region_track(animation: Animation, times: Array[float], reversed: bool) -> void:
	var track: int = _add_discrete_track(animation, BOOK_REGION_PATH)
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
	for key: int in BOOK_FRAMES:
		var frame: int = BOOK_FRAMES - 1 - key if reversed else key
		animation.track_insert_key(track, times[key], _frame_region(frame))


func _add_discrete_track(animation: Animation, path: NodePath) -> int:
	var track: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, path)
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	return track


func _add_sound_track(animation: Animation, time: float, stream: AudioStream, start_offset: float) -> void:
	var track: int = animation.add_track(Animation.TYPE_AUDIO)
	animation.track_set_path(track, SOUND_PLAYER_PATH)
	animation.audio_track_insert_key(track, time, stream, start_offset)


func _frame_region(frame: int) -> Rect2:
	return Rect2(Vector2(frame * BOOK_FRAME_SIZE.x, 0), BOOK_FRAME_SIZE)
