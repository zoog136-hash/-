extends SceneTree
## 가호 owner contract: pinned by git blob where source text exists; an
## exported app (no source text) is not reported as a mismatch.
##   godot --headless --path <repo> --script res://tests/protection_owner_contract_test.gd
const BINDINGS = preload("res://scripts/crafting/patch523_protection_bindings.gd")
const OWNER_TX = preload("res://scripts/crafting/patch523_owner_transactions.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("PROTECTION_OWNER_CONTRACT_FAIL: " + label)

func _initialize() -> void:
	var owner_script: Script = load("res://scripts/protection/protection523_runtime.gd") if ResourceLoader.exists("res://scripts/protection/protection523_runtime.gd") else null
	if owner_script != null:
		check(OWNER_TX.reviewed_script(owner_script, BINDINGS.REVIEWED_OWNER_BLOB), "the reviewed owner source matches its pinned blob")
	check(OWNER_TX.quest_ownership_provider() != null, "the reviewed quest ownership provider is accepted")
	var changed := GDScript.new()
	changed.source_code = "extends RefCounted\nvar changed := 1\n"
	check(not OWNER_TX.reviewed_script(changed, BINDINGS.REVIEWED_OWNER_BLOB), "a changed owner source is a mismatch")
	var compiled := GDScript.new()
	check(compiled.get_source_code().is_empty() and OWNER_TX.reviewed_script(compiled, BINDINGS.REVIEWED_OWNER_BLOB), "no source text (exported app) is not a mismatch")
	check(not OWNER_TX.reviewed_script(null, BINDINGS.REVIEWED_OWNER_BLOB), "no owner script is a mismatch")
	print("PROTECTION_OWNER_CONTRACT_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "owner_found": owner_script != null}))
	quit(0 if failures.is_empty() else 1)
