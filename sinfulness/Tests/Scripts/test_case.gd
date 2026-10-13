class_name TestCase extends RefCounted
## Base class for test cases run by TestRunner.
##
## Put a script that extends TestCase in res://Tests/Scripts/Cases/ with a file name
## starting with "test_". Every method whose name starts with "test_" is run in order.
## Test methods may use await (for example wait_seconds()).

var tree: SceneTree

var _failures: Array[String] = []
var _skip_reason: String = ""


func begin_test() -> void:
	_failures.clear()
	_skip_reason = ""


func get_failures() -> Array[String]:
	return _failures


func get_skip_reason() -> String:
	return _skip_reason


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_failures.append("expected true. " + message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_failures.append("expected false. " + message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	var equal: bool = typeof(actual) == typeof(expected) and actual == expected
	if not equal and _is_number(actual) and _is_number(expected):
		equal = is_equal_approx(float(actual), float(expected))
	if not equal:
		_failures.append("expected %s, got %s. %s" % [str(expected), str(actual), message])


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		_failures.append("expected a value, got null. " + message)


## Marks the current test as skipped. Return from the test right after calling it.
func skip(reason: String) -> void:
	_skip_reason = reason


## Returns the autoload node called [param autoload_name], or null if it is not registered.
func get_autoload(autoload_name: String) -> Node:
	return tree.root.get_node_or_null(autoload_name)


func wait_seconds(seconds: float) -> void:
	await tree.create_timer(seconds).timeout


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
