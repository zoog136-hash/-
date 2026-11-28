extends SceneTree
## spell_group_conversion._accepted_bound_source_id(): the profile validation
## (row SHA-256, JSON parse, bonus checks, original row) is kept per skill
## while the adapter revision, the profile/binding/member objects, the input
## identity and the definition cache generation are the same, and is done
## again when any of them changes. Runs without the private archive.
const SGC = preload("res://scripts/skills/spell_group_conversion.gd")
const ADAPTER = preload("res://scripts/skills/player_skills523.gd")
const ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []

class Catalog extends RefCounted:
	var by_id: Dictionary = {}
	var source523: Object
class Service extends RefCounted:
	var catalog: Object
class Host extends Node:
	var original_skills: Object

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("SPELL_GROUP_BOUND_MEMO_FAIL: ", label)

func _initialize() -> void:
	var adapter = ADAPTER.new()
	var row: Dictionary = {"ID": 77, "Name": "test"}
	adapter.bindings = {"source_zip_sha256": SGC.SOURCE_SHA, "skills": {"s1": {"spell_id": 77, "row_sha256": "a".repeat(64)}}}
	# row_json missing: _profile_problem rejects it, so the answer is 0.
	adapter.profiles = {"s1": {"row": row}}
	var catalog := Catalog.new()
	catalog.by_id = {"s1": {"id": "s1"}}
	catalog.source523 = adapter
	var service := Service.new()
	service.catalog = catalog
	var host := Host.new()
	host.original_skills = service
	root.add_child(host)
	var conversion = SGC.new()
	conversion.world = host
	var record: Dictionary = {"id": "s1"}
	check(conversion.source_id(record) == 0, "a profile the adapter rejects has no bound source id")
	var first: Variant = conversion._bound_memo.get("s1")
	check(first is Array and first[7] == 0, "the answer is kept for the skill")
	check(conversion.source_id(record) == 0 and is_same(conversion._bound_memo.get("s1"), first), "the same inputs reuse the kept answer")
	adapter.revision += 1
	conversion.source_id(record)
	var after_revision: Variant = conversion._bound_memo.get("s1")
	check(not is_same(after_revision, first) and after_revision[1] == adapter.revision, "an adapter revision validates again")
	adapter.profiles = {"s1": {"row": row.duplicate()}}
	conversion.source_id(record)
	check(not is_same(conversion._bound_memo.get("s1"), after_revision), "a replaced profile object validates again")
	var before_members: Variant = conversion._bound_memo.get("s1")
	conversion.members = {}
	conversion.source_id(record)
	check(not is_same(conversion._bound_memo.get("s1"), before_members), "replaced group members validate again")
	var before_reset: Variant = conversion._bound_memo.get("s1")
	ROWS.reset()
	conversion.source_id(record)
	check(not is_same(conversion._bound_memo.get("s1"), before_reset), "a definition cache reset validates again")
	var source: String = FileAccess.get_file_as_string("res://scripts/skills/spell_group_conversion.gd")
	check(source.contains("not adapter._profile_problem(canonical_id,profile,binding).is_empty()"), "the kept answer comes from the unchanged validation")
	host.queue_free()
	print("SPELL_GROUP_BOUND_MEMO_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
