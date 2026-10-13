extends CanvasLayer
## The pause-menu book. Tab opens and closes it, the tabs choose a page, a page turn plays,
## and the page is filled from GlobalInventory.
##
## States: TAB_SELECT (moving between tabs), PAGE_TURN (animation, input ignored) and
## CONTENT (moving inside a page). OPENING covers the book-opening animation.

enum MenuState { CLOSED, OPENING, TAB_SELECT, PAGE_TURN, CONTENT }

const MENU_SPEED: float = 1.3
const OPEN_ANIMATION: StringName = &"open_menu"
const PAGE_TURN_ANIMATION: StringName = &"page_turn"
const PAGE_TURN_FRAMES: int = 8
const PAGE_TURN_FRAME_TIME: float = 0.0667
const PAGE_TURN_FRAME_SIZE: Vector2 = Vector2(256, 176)
## Movement keys forwarded to UI navigation while the menu is open (WASD).
const MOVE_TO_UI_ACTIONS: Dictionary[StringName, StringName] = {
    &"forward": &"ui_up",
    &"backwards": &"ui_down",
    &"left": &"ui_left",
    &"right": &"ui_right",
}

@onready var animation_player: AnimationPlayer = $AnimationPlayer
## Overlay with Spellbook_NextPage (eight 256x176 frames); its AtlasTexture margin lines the
## frames up with the opened book, which is 240 px tall.
@onready var page_turn: TextureRect = $Control/PageTurn
@onready var tabs_root: Control = $Control/Tabs
@onready var content: Control = $Control/Tabs/ContentofTab

var is_paused: bool = false

var _state: MenuState = MenuState.CLOSED
var _tabs: Array[BookTab] = []
var _active_tab: BookTab = null
var _page: BookPage = null
var _last_focus: Control = null


func _ready() -> void:
    for child: Node in tabs_root.get_children():
        if child is BookTab:
            var tab: BookTab = child
            tab.tab_chosen.connect(_on_tab_chosen)
            _tabs.append(tab)
    _add_page_turn_animation()
    animation_player.animation_finished.connect(_on_animation_finished)
    get_viewport().gui_focus_changed.connect(_on_focus_changed)
    hide_pause_menu()


func hide_pause_menu() -> void:
    is_paused = false
    get_tree().paused = false
    visible = false
    _state = MenuState.CLOSED
    _clear_page()
    _set_active_tab(null)
    _set_tabs_interactive(false)
    animation_player.stop(true)
    page_turn.visible = false
    _last_focus = null


func show_pause_menu() -> void:
    is_paused = true
    get_tree().paused = true
    visible = true
    _state = MenuState.OPENING
    _active_tab = _tabs[0]
    animation_player.speed_scale = MENU_SPEED
    animation_player.play(OPEN_ANIMATION)

    


func _input(event: InputEvent) -> void:
    if event.is_action_pressed("pause_menu"):
        get_viewport().set_input_as_handled()
        if is_paused:
            hide_pause_menu()
        else:
            show_pause_menu()
        return
    if not is_paused:
        return
    if event.is_action_pressed("menu_back"):
        get_viewport().set_input_as_handled()
        _go_back()
        return
    if _state == MenuState.OPENING or _state == MenuState.PAGE_TURN:
        if not event is InputEventMouseMotion:
            get_viewport().set_input_as_handled()
        return
    _forward_movement_keys(event)
    if event is InputEventMouseButton and event.is_pressed():
        _restore_focus.call_deferred()


# -- States --------------------------------------------------------------------


func _enter_tab_select(focus_tab: BookTab) -> void:
    _state = MenuState.TAB_SELECT
    if _page != null:
        _page.set_interactive(false)
    _set_tabs_interactive(true)
    focus_tab.grab_focus()


func _on_tab_chosen(tab: BookTab) -> void:
    if _state != MenuState.TAB_SELECT:
        return
    _state = MenuState.PAGE_TURN
    _set_active_tab(tab)
    _clear_page()
    _set_tabs_interactive(false)
    animation_player.speed_scale = MENU_SPEED
    animation_player.play(PAGE_TURN_ANIMATION)


func _show_page() -> void:
    page_turn.visible = false
    if _active_tab.page_scene != null:
        _page = _active_tab.page_scene.instantiate() as BookPage
        content.add_child(_page)
        _page.build()
        _page.set_interactive(true)
    var first_focus: Control = _page.get_first_focus() if _page != null else null
    if first_focus == null:
        # Nothing to select on this page (empty tab or no items): stay on the tab list.
        _enter_tab_select(_active_tab)
        return
    _state = MenuState.CONTENT
    first_focus.grab_focus()


func _go_back() -> void:
    if _state != MenuState.CONTENT:
        return
    if _page != null and _page.go_back():
        return
    _enter_tab_select(_active_tab)


func _on_animation_finished(animation_name: StringName) -> void:
    if animation_name == OPEN_ANIMATION and _state == MenuState.OPENING:
        _enter_tab_select(_tabs[0])
        _show_page()
    elif animation_name == PAGE_TURN_ANIMATION and _state == MenuState.PAGE_TURN:
        _show_page()


# -- Helpers -------------------------------------------------------------------


func _set_tabs_interactive(enabled: bool) -> void:
    for tab: BookTab in _tabs:
        tab.set_interactive(enabled)


func _set_active_tab(tab: BookTab) -> void:
    if _active_tab != null:
        _active_tab.set_active(false)
    _active_tab = tab
    if _active_tab != null:
        _active_tab.set_active(true)


func _clear_page() -> void:
    if _page != null:
        content.remove_child(_page)
        _page.queue_free()
        _page = null


## Turns W/A/S/D into ui_up/ui_left/ui_down/ui_right so Godot's focus navigation handles them.
func _forward_movement_keys(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    for action: StringName in MOVE_TO_UI_ACTIONS:
        var ui_action: StringName = MOVE_TO_UI_ACTIONS[action]
        if event.is_action(action) and not event.is_action(ui_action):
            get_viewport().set_input_as_handled()
            if event.is_pressed():
                var ui_event: InputEventAction = InputEventAction.new()
                ui_event.action = ui_action
                ui_event.pressed = true
                Input.parse_input_event(ui_event)
            return


func _on_focus_changed(control: Control) -> void:
    if is_paused and is_ancestor_of(control):
        _last_focus = control


## Clicking empty space can drop focus; put it back so keyboard navigation keeps working.
func _restore_focus() -> void:
    if get_viewport().gui_get_focus_owner() != null:
        return
    if _state == MenuState.CONTENT or _state == MenuState.TAB_SELECT:
        if is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree() and _last_focus.focus_mode != Control.FOCUS_NONE:
            _last_focus.grab_focus()
        elif _state == MenuState.CONTENT and _page != null and _page.get_first_focus() != null:
            _page.get_first_focus().grab_focus()
        else:
            (_active_tab if _active_tab != null else _tabs[0]).grab_focus()


## Builds the page-turn animation: shows the PageTurn overlay and steps its AtlasTexture
## through the eight Spellbook_NextPage frames. The Book texture itself is never touched.
func _add_page_turn_animation() -> void:
    var animation: Animation = Animation.new()
    animation.length = PAGE_TURN_FRAMES * PAGE_TURN_FRAME_TIME
    var visible_track: int = animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(visible_track, "PageTurn:visible")
    animation.value_track_set_update_mode(visible_track, Animation.UPDATE_DISCRETE)
    animation.track_insert_key(visible_track, 0.0, true)
    var region_track: int = animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(region_track, "PageTurn:texture:region")
    animation.value_track_set_update_mode(region_track, Animation.UPDATE_DISCRETE)
    for frame: int in PAGE_TURN_FRAMES:
        var region: Rect2 = Rect2(Vector2(frame * PAGE_TURN_FRAME_SIZE.x, 0), PAGE_TURN_FRAME_SIZE)
        animation.track_insert_key(region_track, frame * PAGE_TURN_FRAME_TIME, region)
    animation_player.get_animation_library(&"").add_animation(PAGE_TURN_ANIMATION, animation)
