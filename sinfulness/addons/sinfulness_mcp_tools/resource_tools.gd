@tool
class_name MCPToolkitSinfulnessResourceTools
extends MCPToolkitExtension
## Creates, updates and reads .tres resources inside the editor.
##
## Registers [code]sinres.write[/code] and [code]sinres.read[/code] (MCP tools
## [code]sinres_write[/code], [code]sinres_read[/code]). Eager (no group), because the
## built-in resource_io group does not show up in every client.[br]
## [br]
## Writing edits the editor's cached instance and saves it with ResourceSaver, so the
## editor never keeps a stale copy that overwrites the file later.[br]
## Property values are JSON and are converted to the property's type: numbers, bools,
## strings, StringName, [x, y] for Vector2, a res:// path for a resource, or
## [code]{"script": "res://x.gd", "properties": {...}}[/code] for a new sub-resource.
## Arrays (also typed arrays) take a list of such values and replace the whole array.

const _BUILT_IN_PROPERTIES: Array[String] = ["resource_local_to_scene", "resource_path", "resource_name", "resource_scene_unique_id", "script", "metadata/_custom_type_script"]


## Registers the resource commands with the live [param registry].
## [param server] is the MCP server node (unused).
func register(registry: MCPToolkitCommandRegistry, server: Node) -> void:
	var write_opts := MCPToolkitExtensionOptions.new(
		"Create or update a .tres in the editor and save it. 'file_path' is res://...tres. " +
		"'script' (res:// .gd) is required when the file does not exist yet. 'properties' maps " +
		"property names to JSON values: numbers, bools, strings, [x, y] for Vector2, a res:// path for " +
		"a resource, {script, properties} for a new sub-resource, or a list of these for an array " +
		"(replaces the whole array).") \
		.with_input_schema({
			"type": "object",
			"properties": {
				"file_path": {"type": "string"},
				"script": {"type": "string", "description": "res:// .gd, needed to create a new file"},
				"properties": {"type": "object"},
			},
			"required": ["file_path"],
		})
	registry.add("sinres.write", _write, write_opts)

	var read_opts := MCPToolkitExtensionOptions.new(
		"Read a .tres as the editor sees it: script path and every stored property " +
		"(sub-resources are expanded one level, other resources shown by path).") \
		.with_input_schema({
			"type": "object",
			"properties": {"file_path": {"type": "string"}},
			"required": ["file_path"],
		})
	registry.add("sinres.read", _read, read_opts)


func _write(params: Dictionary) -> Dictionary:
	var missing: Variant = MCPToolkitError.require(params, ["file_path"])
	if missing != null:
		return missing
	var file_path: String = str(params["file_path"])
	if not (file_path.begins_with("res://") and file_path.ends_with(".tres")):
		return MCPToolkitError.fail("INVALID_PARAMS", "file_path must be a res:// .tres path")

	var resource: Resource = null
	var created: bool = false
	if ResourceLoader.exists(file_path):
		resource = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_REUSE)
		if resource == null:
			return MCPToolkitError.fail("NOT_FOUND", "cannot load %s" % file_path)
	else:
		if not params.has("script"):
			return MCPToolkitError.fail("INVALID_PARAMS", "%s does not exist; pass 'script' to create it" % file_path)
		resource = _new_from_script(str(params["script"]))
		if resource == null:
			return MCPToolkitError.fail("NOT_FOUND", "cannot instantiate %s" % params["script"])
		created = true

	var properties: Variant = params.get("properties", {})
	if not (properties is Dictionary):
		return MCPToolkitError.fail("INVALID_PARAMS", "properties must be an object")
	var error: String = _apply(resource, properties)
	if not error.is_empty():
		return MCPToolkitError.fail("INVALID_PARAMS", error)

	var flags: int = ResourceSaver.FLAG_CHANGE_PATH if created else 0
	var result: Error = ResourceSaver.save(resource, file_path, flags)
	if result != OK:
		return MCPToolkitError.fail("SAVE_FAILED", "ResourceSaver.save(%s) returned %s" % [file_path, error_string(result)])
	resource.emit_changed()
	EditorInterface.get_resource_filesystem().update_file(file_path)
	return MCPToolkitSuccess.ok({"file_path": file_path, "created": created, "properties": _describe(resource, 1)})


func _read(params: Dictionary) -> Dictionary:
	var missing: Variant = MCPToolkitError.require(params, ["file_path"])
	if missing != null:
		return missing
	var file_path: String = str(params["file_path"])
	if not ResourceLoader.exists(file_path):
		return MCPToolkitError.fail("NOT_FOUND", "%s does not exist" % file_path)
	var resource: Resource = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_REUSE)
	if resource == null:
		return MCPToolkitError.fail("NOT_FOUND", "cannot load %s" % file_path)
	return MCPToolkitSuccess.ok({"file_path": file_path, "properties": _describe(resource, 1)})


# -- Converting ----------------------------------------------------------------


func _new_from_script(script_path: String) -> Resource:
	var script := ResourceLoader.load(script_path) as Script
	if script == null or not ClassDB.is_parent_class(script.get_instance_base_type(), "Resource"):
		return null
	# Like the Inspector: a non-@tool script gets a placeholder instance that keeps exported values.
	var resource: Resource = ClassDB.instantiate(script.get_instance_base_type())
	resource.set_script(script)
	return resource


## Sets every entry of [param properties] on [param resource]. Returns an error text or "".
func _apply(resource: Resource, properties: Dictionary) -> String:
	var infos: Dictionary = {}
	for info: Dictionary in resource.get_property_list():
		infos[info["name"]] = info
	for key: Variant in properties:
		var name: String = str(key)
		if not infos.has(name):
			return "%s has no property '%s'" % [resource.get_class(), name]
		var value: Variant = _convert(properties[key], infos[name], resource.get(name))
		if value is String and str(value).begins_with("ERROR: "):
			return "%s: %s" % [name, str(value).trim_prefix("ERROR: ")]
		resource.set(name, value)
	return ""


func _convert(value: Variant, info: Dictionary, current: Variant) -> Variant:
	match int(info["type"]):
		TYPE_BOOL:
			return bool(value)
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_STRING:
			return str(value)
		TYPE_STRING_NAME:
			return StringName(str(value))
		TYPE_VECTOR2:
			if value is Array and value.size() == 2:
				return Vector2(float(value[0]), float(value[1]))
			return "ERROR: expected [x, y]"
		TYPE_OBJECT:
			return _to_resource(value)
		TYPE_ARRAY:
			if not (value is Array):
				return "ERROR: expected a list"
			var array: Array = (current as Array).duplicate() if current is Array else []
			array.clear()
			for item: Variant in value:
				var converted: Variant = _to_resource(item) if (item is Dictionary or (item is String and str(item).begins_with("res://"))) else item
				if converted is String and str(converted).begins_with("ERROR: "):
					return converted
				array.append(converted)
			return array
	return value


func _to_resource(value: Variant) -> Variant:
	if value == null:
		return null
	if value is String:
		var loaded: Resource = ResourceLoader.load(str(value))
		return loaded if loaded != null else "ERROR: cannot load %s" % value
	if value is Dictionary and value.has("script"):
		var sub: Resource = _new_from_script(str(value["script"]))
		if sub == null:
			return "ERROR: cannot instantiate %s" % value["script"]
		var error: String = _apply(sub, value.get("properties", {}))
		return sub if error.is_empty() else "ERROR: " + error
	return "ERROR: expected a res:// path or {script, properties}"


## Stored script properties of [param resource] as JSON-friendly values.
func _describe(resource: Resource, depth: int) -> Dictionary:
	var out: Dictionary = {"_script": resource.get_script().resource_path if resource.get_script() != null else resource.get_class()}
	for info: Dictionary in resource.get_property_list():
		if not (int(info["usage"]) & PROPERTY_USAGE_STORAGE) or _BUILT_IN_PROPERTIES.has(info["name"]):
			continue
		out[info["name"]] = _describe_value(resource.get(info["name"]), depth)
	return out


func _describe_value(value: Variant, depth: int) -> Variant:
	if value is Resource:
		var res: Resource = value
		if not res.resource_path.is_empty() and not res.resource_path.contains("::"):
			return res.resource_path
		return _describe(res, depth - 1) if depth > 0 else res.get_class()
	if value is Array:
		var list: Array = []
		for item: Variant in value:
			list.append(_describe_value(item, depth))
		return list
	if value is Vector2:
		return [value.x, value.y]
	if value is StringName:
		return str(value)
	return value
