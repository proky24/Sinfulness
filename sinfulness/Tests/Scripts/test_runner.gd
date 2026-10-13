extends Node
## Runs every res://Tests/Scripts/Cases/test_*.gd case when the scene starts.
##
## Prints one "[TEST]" line per test and a "[TEST] SUMMARY" line at the end, and keeps
## the totals in script variables so they can be read while the game runs.

const CASES_DIR: String = "res://Tests/Scripts/Cases"
const LOG_PREFIX: String = "[TEST]"

## Only case files whose name contains this text are run. Empty runs all.
@export var filter: String = ""
@export var run_on_ready: bool = true

var passed: int = 0
var failed: int = 0
var skipped: int = 0
var finished: bool = false
var failures: Array[String] = []


func _ready() -> void:
	if run_on_ready:
		run_tests.call_deferred(filter)


func run_tests(name_filter: String = "") -> void:
	passed = 0
	failed = 0
	skipped = 0
	finished = false
	failures.clear()
	print("%s START filter='%s'" % [LOG_PREFIX, name_filter])
	# The first frames after launch are long; let them pass so timer-based tests are not skewed.
	await get_tree().process_frame
	await get_tree().process_frame

	var files: PackedStringArray = DirAccess.get_files_at(CASES_DIR)
	files.sort()
	for file_name: String in files:
		if not file_name.begins_with("test_") or not file_name.ends_with(".gd"):
			continue
		if not name_filter.is_empty() and not file_name.contains(name_filter):
			continue
		await _run_case(CASES_DIR.path_join(file_name))

	finished = true
	print("%s SUMMARY passed=%d failed=%d skipped=%d" % [LOG_PREFIX, passed, failed, skipped])


func _run_case(path: String) -> void:
	var case_script: GDScript = load(path) as GDScript
	if case_script == null:
		_record_failure(path, "could not load the script")
		return
	var instance: Variant = case_script.new()
	if not (instance is TestCase):
		_record_failure(path, "does not extend TestCase")
		return
	var test_case: TestCase = instance
	test_case.tree = get_tree()

	for method: Dictionary in case_script.get_script_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue
		var label: String = "%s:%s" % [path.get_file().get_basename(), method_name]
		test_case.begin_test()
		await test_case.call(method_name)
		if not test_case.get_skip_reason().is_empty():
			skipped += 1
			print("%s SKIP %s (%s)" % [LOG_PREFIX, label, test_case.get_skip_reason()])
		elif test_case.get_failures().is_empty():
			passed += 1
			print("%s PASS %s" % [LOG_PREFIX, label])
		else:
			_record_failure(label, " | ".join(test_case.get_failures()))


func _record_failure(label: String, message: String) -> void:
	failed += 1
	failures.append("%s: %s" % [label, message])
	print("%s FAIL %s: %s" % [LOG_PREFIX, label, message])
