class_name FloorBounds extends Node2D

# Root script of a handmade floor. Sends the floor's pixel bounds to the camera.
#
# Draw order: every TileMapLayer sits at (0, 0). Walls are split by how they
# relate to the player (z_index 0, y-sorted by its position):
# - Water, Floor, FloorDecoration and FloorShade use z_index -1 (always under).
# - WallFaces and WallFacesDecoration hold the brick fronts of walls north of the
#   floor, arches and niches. They use z_index 0 with y-sort and y_sort_origin 6,
#   so in a room the player is in front of the bricks, and once the player walks
#   into a door or niche the bricks beside it cover the sword and body.
# - WallTops uses z_index 1 (always over): wall tops, side walls, walls south of
#   the floor and the void. A sword pushed into a side wall disappears behind it.
# - ArchTops uses z_index 1 with collision off: the wall top above each door, so
#   the player walks under it.
# Side walls are never y-sorted: with per-cell sorting the wall cell beside the
# player flipped between front and back every 8 px.

@export var bounds_layer: TileMapLayer


func _ready() -> void:
	GlobalLevelManager.change_tilemap_bounds(get_floor_bounds())
	pass


func get_floor_bounds() -> Array[Vector2]:
	var bounds: Array[Vector2] = []
	if bounds_layer == null or bounds_layer.tile_set == null:
		push_warning("FloorBounds: bounds_layer is not set")
		return bounds
	var used_rect: Rect2i = bounds_layer.get_used_rect()
	if not used_rect.has_area():
		push_warning("FloorBounds: bounds_layer has no tiles")
		return bounds
	var tile_size: Vector2 = Vector2(bounds_layer.tile_set.tile_size)
	bounds.append(bounds_layer.position + Vector2(used_rect.position) * tile_size)
	bounds.append(bounds_layer.position + Vector2(used_rect.end) * tile_size)
	return bounds
