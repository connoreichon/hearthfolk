class_name HFTestCase
extends RefCounted
## Clase base para tests. El runner ejecuta todo método que empiece por "test_".

var failures: Array[String] = []
var checks: int = 0
var current: String = ""


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_true(condition: bool, message: String = "") -> void:
	checks += 1
	if not condition:
		failures.append("%s: assert_true falló. %s" % [current, message])


func assert_false(condition: bool, message: String = "") -> void:
	assert_true(not condition, message)


func assert_eq(got: Variant, expected: Variant, message: String = "") -> void:
	checks += 1
	if got != expected:
		failures.append(
			"%s: obtenido %s, esperado %s. %s" % [current, str(got), str(expected), message]
		)


func assert_almost_eq(
	got: float, expected: float, epsilon: float = 0.0001, message: String = ""
) -> void:
	checks += 1
	if absf(got - expected) > epsilon:
		failures.append(
			"%s: obtenido %f, esperado %f (±%f). %s" % [current, got, expected, epsilon, message]
		)


func assert_ne(got: Variant, not_expected: Variant, message: String = "") -> void:
	checks += 1
	if got == not_expected:
		failures.append(
			"%s: %s no debía ser igual a %s. %s" % [current, str(got), str(not_expected), message]
		)
