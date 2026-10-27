@tool
class_name MCPToolkitSinfulnessInputTools
extends MCPToolkitExtension
## Adds input actions to the project's Input Map inside the editor.
##
## Registers [code]sininput.add_action[/code] (MCP tool [code]sininput_add_action[/code]).
## Eager (no group), because the built-in input_map group does not show up in every client.
## The events are real InputEventKey / InputEventJoypadButton objects saved with
## ProjectSettings.save(), so project.godot is never edited as text.


## Registers the input command with the live [param registry].
## [param server] is the MCP server node (unused).
func register(registry: MCPToolkitCommandRegistry, server: Node) -> void:
	var add_opts := MCPToolkitExtensionOptions.new(
		"Add an input action to the Input Map and save project.godot. 'action' is the name, " +
		"'physical_keys' a list of physical keycodes (e.g. 49 for key 1), 'joy_buttons' a list of " +
		"JoyButton indexes (e.g. 12 = D-pad down, 14 = D-pad right). Refuses an existing action " +
		"unless 'replace' is true.") \
		.with_input_schema({
			"type": "object",
			"properties": {
				"action": {"type": "string"},
				"physical_keys": {"type": "array", "items": {"type": "integer"}},
				"joy_buttons": {"type": "array", "items": {"type": "integer"}},
				"deadzone": {"type": "number", "default": 0.2},
				"replace": {"type": "boolean", "default": false},
			},
			"required": ["action"],
		})
	registry.add("sininput.add_action", _add_action, add_opts)


func _add_action(params: Dictionary) -> Dictionary:
	var missing: Variant = MCPToolkitError.require(params, ["action"])
	if missing != null:
		return missing
	var action: String = str(params["action"])
	var setting: String = "input/%s" % action
	if ProjectSettings.has_setting(setting) and not bool(params.get("replace", false)):
		return MCPToolkitError.fail("ALREADY_EXISTS", "action '%s' already exists" % action, "Pass replace:true to overwrite it.")

	var events: Array = []
	for code: Variant in params.get("physical_keys", []):
		var key := InputEventKey.new()
		key.device = -1
		key.physical_keycode = int(code) as Key
		events.append(key)
	for button: Variant in params.get("joy_buttons", []):
		var joy := InputEventJoypadButton.new()
		joy.device = -1
		joy.button_index = int(button) as JoyButton
		events.append(joy)
	if events.is_empty():
		return MCPToolkitError.fail("INVALID_PARAMS", "give at least one physical key or joy button")

	ProjectSettings.set_setting(setting, {"deadzone": float(params.get("deadzone", 0.2)), "events": events})
	var result: Error = ProjectSettings.save()
	if result != OK:
		return MCPToolkitError.fail("SAVE_FAILED", "ProjectSettings.save() returned %s" % error_string(result))
	var described: Array = []
	for event: InputEvent in events:
		described.append(event.as_text())
	return MCPToolkitSuccess.ok({"action": action, "events": described})
