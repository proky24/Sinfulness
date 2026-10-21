extends TestCase
## PRD 7: torch light is blocked by walls and doorway openings (FloorWallTile occlusion layer).

const FLOOR_WALL_TILE_PATH: String = "res://Floors/TilesSetsNodes/FloorWallTile.tscn"
const TORCH_PATH: String = "res://Entities/GeneralNodes/Props/Torches/TorchSmall.tscn"
const ROUND_TRIP_PATH: String = "user://test_torch_light_tileset.tres"

const ARCH_TILES: Array[Vector2i] = [Vector2i(4, 24), Vector2i(5, 24), Vector2i(4, 25), Vector2i(5, 25)]
const BRICK_FRONT_TILES: Array[Vector2i] = [Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5)]
const TORCH_COLOR: Color = Color(0.98000807, 0.9717125, 0.3432214, 1)
const TORCH_ENERGY: float = 3.5


func test_tileset_has_occlusion_layer_for_light_mask_1() -> void:
	var tile_set: TileSet = _load_floor_wall_tile_set()
	assert_not_null(tile_set, FLOOR_WALL_TILE_PATH)
	if tile_set == null:
		return
	assert_true(_find_occlusion_layer(tile_set) >= 0, "an occlusion layer with light_mask & 1")


func test_arch_opening_tiles_have_occluders() -> void:
	var tile_set: TileSet = _load_floor_wall_tile_set()
	var layer: int = _find_occlusion_layer(tile_set) if tile_set != null else -1
	if layer < 0:
		skip("no occlusion layer")
		return
	for coords: Vector2i in ARCH_TILES:
		assert_true(_occluder_count(tile_set, coords, layer) > 0, "arch tile %s" % coords)


func test_brick_fronts_have_no_occluders() -> void:
	var tile_set: TileSet = _load_floor_wall_tile_set()
	var layer: int = _find_occlusion_layer(tile_set) if tile_set != null else -1
	if layer < 0:
		skip("no occlusion layer")
		return
	for coords: Vector2i in BRICK_FRONT_TILES:
		assert_eq(_occluder_count(tile_set, coords, layer), 0, "brick front %s" % coords)


## The user edits FloorWallTile in the editor, so the layer (light_mask is the default 1)
## must survive a save and reload.
func test_occlusion_survives_save() -> void:
	var tile_set: TileSet = _load_floor_wall_tile_set()
	if tile_set == null:
		skip("tile set did not load")
		return
	assert_eq(ResourceSaver.save(tile_set.duplicate(true), ROUND_TRIP_PATH), OK, "save " + ROUND_TRIP_PATH)
	var reloaded: TileSet = ResourceLoader.load(ROUND_TRIP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TileSet
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ROUND_TRIP_PATH))
	assert_not_null(reloaded, "reloaded tile set")
	if reloaded == null:
		return
	var layer: int = _find_occlusion_layer(reloaded)
	assert_true(layer >= 0, "occlusion layer after reload")
	if layer >= 0:
		assert_true(_occluder_count(reloaded, Vector2i(4, 24), layer) > 0, "arch occluder after reload")


func test_torch_light_casts_shadows_and_keeps_its_look() -> void:
	var torch: Node = (load(TORCH_PATH) as PackedScene).instantiate()
	var light: PointLight2D = torch.get_node_or_null("Sprite2D/PointLight2D") as PointLight2D
	assert_not_null(light, "Sprite2D/PointLight2D")
	if light != null:
		assert_true(light.shadow_enabled, "shadow_enabled")
		assert_true(light.color.is_equal_approx(TORCH_COLOR), "color %s" % light.color)
		assert_eq(light.energy, TORCH_ENERGY, "energy")
	torch.free()


func _load_floor_wall_tile_set() -> TileSet:
	var layer: TileMapLayer = (load(FLOOR_WALL_TILE_PATH) as PackedScene).instantiate() as TileMapLayer
	if layer == null:
		return null
	var tile_set: TileSet = layer.tile_set
	layer.free()
	return tile_set


func _find_occlusion_layer(tile_set: TileSet) -> int:
	for i: int in tile_set.get_occlusion_layers_count():
		if tile_set.get_occlusion_layer_light_mask(i) & 1:
			return i
	return -1


func _occluder_count(tile_set: TileSet, coords: Vector2i, layer: int) -> int:
	var source: TileSetAtlasSource = tile_set.get_source(0) as TileSetAtlasSource
	if source == null or not source.has_tile(coords):
		return -1
	var data: TileData = source.get_tile_data(coords, 0)
	var count: int = 0
	for i: int in data.get_occluder_polygons_count(layer):
		var polygon: OccluderPolygon2D = data.get_occluder_polygon(layer, i)
		if polygon != null and polygon.polygon.size() >= 3:
			count += 1
	return count
