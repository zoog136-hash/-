extends SceneTree

const SGC := preload("res://scripts/skills/spell_group_conversion.gd")
const ADAPTER := preload("res://scripts/skills/player_skills523.gd")
const ROWS := preload("res://scripts/resources/current523_definition_rows.gd")

class Catalog extends RefCounted:
	var by_id: Dictionary = {}
	var source523: Object

class Service extends RefCounted:
	var catalog: Object

class Host extends Node:
	var job_class := "요정"
	var original_skills: Object

class ConversionProbe extends "res://scripts/skills/spell_group_conversion.gd":
	var source_row: Dictionary = {}
	var source_reads: int = 0
	var source_available: bool = true
	func _bound_source_generation() -> int:
		return ROWS.cache_generation() if source_available else -1
	func _read_verified_spell_row(id: int) -> Dictionary:
		source_reads += 1
		return source_row.duplicate(true) if id == int(source_row.get("ID", 0)) else {}

var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("SPELL_GROUP_BOUND_MEMO_FAIL: ", label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var original := {"ID":77,"Name":"test","TestSpell":false,"TargetKindID":1,"TargettingTypeID":1,
		"IsRequireSpellGroupMastery":true,"SpellGroupID":5}
	var document: String = JSON.stringify(original)
	var source_row: Dictionary = JSON.parse_string(document)
	var binding := {"spell_id":77,"row_sha256":document.sha256_text()}
	var bonus := {"link":{},"bonus":{"Value":1,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0},
		"type":{"Name":"Synthetic"},"unit":{"Name":"Value"}}
	var profile := {"row":source_row.duplicate(true),"target_kind":{"ID":1},"targeting_type":{"ID":1},
		"learn_limits":[],"bonuses":[],"buffs":[{"row":{},"bonuses":[bonus]}],"costs":[],"cast_groups":[]}
	var adapter = ADAPTER.new()
	adapter.bindings = {"source_zip_sha256":SGC.SOURCE_SHA,"skills":{"s1":binding}}
	adapter.profiles = {"s1":profile}
	var record := {"id":"s1"}
	var catalog := Catalog.new()
	catalog.source523 = adapter
	catalog.by_id = {"s1":record}
	var service := Service.new()
	service.catalog = catalog
	var host := Host.new()
	host.original_skills = service
	root.add_child(host)
	var conversion := ConversionProbe.new()
	conversion.world = host
	conversion.source_row = source_row
	conversion.members = {77:source_row.duplicate(true)}
	conversion.source_input_identity = {"kind":"twilight.spell-group.current523.input.v1",
		"source_snapshot":"patch523","archive_sha256":SGC.SOURCE_SHA,"source_sha256":SGC.SOURCE_SHA}
	conversion.state.classes = {"요정":{"group":5},"마법사":{"group":1}}

	check(conversion.source_id(record) == 0, "missing document rejects")
	var rejected: Variant = conversion._bound_memo.get("s1")
	check(rejected is Dictionary and conversion.source_id(record) == 0 and is_same(conversion._bound_memo.get("s1"),rejected),
		"identical invalid document reuses its rejection")
	profile.row_json = document
	check(conversion.source_id(record) == 77 and conversion.source_reads == 1, "adding a valid document in place admits it")
	check(conversion.source_id(record) == 77 and conversion.source_reads == 1, "unchanged verified row reuses the source lookup")
	profile.row_json = StringName(document)
	check(conversion.source_id(record) == 0, "an equal-looking value of the wrong type rejects")
	profile.row_json = document
	check(conversion.source_id(record) == 77, "restored document can be verified again")
	var valid_reads := conversion.source_reads
	bonus.unit.Name = 1
	check(conversion.source_id(record) == 0 and conversion.source_reads == valid_reads, "nested bonus changes are checked without repeating the row lookup")
	bonus.unit.Name = "Value"
	check(conversion.source_id(record) == 77 and conversion.source_reads == valid_reads, "restored nested bonus is admitted without a stale refusal")
	profile.target_kind.ID = 2
	check(conversion.source_id(record) == 0, "in-place target-kind change rejects")
	profile.target_kind.ID = {}
	check(conversion.source_id(record) == 0, "invalid target-kind type rejects")
	profile.target_kind.ID = 1
	profile.row.Name = "changed"
	check(conversion.source_id(record) == 0, "in-place row body change rejects")
	profile.row.Name = source_row.Name
	conversion.members[77].SpellGroupID = 4
	check(conversion.source_id(record) == 0, "in-place group member change rejects")
	conversion.members[77].SpellGroupID = source_row.SpellGroupID
	conversion.source_input_identity.source_sha256 = "wrong"
	check(conversion.source_id(record) == 0, "in-place input identity change rejects")
	conversion.source_input_identity.source_sha256 = SGC.SOURCE_SHA
	check(conversion.allows(record) and conversion.source_reads == valid_reads, "restoring live gates does not repeat original row decoding")
	conversion.state.classes["요정"].group = 4
	check(not conversion.allows(record) and conversion.source_reads == valid_reads, "changing selected group applies to an already cached row")
	host.job_class = "마법사"
	conversion.state.classes["마법사"].group = 5
	check(conversion.allows(record), "active character's group is read live")
	host.job_class = "요정"
	check(not conversion.allows(record), "returning to previous character's group keeps its restriction")
	binding.row_sha256 = "a".repeat(64)
	check(conversion.source_id(record) == 0, "in-place binding digest change rejects")
	binding.row_sha256 = document.sha256_text()
	check(conversion.source_id(record) == 77, "restoring the binding is admitted")
	valid_reads = conversion.source_reads
	adapter.revision += 1
	check(conversion.source_id(record) == 77 and conversion.source_reads == valid_reads + 1, "adapter revision starts a new row lifetime")
	ROWS.reset()
	check(conversion.source_id(record) == 77 and conversion.source_reads == valid_reads + 2, "definition reset starts a new row lifetime")
	var replacement = ADAPTER.new()
	replacement.bindings = adapter.bindings
	replacement.profiles = adapter.profiles
	replacement.revision = adapter.revision
	catalog.source523 = replacement
	check(conversion.source_id(record) == 77 and conversion.source_reads == valid_reads + 3, "a different adapter does not retain the previous cache")
	conversion.source_available = false
	check(conversion.source_id(record) == 0 and conversion.source_reads == valid_reads + 3, "unavailable archive rejects a previously verified document")
	conversion.source_available = true
	conversion.source_row = {}
	check(conversion.source_id(record) == 0 and conversion.source_reads == valid_reads + 4, "unavailable row is not verified")
	conversion.source_row = source_row
	check(conversion.source_id(record) == 77 and conversion.source_reads == valid_reads + 5, "newly readable row has no stale rejection")
	host.queue_free()
	print("SPELL_GROUP_BOUND_MEMO_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
