extends SceneTree
## Stored definition tables (user://current523_bake) are keyed by
## STORE_FORMAT instead of the reader's whole script, so ordinary edits of
## current523_definition_rows.gd no longer make every phone re-convert every
## table during play. This test keeps that safe: the code between
## [store-format-begin] and [store-format-end] decides what a stored table
## holds; when it changes, STORE_FORMAT must change too.
##   godot --headless --path <repo> --script res://tests/definition_store_format_test.gd
const ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
const ROWS_PATH := "res://scripts/resources/current523_definition_rows.gd"
## STORE_FORMAT -> SHA-256 of the format region text. Add a new entry (with a
## new STORE_FORMAT) when the region changes; never edit an existing hash.
const RECORDED: Dictionary = {
	"twilight.current523.definition-store.v1": "c4f51cdc3daab371b5a94987d3227dd15642c3fddd01d665674937b3073b8aa3",
}
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("DEFINITION_STORE_FORMAT_FAIL: " + label)

func _initialize() -> void:
	var text: String = FileAccess.get_file_as_string(ROWS_PATH)
	var begin: int = text.find("## [store-format-begin]")
	var end: int = text.find("## [store-format-end]")
	check(begin > 0 and end > begin, "the store format region is marked")
	var digest: String = text.substr(begin, end - begin).sha256_text() if begin > 0 and end > begin else ""
	check(RECORDED.has(ROWS.STORE_FORMAT), "STORE_FORMAT %s is recorded" % ROWS.STORE_FORMAT)
	check(RECORDED.get(ROWS.STORE_FORMAT, "") == digest, "stored table format code changed (sha %s): give it a new STORE_FORMAT and record it" % digest)
	# Keys exist only for a verified original archive on this device.
	if not ROWS.verified_key().is_empty():
		check(ROWS._bake_key("Bonus") != ROWS._bake_key("SpellClass"), "each table has its own key")
	check(not ROWS.BAKE_CODE.has(ROWS_PATH), "the reader's whole script is not part of the stored table key")
	print("DEFINITION_STORE_FORMAT_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "region_sha256":digest}))
	quit(0 if failures.is_empty() else 1)
