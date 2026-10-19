@tool
class_name MCPToolkitSinfulnessPropTools
extends MCPToolkitExtension
## Places Prop instances (res://Entities/GeneralNodes/Props/Prop.tscn) from a JSON plan.
##
## Registers [code]sinprops.place[/code] (MCP tool [code]sinprops_place[/code]). The tool
## is eager (no group), so it is listed as soon as a client connects.[br]
## [br]
## Plan file (res:// or user:// JSON):[br]
## [code]{"textures_dir": "res://.../Textures", "groups": [{"name": "R1_Props", "props":
## [{"variant": "barrel_dark", "x": 120, "y": 600, "name"?, "solid"?, "breakable"?, "flat"?,
## "lift"?, "collision_size"?: [w, h]}]}]}[/code][br]
## Every group becomes a y-sorted Node2D under [code]parent_path[/code] (created at the end
## of the scene root when missing) holding one Prop instance per entry. Placing goes
## through the editor undo history as one action. Save with [code]editor_save_scene[/code].

const _PROP_SCENE: String = "res://Entities/GeneralNodes/Props/Prop.tscn"
const _DEFAULT_TEXTURES_DIR: String = "res://Entities/GeneralNodes/Props/Textures"


## Registers the prop command with the live [param registry].
## [param server] is the MCP server node (unused).
func register(registry: MCPToolkitCommandRegistry, server: Node) -> void:
	var place_opts := MCPToolkitExtensionOptions.new(
		"Instance Prop.tscn from a JSON plan file into the edited scene, with undo. 'file' is a " +
		"res:// or user:// JSON {textures_dir?, groups: [{name, props: [{variant, x, y, name?, solid?, " +
		"breakable?, flat?, lift?, collision_size?: [w, h]}]}]}. Each group becomes a y-sorted Node2D " +
		"under 'parent_path' (default 'Props', created at the end of the root if missing). " +
		"'clear_first' removes everything under parent_path first.") \
		.with_timeout_ms(60000) \
		.with_input_schema({
			"type": "object",
			"properties": {
				"file": {"type": "string", "description": "res:// or user:// JSON plan"},
				"parent_path": {"type": "string", "default": "Props"},
				"clear_first": {"type": "boolean", "default": false},
			},
			"required": ["file"],
		})
	registry.add("sinprops.place", _place, place_opts)


## Instances every prop of the plan in [code]file[/code] as one undoable action.
##
## Returns a success envelope with the number of props per group, or a failure envelope
## when the plan, a texture or the Prop scene cannot be loaded.
func _place(params: Dictionary) -> Dictionary:
	var missing: Variant = MCPToolkitError.require(params, ["file"])
	if missing != null:
		return missing
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		return MCPToolkitError.fail("NOT_FOUND", "no scene is open in the editor", "Open the scene with scene_open first.")
	var file_path: String = str(params["file"])
	if not (file_path.begins_with("res://") or file_path.begins_with("user://")):
		return MCPToolkitError.fail("INVALID_PARAMS", "file must be a res:// or user:// path")
	var text: String = FileAccess.get_file_as_string(file_path)
	if text.is_empty():
		return MCPToolkitError.fail("NOT_FOUND", "cannot read %s" % file_path)
	var plan: Variant = JSON.parse_string(text)
	if not (plan is Dictionary) or not (plan.get("groups") is Array):
		return MCPToolkitError.fail("INVALID_PARAMS", "%s is not a plan {groups: [...]}" % file_path)
	var packed := ResourceLoader.load(_PROP_SCENE) as PackedScene
	if packed == null:
		return MCPToolkitError.fail("NOT_FOUND", "%s is not a loadable scene" % _PROP_SCENE)
	var textures_dir: String = str(plan.get("textures_dir", _DEFAULT_TEXTURES_DIR))

	# Build every node first, so a bad entry changes nothing.
	var groups: Array[Node2D] = []
	var counts: Dictionary = {}
	for group_data: Variant in plan["groups"]:
		if not (group_data is Dictionary):
			continue
		var group := Node2D.new()
		group.name = str(group_data.get("name", "Group"))
		group.y_sort_enabled = true
		var used_names: Dictionary = {}
		for prop_data: Variant in group_data.get("props", []):
			if not (prop_data is Dictionary):
				continue
			var variant: String = str(prop_data.get("variant", ""))
			var texture := ResourceLoader.load("%s/%s.tres" % [textures_dir, variant]) as Texture2D
			if texture == null:
				return MCPToolkitError.fail("NOT_FOUND", "no texture %s/%s.tres (group %s)" % [textures_dir, variant, group.name])
			var prop: Node2D = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			prop.name = _unique_name(str(prop_data.get("name", variant)), used_names)
			prop.position = Vector2(roundf(float(prop_data.get("x", 0))), roundf(float(prop_data.get("y", 0))))
			prop.set("texture", texture)
			for flag: String in ["solid", "breakable", "flat"]:
				if prop_data.has(flag):
					prop.set(flag, bool(prop_data[flag]))
			if prop_data.has("lift"):
				prop.set("lift", int(prop_data["lift"]))
			var size: Variant = prop_data.get("collision_size")
			if size is Array and size.size() == 2:
				prop.set("collision_size", Vector2(float(size[0]), float(size[1])))
			group.add_child(prop)
		counts[str(group.name)] = group.get_child_count()
		groups.append(group)

	var parent_path: String = str(params.get("parent_path", "Props"))
	var parent: Node = root.get_node_or_null(NodePath(parent_path))
	var new_parent: Node2D = null
	if parent == null:
		if parent_path.contains("/"):
			return MCPToolkitError.fail("NODE_NOT_FOUND", "no node at %s" % parent_path)
		new_parent = Node2D.new()
		new_parent.name = parent_path
		new_parent.y_sort_enabled = true
		parent = new_parent

	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("MCP place props from %s" % file_path.get_file(), UndoRedo.MERGE_DISABLE, root)
	if new_parent != null:
		undo_redo.add_do_method(root, "add_child", new_parent, true)
		undo_redo.add_do_method(new_parent, "set_owner", root)
		undo_redo.add_do_reference(new_parent)
		undo_redo.add_undo_method(root, "remove_child", new_parent)
	elif bool(params.get("clear_first", false)):
		for old: Node in parent.get_children():
			undo_redo.add_do_method(parent, "remove_child", old)
			undo_redo.add_undo_method(parent, "add_child", old, true)
			undo_redo.add_undo_method(parent, "move_child", old, old.get_index())
			for owned: Node in _owned_subtree(old, root):
				undo_redo.add_undo_method(owned, "set_owner", root)
			undo_redo.add_undo_reference(old)
	for group: Node2D in groups:
		undo_redo.add_do_method(parent, "add_child", group, true)
		undo_redo.add_do_method(group, "set_owner", root)
		for prop: Node in group.get_children():
			undo_redo.add_do_method(prop, "set_owner", root)
		undo_redo.add_do_reference(group)
		undo_redo.add_undo_method(parent, "remove_child", group)
	undo_redo.commit_action(true)

	var total: int = 0
	for group_name: String in counts:
		total += int(counts[group_name])
	return MCPToolkitSuccess.ok({
		"parent": str(root.get_path_to(parent)),
		"groups": counts,
		"total": total,
	})


## Returns [param base], or [param base] with a number, not yet in [param used].
func _unique_name(base: String, used: Dictionary) -> String:
	var candidate: String = base
	var n: int = 2
	while used.has(candidate):
		candidate = "%s_%d" % [base, n]
		n += 1
	used[candidate] = true
	return candidate


## Returns [param node] and its descendants whose owner is [param root].
func _owned_subtree(node: Node, root: Node) -> Array[Node]:
	var result: Array[Node] = []
	if node.owner == root:
		result.append(node)
	for child: Node in node.get_children():
		result.append_array(_owned_subtree(child, root))
	return result
