@tool
class_name MCPToolkitProjectFsTools
extends MCPToolkitExtension
## Moves or renames a res:// file or folder while keeping references and UIDs intact.
##
## Registers [code]project_fs.move[/code] (MCP tool [code]project_fs_move[/code]).
## The tool moves a file together with its [code].uid[/code] and [code].import[/code]
## companions, or a whole folder, then rewrites quoted references to the old paths in
## [code].tscn[/code], [code].tres[/code] and [code].import[/code] files, re-points the
## UID cache and any cached resources to the new paths, and rescans the editor
## filesystem.[br]
## [br]
## Safety: both paths go through the toolkit's [code]res://[/code] path guard; the
## project root, [code]res://.godot[/code], [code]project.godot[/code] and the toolkit
## folder are refused; an existing destination is never overwritten; scenes and scripts
## that are open in the editor block the move. Every file that is moved or rewritten is
## first copied to [code]user://mcp_move_backups/<timestamp>/[/code]. References inside
## [code].gd[/code], [code].cfg[/code] and [code]project.godot[/code] are never rewritten;
## they are returned as warnings. Pass [param dry_run] to see the plan without changing
## anything.

const _BACKUP_ROOT: String = "user://mcp_move_backups"
const _COMPANIONS: Array[String] = [".uid", ".import"]
const _REWRITE_EXTENSIONS: Array[String] = ["tscn", "tres", "import"]
const _REPORT_EXTENSIONS: Array[String] = ["gd", "cfg", "godot"]
const _PROTECTED_PATHS: Array[String] = [
	"res://.godot",
	"res://project.godot",
	"res://addons/godot_mcp_toolkit",
]
const _SCAN_TIMEOUT_MS: int = 15000


## Registers [code]project_fs.move[/code] with the live [param registry].
## [param server] is the MCP server node (unused).
func register(registry: MCPToolkitCommandRegistry, server: Node) -> void:
	var opts := MCPToolkitExtensionOptions.new(
		"Move or rename a res:// file or folder like the Godot FileSystem dock: moves .uid/.import companions, " +
		"rewrites references in .tscn/.tres/.import files, updates the UID cache, backs up touched files to " +
		"user://mcp_move_backups, and rescans. Refuses open scenes/scripts and existing destinations. " +
		"Use dry_run:true to preview.") \
		.mark_scene_independent() \
		.guard_project_path("from_path") \
		.guard_project_path("to_path") \
		.with_timeout_ms(60000) \
		.with_input_schema({
			"type": "object",
			"properties": {
				"from_path": {"type": "string", "description": "Existing res:// file or folder to move"},
				"to_path": {"type": "string", "description": "New res:// path (must not exist; same file extension for files)"},
				"dry_run": {"type": "boolean", "default": false, "description": "Return the plan without changing anything"},
			},
			"required": ["from_path", "to_path"],
		})
	registry.add("project_fs.move", _move, opts)


## Moves [param params].from_path to [param params].to_path.
##
## Returns a success envelope with the moved files, the rewritten reference files, the
## backup folder and any warnings, or the plan alone when [code]dry_run[/code] is true.
## Returns a failure envelope when validation fails or the editor is busy.
func _move(params: Dictionary) -> Dictionary:
	var missing: Variant = MCPToolkitError.require(params, ["from_path", "to_path"])
	if missing != null:
		return missing
	var from_path: String = _strip_trailing_slash(str(params["from_path"]).replace("\\", "/"))
	var to_path: String = _strip_trailing_slash(str(params["to_path"]).replace("\\", "/"))
	var dry_run: bool = bool(params.get("dry_run", false))

	var invalid: Variant = _validate(from_path, to_path)
	if invalid != null:
		return invalid

	if not await MCPToolkitSafeSceneOps.wait_for_scan_idle():
		return MCPToolkitError.fail("TIMEOUT", "the editor filesystem is scanning; retry shortly")

	var is_dir: bool = DirAccess.dir_exists_absolute(from_path)

	# old path -> new path for every file that physically moves (companions included).
	var location_map: Dictionary = {}
	if is_dir:
		var inside: Array[String] = []
		_collect_files(from_path, inside, false)
		for file: String in inside:
			location_map[file] = to_path + file.substr(from_path.length())
	else:
		location_map[from_path] = to_path
		for suffix: String in _COMPANIONS:
			if FileAccess.file_exists(from_path + suffix):
				location_map[from_path + suffix] = to_path + suffix

	# Only real resources are referenced by path; companions are not.
	var path_map: Dictionary = {}
	for old: String in location_map:
		if not _is_companion(old):
			path_map[old] = location_map[old]

	var in_use: Variant = _check_in_use(path_map)
	if in_use != null:
		return in_use

	var rewrites: Array[Dictionary] = []
	var warnings: Array[String] = []
	var project_files: Array[String] = []
	_collect_files("res://", project_files, true)
	for file: String in project_files:
		var ext: String = file.get_extension()
		var can_rewrite: bool = ext in _REWRITE_EXTENSIONS
		if not can_rewrite and not (ext in _REPORT_EXTENSIONS):
			continue
		var text: String = FileAccess.get_file_as_string(file)
		if text.is_empty():
			continue
		var hits: int = 0
		for old: String in path_map:
			hits += text.count("\"" + old + "\"")
		if can_rewrite:
			if hits > 0:
				rewrites.append({"file": file, "references": hits})
			continue
		if is_dir:
			hits += text.count("\"" + from_path + "/") + text.count("\"" + from_path + "\"")
		if hits > 0:
			warnings.append("%s mentions a moved path %d time(s); it is not rewritten, update it by hand" % [file, hits])

	var open_scenes: PackedStringArray = EditorInterface.get_open_scenes()
	for entry: Dictionary in rewrites:
		var file: String = entry["file"]
		if file in open_scenes:
			return MCPToolkitError.fail("PATH_IN_USE",
				"%s references a moved file and is open in the editor" % file,
				"Save and close it with scene_close, then retry.")

	var moved_list: Array[String] = []
	for old: String in location_map:
		moved_list.append("%s -> %s" % [old, location_map[old]])

	if dry_run:
		return MCPToolkitSuccess.ok({
			"dry_run": true,
			"is_folder": is_dir,
			"moves": moved_list,
			"rewrites": rewrites,
			"warnings": warnings,
		})

	# 1. Back up everything that will be moved or rewritten.
	var backup_dir: String = "%s/%s" % [_BACKUP_ROOT, Time.get_datetime_string_from_system().replace(":", "-")]
	var to_back_up: Array[String] = []
	for old: String in location_map:
		to_back_up.append(old)
	for entry: Dictionary in rewrites:
		if not (entry["file"] in to_back_up):
			to_back_up.append(entry["file"])
	for file: String in to_back_up:
		var backup_path: String = backup_dir + "/" + file.trim_prefix("res://")
		DirAccess.make_dir_recursive_absolute(backup_path.get_base_dir())
		var copy_err: Error = DirAccess.copy_absolute(file, backup_path)
		if copy_err != OK:
			return MCPToolkitError.fail("WRITE_FAILED",
				"backup of %s failed (error %d); nothing was moved" % [file, copy_err])

	# 2. Remember UIDs before the files leave their old paths.
	var uids: Dictionary = {}
	for old: String in path_map:
		var uid: int = ResourceLoader.get_resource_uid(old)
		if uid != ResourceUID.INVALID_ID:
			uids[old] = uid

	# 3. Move.
	var parent_err: Error = DirAccess.make_dir_recursive_absolute(to_path.get_base_dir())
	if parent_err != OK:
		return MCPToolkitError.fail("CREATE_DIR_FAILED",
			"could not create %s (error %d); nothing was moved" % [to_path.get_base_dir(), parent_err])
	if is_dir:
		var dir_err: Error = DirAccess.rename_absolute(from_path, to_path)
		if dir_err != OK:
			return MCPToolkitError.fail("FAILED", "renaming the folder failed (error %d); nothing was moved" % dir_err)
	else:
		var file_err: Error = DirAccess.rename_absolute(from_path, to_path)
		if file_err != OK:
			return MCPToolkitError.fail("FAILED", "renaming the file failed (error %d); nothing was moved" % file_err)
		for old: String in location_map:
			if old == from_path:
				continue
			if DirAccess.rename_absolute(old, location_map[old]) != OK:
				warnings.append("companion %s could not be moved" % old)

	# 4. Rewrite references (files inside a moved folder are read at their new location).
	var rewritten: Array[Dictionary] = []
	for entry: Dictionary in rewrites:
		var original: String = entry["file"]
		var current: String = location_map.get(original, original)
		var text: String = FileAccess.get_file_as_string(current)
		for old: String in path_map:
			text = text.replace("\"" + old + "\"", "\"" + str(path_map[old]) + "\"")
		var out := FileAccess.open(current, FileAccess.WRITE)
		if out == null:
			warnings.append("could not rewrite %s (restore it from the backup)" % current)
			continue
		out.store_string(text)
		out.close()
		rewritten.append({"file": current, "references": entry["references"]})

	# 5. Point the UID cache and cached resources at the new paths.
	for old: String in uids:
		var uid: int = uids[old]
		if ResourceUID.has_id(uid):
			ResourceUID.set_id(uid, path_map[old])
		else:
			ResourceUID.add_id(uid, path_map[old])
	for old: String in path_map:
		if ResourceLoader.has_cached(old):
			var cached: Resource = ResourceLoader.get_cached_ref(old)
			if cached != null:
				cached.take_over_path(path_map[old])

	# 6. Rescan so the FileSystem dock and the class cache see the new layout.
	var scanned: bool = await _rescan()
	if not scanned:
		warnings.append("the filesystem rescan did not finish in time; call editor_refresh")

	return MCPToolkitSuccess.ok({
		"is_folder": is_dir,
		"from_path": from_path,
		"to_path": to_path,
		"moves": moved_list,
		"rewritten": rewritten,
		"uids_updated": uids.size(),
		"backup_dir": backup_dir,
		"warnings": warnings,
	})


## Returns a failure envelope when [param from_path] -> [param to_path] is not an
## allowed move, or null when it is.
func _validate(from_path: String, to_path: String) -> Variant:
	if from_path == to_path:
		return MCPToolkitError.fail("INVALID_PARAMS", "from_path and to_path are the same")
	for path: String in [from_path, to_path]:
		if path == "res:" or path == "res://":
			return MCPToolkitError.fail("FOLDER_PROTECTED", "the project root cannot be moved or replaced")
		for protected: String in _PROTECTED_PATHS:
			if path == protected or path.begins_with(protected + "/"):
				return MCPToolkitError.fail("FOLDER_PROTECTED", "%s is protected" % protected)
	if _is_companion(from_path) or _is_companion(to_path):
		return MCPToolkitError.fail("INVALID_PARAMS",
			".uid and .import files move together with their resource; pass the resource path instead")
	var from_is_dir: bool = DirAccess.dir_exists_absolute(from_path)
	if not from_is_dir and not FileAccess.file_exists(from_path):
		return MCPToolkitError.fail("NOT_FOUND", "nothing exists at %s" % from_path)
	if DirAccess.dir_exists_absolute(to_path) or FileAccess.file_exists(to_path):
		return MCPToolkitError.fail("ALREADY_EXISTS", "%s already exists" % to_path,
			"Pick a new name. For a case-only rename on Windows, move to a temporary name first.")
	if to_path.begins_with(from_path + "/"):
		return MCPToolkitError.fail("INVALID_PARAMS", "a folder cannot be moved into itself")
	if not from_is_dir and from_path.get_extension() != to_path.get_extension():
		return MCPToolkitError.fail("INVALID_PARAMS",
			"changing the file extension (%s -> %s) is not supported" % [from_path.get_extension(), to_path.get_extension()])
	return null


## Returns a failure envelope when any resource in [param path_map] is open as a
## scene tab or in the script editor, or null when none is.
func _check_in_use(path_map: Dictionary) -> Variant:
	var open_scenes: PackedStringArray = EditorInterface.get_open_scenes()
	for old: String in path_map:
		if old in open_scenes:
			return MCPToolkitError.fail("PATH_IN_USE", "scene %s is open in the editor" % old,
				"Save and close it with scene_close, then retry.")
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	if script_editor != null:
		for script: Script in script_editor.get_open_scripts():
			if script.resource_path in path_map:
				return MCPToolkitError.fail("PATH_IN_USE", "script %s is open in the script editor" % script.resource_path,
					"Close its tab in the Godot script editor, then retry.")
	return null


## Appends every file under [param dir_path] to [param out]. With
## [param for_scan] true, hidden folders, folders holding a [code].gdignore[/code]
## and the toolkit folder are skipped.
func _collect_files(dir_path: String, out: Array[String], for_scan: bool) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.include_hidden = not for_scan
	if for_scan and dir_path != "res://" and dir.file_exists(".gdignore"):
		return
	for file_name: String in dir.get_files():
		out.append(dir_path.path_join(file_name))
	for sub_name: String in dir.get_directories():
		var sub_path: String = dir_path.path_join(sub_name)
		if for_scan and (sub_name.begins_with(".") or sub_path == "res://addons/godot_mcp_toolkit"):
			continue
		_collect_files(sub_path, out, for_scan)


## Starts a full filesystem scan and waits for it. Returns false on timeout.
func _rescan() -> bool:
	var efs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if efs == null:
		return false
	efs.scan()
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame
	var start: int = Time.get_ticks_msec()
	while efs.is_scanning():
		if Time.get_ticks_msec() - start > _SCAN_TIMEOUT_MS:
			return false
		await tree.create_timer(0.1).timeout
	return true


func _is_companion(path: String) -> bool:
	for suffix: String in _COMPANIONS:
		if path.ends_with(suffix):
			return true
	return false


func _strip_trailing_slash(path: String) -> String:
	if path.ends_with("/") and path != "res://":
		return path.substr(0, path.length() - 1)
	return path
