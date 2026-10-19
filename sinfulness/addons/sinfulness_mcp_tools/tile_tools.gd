@tool
class_name MCPToolkitSinfulnessTileTools
extends MCPToolkitExtension
## Paints and reads cells on TileMapLayer nodes of the edited scene.
##
## Registers [code]sintiles.paint[/code] (MCP tool [code]sintiles_paint[/code]),
## [code]sintiles.read[/code] ([code]sintiles_read[/code]),
## [code]sintiles.terrain[/code] ([code]sintiles_terrain[/code]) and
## [code]sintiles.add_layer[/code] ([code]sintiles_add_layer[/code]). The tools are
## eager (no group), so they are listed as soon as a client connects.[br]
## [br]
## Painting goes through the editor undo history, so every call can be undone with
## Ctrl+Z, and marks the scene as modified. Save it with [code]editor_save_scene[/code].
## Only cells whose tile exists in the layer's TileSet are written; the rest are
## reported as invalid.

const Untrusted = preload("res://addons/godot_mcp_toolkit/security/untrusted.gd")
const _READ_CAP: int = 3000


## Registers the three tile commands with the live [param registry].
## [param server] is the MCP server node (unused).
func register(registry: MCPToolkitCommandRegistry, server: Node) -> void:
	var paint_opts := MCPToolkitExtensionOptions.new(
		"Paint cells on a TileMapLayer in the edited scene, with undo. Combine any of: 'cells' " +
		"(list of {x, y, atlas_x, atlas_y, source_id?, alt?}; source_id -1 erases), 'regions' " +
		"(rectangles {x, y, width, height, atlas_x, atlas_y, source_id?, alt?}) and 'map' " +
		"(ASCII rows painted from 'origin' {x, y} with 'legend' {char: [atlas_x, atlas_y]} or " +
		"{char: [atlas_x, atlas_y, source_id]}; a char mapped to [-1] erases, chars missing from " +
		"the legend are skipped). Applied in order cells, regions, map. 'clear_first' empties the layer. " +
		"'map_file' (a user:// JSON file with map, legend and origin) replaces the inline map.") \
		.with_timeout_ms(60000) \
		.with_input_schema({
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "TileMapLayer path relative to the edited scene root, e.g. 'Walls'"},
				"clear_first": {"type": "boolean", "default": false},
				"cells": {"type": "array", "items": {"type": "object"}},
				"regions": {"type": "array", "items": {"type": "object"}},
				"origin": {"type": "object", "description": "{x, y} cell of the first map character"},
				"map": {"type": "array", "items": {"type": "string"}},
				"legend": {"type": "object"},
				"map_file": {"type": "string", "description": "user:// JSON file {map, legend, origin}"},
			},
			"required": ["node_path"],
		})
	registry.add("sintiles.paint", _paint, paint_opts)

	var read_opts := MCPToolkitExtensionOptions.new(
		"Read cells of a TileMapLayer in the edited scene: used_rect, cell count, and cells " +
		"{x, y, source_id, atlas_x, atlas_y} (optionally only inside 'region' {x, y, width, height}). " +
		"With as_map:true returns ASCII rows instead, one char per atlas tile plus a legend.") \
		.mark_read_only() \
		.with_input_schema({
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"region": {"type": "object"},
				"as_map": {"type": "boolean", "default": false},
			},
			"required": ["node_path"],
		})
	registry.add("sintiles.read", _read, read_opts)

	var terrain_opts := MCPToolkitExtensionOptions.new(
		"Paint cells with a terrain (TileMapLayer.set_cells_terrain_connect), with undo. " +
		"'cells' is a list of {x, y} or 'regions' a list of {x, y, width, height}.") \
		.with_timeout_ms(60000) \
		.with_input_schema({
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"terrain_set": {"type": "integer", "default": 0},
				"terrain": {"type": "integer", "default": 0},
				"cells": {"type": "array", "items": {"type": "object"}},
				"regions": {"type": "array", "items": {"type": "object"}},
			},
			"required": ["node_path"],
		})
	registry.add("sintiles.terrain", _terrain, terrain_opts)

	var add_layer_opts := MCPToolkitExtensionOptions.new(
		"Instance a tile scene (e.g. res://Floors/TilesSetsNodes/FloorWallTile.tscn) as a new layer " +
		"node in the edited scene, as a real instance that shares the scene's TileSet, with undo. " +
		"Optional parent_path (default root), index among siblings and z_index.") \
		.guard_project_path("scene_path") \
		.with_input_schema({
			"type": "object",
			"properties": {
				"scene_path": {"type": "string"},
				"node_name": {"type": "string"},
				"parent_path": {"type": "string", "default": "."},
				"index": {"type": "integer"},
				"z_index": {"type": "integer"},
			},
			"required": ["scene_path", "node_name"],
		})
	registry.add("sintiles.add_layer", _add_layer, add_layer_opts)

	var reload_opts := MCPToolkitExtensionOptions.new(
		"Reload an open scene tab from disk (EditorInterface.reload_scene_from_path), discarding " +
		"unsaved editor changes in that tab. Use after the .tscn was changed outside the editor.") \
		.mark_destructive() \
		.guard_project_path("scene_path") \
		.with_input_schema({
			"type": "object",
			"properties": {"scene_path": {"type": "string"}},
			"required": ["scene_path"],
		})
	registry.add("sintiles.reload_scene", _reload_scene, reload_opts)


## Writes the cells described by [param params] into the TileMapLayer at
## [code]node_path[/code] as one undoable action.
##
## Returns a success envelope with the number of cells written, erased, unchanged and
## invalid, plus the layer's used_rect after painting; or a failure envelope when the
## node is missing or not a TileMapLayer.
func _paint(params: Dictionary) -> Dictionary:
	var layer_or_error: Variant = _get_layer(params)
	if layer_or_error is Dictionary:
		return layer_or_error
	var layer: TileMapLayer = layer_or_error
	if params.has("map_file"):
		var file_error: Variant = _load_map_file(params)
		if file_error != null:
			return file_error

	# Final value per cell: [source_id, atlas, alt]. Later entries win.
	var wanted: Dictionary = {}
	if bool(params.get("clear_first", false)):
		for coords: Vector2i in layer.get_used_cells():
			wanted[coords] = [-1, Vector2i(-1, -1), 0]
	for cell: Variant in params.get("cells", []):
		if cell is Dictionary:
			wanted[Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0)))] = _tile_from(cell)
	for region: Variant in params.get("regions", []):
		if not (region is Dictionary):
			continue
		var tile: Array = _tile_from(region)
		var start := Vector2i(int(region.get("x", 0)), int(region.get("y", 0)))
		for dy: int in int(region.get("height", 1)):
			for dx: int in int(region.get("width", 1)):
				wanted[start + Vector2i(dx, dy)] = tile
	var map_error: Variant = _collect_map(params, wanted)
	if map_error != null:
		return map_error

	var written: int = 0
	var erased: int = 0
	var unchanged: int = 0
	var invalid: Array[String] = []
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("MCP paint tiles on %s" % layer.name, UndoRedo.MERGE_DISABLE, layer)
	for coords: Vector2i in wanted:
		var tile: Array = wanted[coords]
		var source_id: int = tile[0]
		var atlas: Vector2i = tile[1]
		var alt: int = tile[2]
		var old_source: int = layer.get_cell_source_id(coords)
		var old_atlas: Vector2i = layer.get_cell_atlas_coords(coords)
		var old_alt: int = layer.get_cell_alternative_tile(coords)
		if source_id == -1:
			if old_source == -1:
				unchanged += 1
				continue
			erased += 1
		else:
			if not _tile_exists(layer, source_id, atlas, alt):
				if invalid.size() < 20:
					invalid.append("%d,%d -> %d:%d" % [coords.x, coords.y, atlas.x, atlas.y])
				continue
			if old_source == source_id and old_atlas == atlas and old_alt == alt:
				unchanged += 1
				continue
			written += 1
		undo_redo.add_do_method(layer, "set_cell", coords, source_id, atlas, alt)
		undo_redo.add_undo_method(layer, "set_cell", coords, old_source, old_atlas, old_alt)
	undo_redo.commit_action(true)

	return MCPToolkitSuccess.ok({
		"layer": str(layer.name),
		"written": written,
		"erased": erased,
		"unchanged": unchanged,
		"invalid_count": invalid.size(),
		"invalid_sample": invalid,
		"used_rect": _rect_dict(layer.get_used_rect()),
	})


## Returns the cells of the TileMapLayer at [code]node_path[/code], optionally limited
## to [code]region[/code], as a list or (with [code]as_map[/code]) as ASCII rows.
func _read(params: Dictionary) -> Dictionary:
	var layer_or_error: Variant = _get_layer(params)
	if layer_or_error is Dictionary:
		return layer_or_error
	var layer: TileMapLayer = layer_or_error
	var used_rect: Rect2i = layer.get_used_rect()
	var area: Rect2i = used_rect
	if params.get("region") is Dictionary:
		var r: Dictionary = params["region"]
		area = Rect2i(int(r.get("x", 0)), int(r.get("y", 0)), int(r.get("width", 0)), int(r.get("height", 0)))

	if bool(params.get("as_map", false)):
		var symbols: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#$%&*+=?@"
		var legend: Dictionary = {}
		var rows: Array[String] = []
		for y: int in range(area.position.y, area.end.y):
			var row: String = ""
			for x: int in range(area.position.x, area.end.x):
				var coords := Vector2i(x, y)
				var source_id: int = layer.get_cell_source_id(coords)
				if source_id == -1:
					row += "."
					continue
				var key: String = "%d:%d:%d" % [source_id, layer.get_cell_atlas_coords(coords).x, layer.get_cell_atlas_coords(coords).y]
				if not legend.has(key):
					legend[key] = symbols[min(legend.size(), symbols.length() - 1)]
				row += legend[key]
			rows.append(row)
		var inverted: Dictionary = {}
		for key: String in legend:
			inverted[legend[key]] = key
		return MCPToolkitSuccess.ok({
			"used_rect": _rect_dict(used_rect),
			"area": _rect_dict(area),
			"map": Untrusted.wrap("tile_map", str(layer.name), "\n".join(rows)),
			"legend": Untrusted.wrap("tile_legend", str(layer.name), JSON.stringify(inverted)),
		})

	var cells: Array[Dictionary] = []
	var total: int = 0
	for coords: Vector2i in layer.get_used_cells():
		if not area.has_point(coords):
			continue
		total += 1
		if cells.size() >= _READ_CAP:
			continue
		var atlas: Vector2i = layer.get_cell_atlas_coords(coords)
		cells.append({"x": coords.x, "y": coords.y, "source_id": layer.get_cell_source_id(coords), "atlas_x": atlas.x, "atlas_y": atlas.y})
	return MCPToolkitSuccess.ok({
		"used_rect": _rect_dict(used_rect),
		"total_cells": total,
		"returned": cells.size(),
		"cells": Untrusted.wrap("tile_cells", str(layer.name), JSON.stringify(cells)),
	})


## Paints [code]cells[/code] and [code]regions[/code] with terrain
## [code]terrain[/code] of terrain set [code]terrain_set[/code] as one undoable action.
func _terrain(params: Dictionary) -> Dictionary:
	var layer_or_error: Variant = _get_layer(params)
	if layer_or_error is Dictionary:
		return layer_or_error
	var layer: TileMapLayer = layer_or_error
	var coords_list: Array[Vector2i] = []
	for cell: Variant in params.get("cells", []):
		if cell is Dictionary:
			coords_list.append(Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0))))
	for region: Variant in params.get("regions", []):
		if not (region is Dictionary):
			continue
		for dy: int in int(region.get("height", 1)):
			for dx: int in int(region.get("width", 1)):
				coords_list.append(Vector2i(int(region.get("x", 0)) + dx, int(region.get("y", 0)) + dy))
	if coords_list.is_empty():
		return MCPToolkitError.fail("INVALID_PARAMS", "no cells or regions given")

	# Snapshot the cells around the painted area so undo restores neighbours the
	# terrain solver also changed.
	var before: Dictionary = {}
	for coords: Vector2i in coords_list:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var c: Vector2i = coords + Vector2i(dx, dy)
				before[c] = [layer.get_cell_source_id(c), layer.get_cell_atlas_coords(c), layer.get_cell_alternative_tile(c)]
	layer.set_cells_terrain_connect(coords_list, int(params.get("terrain_set", 0)), int(params.get("terrain", 0)))

	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("MCP terrain on %s" % layer.name, UndoRedo.MERGE_DISABLE, layer)
	for c: Vector2i in before:
		var old: Array = before[c]
		undo_redo.add_do_method(layer, "set_cell", c, layer.get_cell_source_id(c), layer.get_cell_atlas_coords(c), layer.get_cell_alternative_tile(c))
		undo_redo.add_undo_method(layer, "set_cell", c, old[0], old[1], old[2])
	undo_redo.commit_action(false)
	return MCPToolkitSuccess.ok({
		"layer": str(layer.name),
		"cells": coords_list.size(),
		"used_rect": _rect_dict(layer.get_used_rect()),
	})


## Instances the scene at [code]scene_path[/code] under [code]parent_path[/code] as a
## node named [code]node_name[/code], as one undoable action.
##
## Returns a success envelope with the new node's path and index, or a failure envelope
## when the scene cannot be loaded or the name is taken.
func _add_layer(params: Dictionary) -> Dictionary:
	var missing: Variant = MCPToolkitError.require(params, ["scene_path", "node_name"])
	if missing != null:
		return missing
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		return MCPToolkitError.fail("NOT_FOUND", "no scene is open in the editor", "Open the scene with scene_open first.")
	var parent_path: String = str(params.get("parent_path", "."))
	var parent: Node = root if parent_path == "." or parent_path.is_empty() else root.get_node_or_null(NodePath(parent_path))
	if parent == null:
		return MCPToolkitError.fail("NODE_NOT_FOUND", "no node at %s" % parent_path)
	var node_name: String = str(params["node_name"])
	if parent.has_node(NodePath(node_name)):
		return MCPToolkitError.fail("INVALID_PARAMS", "%s already has a child named %s" % [parent_path, node_name])
	var packed := ResourceLoader.load(str(params["scene_path"])) as PackedScene
	if packed == null:
		return MCPToolkitError.fail("NOT_FOUND", "%s is not a loadable scene" % params["scene_path"])

	var node: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = node_name
	if params.has("z_index") and node is CanvasItem:
		(node as CanvasItem).z_index = int(params["z_index"])
	var index: int = int(params.get("index", parent.get_child_count()))

	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("MCP add layer %s" % node_name, UndoRedo.MERGE_DISABLE, root)
	undo_redo.add_do_method(parent, "add_child", node, true)
	undo_redo.add_do_method(node, "set_owner", root)
	undo_redo.add_do_method(parent, "move_child", node, index)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(parent, "remove_child", node)
	undo_redo.commit_action(true)

	return MCPToolkitSuccess.ok({
		"path": str(root.get_path_to(node)),
		"index": node.get_index(),
		"scene_file_path": node.scene_file_path,
	})


## Reloads the open scene [code]scene_path[/code] from disk.
##
## Returns a success envelope, or a failure envelope when the scene is not open.
func _reload_scene(params: Dictionary) -> Dictionary:
	var missing: Variant = MCPToolkitError.require(params, ["scene_path"])
	if missing != null:
		return missing
	var scene_path: String = str(params["scene_path"])
	var open_scenes: PackedStringArray = EditorInterface.get_open_scenes()
	var is_open: bool = false
	for open_path: String in open_scenes:
		if open_path == scene_path or (open_path.begins_with("uid://") and ResourceUID.ensure_path(open_path) == scene_path):
			is_open = true
	if not is_open:
		return MCPToolkitError.fail("NOT_FOUND", "%s is not open in the editor (open: %s)" % [scene_path, ", ".join(open_scenes)], "Open it with scene_open instead.")
	EditorInterface.reload_scene_from_path(scene_path)
	return MCPToolkitSuccess.ok({"reloaded": scene_path})


## Returns the TileMapLayer named by [code]node_path[/code] in the edited scene, or a
## failure envelope.
func _get_layer(params: Dictionary) -> Variant:
	var missing: Variant = MCPToolkitError.require(params, ["node_path"])
	if missing != null:
		return missing
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		return MCPToolkitError.fail("NOT_FOUND", "no scene is open in the editor", "Open the scene with scene_open first.")
	var path: String = str(params["node_path"])
	var node: Node = root if path == "." or path.is_empty() else root.get_node_or_null(NodePath(path))
	if node == null:
		return MCPToolkitError.fail("NODE_NOT_FOUND", "no node at %s" % path, "Use scene_get_tree to list valid node paths.")
	if not (node is TileMapLayer):
		return MCPToolkitError.fail("INVALID_PARAMS", "%s is a %s, not a TileMapLayer" % [path, node.get_class()])
	if (node as TileMapLayer).tile_set == null:
		return MCPToolkitError.fail("INVALID_PARAMS", "%s has no TileSet" % path)
	return node


## Reads [code]map[/code], [code]legend[/code] and [code]origin[/code] from the
## user:// JSON file named by [code]map_file[/code] into [param params].
## Returns a failure envelope when the file is outside user:// or unreadable, or null.
func _load_map_file(params: Dictionary) -> Variant:
	var path: String = str(params["map_file"])
	if not path.begins_with("user://") or path.contains(".."):
		return MCPToolkitError.fail("PATH_DENIED", "map_file must be a user:// path without '..'")
	if not FileAccess.file_exists(path):
		return MCPToolkitError.fail("NOT_FOUND", "no file at %s" % path)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or not (data.get("map") is Array):
		return MCPToolkitError.fail("INVALID_VALUE", "%s must hold an object with a 'map' array" % path)
	for key: String in ["map", "legend", "origin"]:
		if data.has(key):
			params[key] = data[key]
	return null


## Adds the cells of the ASCII [code]map[/code] in [param params] to [param wanted].
## Returns a failure envelope on a malformed legend, or null.
func _collect_map(params: Dictionary, wanted: Dictionary) -> Variant:
	var rows: Variant = params.get("map", [])
	if not (rows is Array) or (rows as Array).is_empty():
		return null
	if not (params.get("legend") is Dictionary):
		return MCPToolkitError.fail("INVALID_PARAMS", "'map' needs a 'legend' object")
	var legend: Dictionary = {}
	for key: Variant in params["legend"]:
		var entry: Variant = params["legend"][key]
		if not (entry is Array) or (entry as Array).is_empty():
			return MCPToolkitError.fail("INVALID_PARAMS", "legend entry '%s' must be [atlas_x, atlas_y] or [-1]" % key)
		var values: Array = entry
		if int(values[0]) == -1 and values.size() == 1:
			legend[str(key)] = [-1, Vector2i(-1, -1), 0]
		elif values.size() >= 2:
			var source_id: int = int(values[2]) if values.size() >= 3 else 0
			legend[str(key)] = [source_id, Vector2i(int(values[0]), int(values[1])), 0]
		else:
			return MCPToolkitError.fail("INVALID_PARAMS", "legend entry '%s' must be [atlas_x, atlas_y] or [-1]" % key)
	var origin := Vector2i.ZERO
	if params.get("origin") is Dictionary:
		origin = Vector2i(int(params["origin"].get("x", 0)), int(params["origin"].get("y", 0)))
	for y: int in (rows as Array).size():
		var row: String = str(rows[y])
		for x: int in row.length():
			var ch: String = row[x]
			if legend.has(ch):
				wanted[origin + Vector2i(x, y)] = legend[ch]
	return null


func _tile_from(entry: Dictionary) -> Array:
	var source_id: int = int(entry.get("source_id", 0))
	if source_id == -1:
		return [-1, Vector2i(-1, -1), 0]
	return [source_id, Vector2i(int(entry.get("atlas_x", 0)), int(entry.get("atlas_y", 0))), int(entry.get("alt", 0))]


func _tile_exists(layer: TileMapLayer, source_id: int, atlas: Vector2i, alt: int) -> bool:
	if not layer.tile_set.has_source(source_id):
		return false
	var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null or not source.has_tile(atlas):
		return false
	return source.has_alternative_tile(atlas, alt)


func _rect_dict(rect: Rect2i) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}
