extends RefCounted
## Base for test files: every test_*.gd extends this file and adds methods named test_*.

var failures: Array[String] = []
var checks := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	checks += 1
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func check_near(actual: float, expected: float, message: String, tolerance := 0.001) -> void:
	checks += 1
	if absf(actual - expected) > tolerance:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
