@tool
class_name Prop extends Node2D
## A static decoration (crate, barrel, vase, cluster, shield, gold pile) cut from Objects.png.
##
## Origin rule: the node origin is the object's foot, the bottom edge of the lowest fully
## opaque pixel row of the texture (the baked, semi-transparent shadow hangs below it),
## horizontally the centre of the opaque pixels. The sprite is drawn upward from there
## (centered = false, offset computed from the texture), so y-sort compares the player's
## origin with the prop's base. lift raises the sprite and hit box, not the origin or
## footprint (wall-hung shields).
## Collision: a thin footprint ending at the base, opaque width - 3 px wide and
## opaque height / 4 (5 to 8 px) tall, or collision_size when it is not zero. The shapes
## are created in code, so every instance has its own.

const _FOOTPRINT_INSET: float = 3.0
const _FOOTPRINT_MIN_WIDTH: float = 4.0
const _FOOTPRINT_MIN_HEIGHT: float = 5.0
const _FOOTPRINT_MAX_HEIGHT: float = 8.0

## Opaque pixel bounds per texture, shared by all props.
static var _opaque_cache: Dictionary = {}

@export var texture: Texture2D:
	set(value):
		texture = value
		update_prop()
## Footprint size in px. Vector2.ZERO computes it from the texture.
@export var collision_size: Vector2 = Vector2.ZERO:
	set(value):
		collision_size = value
		update_prop()
## Blocks the player with its footprint.
@export var solid: bool = true:
	set(value):
		solid = value
		update_prop()
## Registers hits on its HitBox and is freed when damaged.
@export var breakable: bool = false:
	set(value):
		breakable = value
		update_prop()
## Floor decal (gold piles): always drawn under the player, never solid.
@export var flat: bool = false:
	set(value):
		flat = value
		update_prop()
## Pixels the sprite is drawn above the origin (wall-hung props).
@export var lift: int = 0:
	set(value):
		lift = value
		update_prop()


@onready var sprite: Sprite2D = $Sprite2D
@onready var footprint: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var hit_box: HitBox = $HitBox
@onready var hit_shape: CollisionShape2D = $HitBox/CollisionShape2D


func _ready() -> void:
	footprint.shape = RectangleShape2D.new()
	hit_shape.shape = RectangleShape2D.new()
	update_prop()


## Re-applies the texture and switches to the sprite and collision shapes.
func update_prop() -> void:
	if not is_node_ready():
		return
	var opaque: Rect2i = _get_opaque_rect(texture)
	_update_sprite(opaque)
	_update_footprint(opaque)
	_update_hit_box(opaque)


func take_damage(_hit: HitData) -> void:
	queue_free()


func _update_sprite(opaque: Rect2i) -> void:
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = Vector2(-_get_centre_x(opaque), -opaque.end.y - lift)
	sprite.z_index = -1 if flat else 0


func _update_footprint(opaque: Rect2i) -> void:
	var size: Vector2 = collision_size
	if size == Vector2.ZERO:
		size = Vector2(
			maxf(opaque.size.x - _FOOTPRINT_INSET, _FOOTPRINT_MIN_WIDTH),
			clampf(roundf(opaque.size.y / 4.0), _FOOTPRINT_MIN_HEIGHT, _FOOTPRINT_MAX_HEIGHT))
	(footprint.shape as RectangleShape2D).size = size
	footprint.position = Vector2(opaque.position.x + opaque.size.x / 2.0 - _get_centre_x(opaque), -size.y / 2.0)
	footprint.set_deferred("disabled", texture == null or flat or not solid)


func _update_hit_box(opaque: Rect2i) -> void:
	(hit_shape.shape as RectangleShape2D).size = Vector2(opaque.size)
	hit_shape.position = Vector2(opaque.position.x + opaque.size.x / 2.0 - _get_centre_x(opaque), -opaque.size.y / 2.0 - lift)
	hit_shape.set_deferred("disabled", texture == null or not breakable)
	if Engine.is_editor_hint():
		return
	var connected: bool = hit_box.Damaged.is_connected(take_damage)
	if breakable and not connected:
		hit_box.Damaged.connect(take_damage)
	elif not breakable and connected:
		hit_box.Damaged.disconnect(take_damage)


## Whole-pixel x of the opaque centre, used as the origin's column in the texture.
func _get_centre_x(opaque: Rect2i) -> int:
	return opaque.position.x + floori(opaque.size.x / 2.0)


## Bounds of the fully opaque pixels (alpha 1), i.e. the object without its baked shadow.
func _get_opaque_rect(tex: Texture2D) -> Rect2i:
	if tex == null:
		return Rect2i()
	if _opaque_cache.has(tex):
		return _opaque_cache[tex]
	var full := Rect2i(Vector2i.ZERO, Vector2i(tex.get_size()))
	var image: Image = tex.get_image()
	if image == null or image.is_empty():
		return full
	if image.is_compressed():
		image.decompress()
	var min_p := Vector2i(image.get_width(), image.get_height())
	var max_p := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a8 == 255:
				min_p = min_p.min(Vector2i(x, y))
				max_p = max_p.max(Vector2i(x, y))
	var opaque: Rect2i = full if max_p.x < 0 else Rect2i(min_p, max_p - min_p + Vector2i.ONE)
	_opaque_cache[tex] = opaque
	return opaque
