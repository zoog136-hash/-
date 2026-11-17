extends SceneTree
## Bag order compares item instance ids that are numeric (old saves) or
## 32-hex digests (current); int() on a digest logged an engine error on every
## sort comparison (2026-11-17 523.602, ustring.cpp:2281).
##   godot --headless --path <repo> --script res://tests/inventory_instance_order_test.gd
const INVENTORY = preload("res://scripts/ui/renewal_inventory.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("INVENTORY_INSTANCE_ORDER_FAIL: " + label)

func _initialize() -> void:
	check(INVENTORY._instance_before("9", "10"), "numeric ids keep numeric order")
	check(not INVENTORY._instance_before("10", "9"), "numeric order is strict")
	check(INVENTORY._instance_before("42", "315d74c1e707f3b68400ab32ddcdc566"), "numeric ids sort before digests")
	check(not INVENTORY._instance_before("315d74c1e707f3b68400ab32ddcdc566", "42"), "digest after numeric")
	check(INVENTORY._instance_before("0a", "315d74c1e707f3b68400ab32ddcdc566"), "shorter text id first")
	check(INVENTORY._instance_before("215d74c1e707f3b68400ab32ddcdc566", "315d74c1e707f3b68400ab32ddcdc566"), "same-length digests compare as text")
	check(not INVENTORY._instance_before("315d74c1e707f3b68400ab32ddcdc566", "315d74c1e707f3b68400ab32ddcdc566"), "equal ids are not before each other")
	check(INVENTORY._instance_before("", "1"), "empty id (stackable) sorts first")
	var ids: Array[String] = ["315d74c1e707f3b68400ab32ddcdc566", "10", "", "9", "015d74c1e707f3b68400ab32ddcdc566"]
	ids.sort_custom(INVENTORY._instance_before)
	check(ids == ["", "9", "10", "015d74c1e707f3b68400ab32ddcdc566", "315d74c1e707f3b68400ab32ddcdc566"], "mixed ids sort without engine errors: " + str(ids))
	print("INVENTORY_INSTANCE_ORDER_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
