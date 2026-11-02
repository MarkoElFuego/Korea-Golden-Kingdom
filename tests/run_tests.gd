extends SceneTree
## Runs every tests/test_*.gd. Usage, from the project folder:
##   <Godot console exe> --headless -s res://tests/run_tests.gd
## Prints one line per test and exits with code 1 if anything fails.

const TESTS_DIR := "res://tests"


## Counts engine and script errors, so a test that crashes counts as failed.
class ErrorCounter extends Logger:
	var errors := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors += 1


func _initialize() -> void:
	var counter := ErrorCounter.new()
	OS.add_logger(counter)

	var passed := 0
	var failed := 0
	for file in _test_files():
		var script: GDScript = load(TESTS_DIR + "/" + file)
		if script == null or not script.can_instantiate():
			print("FAIL  %s: could not load" % file)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var test: Object = script.new()
			var errors_before := counter.errors
			test.call(name)
			var problems: Array[String] = test.failures.duplicate()
			if counter.errors > errors_before:
				problems.append("engine/script error during the test (see output above)")
			if test.checks == 0 and problems.is_empty():
				problems.append("no checks ran")
			if problems.is_empty():
				print("ok    %s :: %s" % [file, name])
				passed += 1
			else:
				print("FAIL  %s :: %s" % [file, name])
				for p in problems:
					print("        - " + p)
				failed += 1

	print("")
	print("%d passed, %d failed" % [passed, failed])
	OS.remove_logger(counter)
	quit(1 if failed > 0 else 0)


func _test_files() -> Array[String]:
	var result: Array[String] = []
	for file in DirAccess.get_files_at(TESTS_DIR):
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_base.gd":
			result.append(file)
	result.sort()
	return result
