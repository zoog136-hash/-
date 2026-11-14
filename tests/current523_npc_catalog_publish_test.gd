extends SceneTree
## Admitting one more monster kind costs only the new rows: owner indexes grow
## in place (equal to a full rebuild), the payload digest is computed when
## read, spawn provenance uses the admitted-ID digest, policy files are read once.
##   godot --headless --path <repo> --script res://tests/current523_npc_catalog_publish_test.gd
const CATALOG = preload("res://scripts/monsters/patch523_npc_catalog.gd")
const PROJECTION = preload("res://scripts/monsters/current523_npc_input_projection.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("NPC_CATALOG_PUBLISH_FAIL: " + label)

static func _entry(row: Dictionary, position: int) -> Dictionary:
	return {"source_row_1based": position, "row": row}

## Content shaped like current523_npc_input_projection._result(): each table a
## fresh shallow copy, earlier entries first.
static func _content(npc_ids: Array) -> Dictionary:
	var attacks: Dictionary = {}
	var classes: Dictionary = {}
	var bonus: Dictionary = {}
	for npc: int in npc_ids:
		classes[str(npc)] = SHARED.get_or_add("c%d" % npc, _entry({"ID": npc, "HP": npc * 10}, npc))
		for slot: int in 2:
			var id: int = npc * 10 + slot
			attacks[str(id)] = SHARED.get_or_add("a%d" % id, _entry({"ID": id, "NpcClassID": npc, "Range": 2}, id))
		# A spell bonus shared by every kind (the same selected entry).
		bonus["77"] = SHARED.get_or_add("b77", _entry({"ID": 77, "SpellClassID": 5}, 77))
	return {"kind": "patch523_npc_spell_catalog", "input_kind": "twilight.current523.npc-input.v1",
		"boss_npc_ids": npc_ids.duplicate(), "tables": {"NpcClass": classes, "NpcAttack": attacks, "SpellBonus": bonus}}

static var SHARED: Dictionary = {}

func _initialize() -> void:
	# Incremental owner indexes == a full rebuild of the final content.
	var grown := CATALOG.new()
	for count: int in range(1, 6):
		grown._publish_original(_content(range(1, count + 1)))
	var full := CATALOG.new()
	full._publish_original(_content([1, 2, 3, 4, 5]))
	check(grown.indexes == full.indexes, "growing one kind at a time gives the same owner indexes")
	check(grown.indexes.NpcAttack["3"].size() == 2 and grown.indexes.SpellBonus["5"].size() == 1, "each row is indexed once")
	# A selection that lost an earlier key (reset) rebuilds in full.
	grown._publish_original(_content([2, 4]))
	var fresh := CATALOG.new()
	fresh._publish_original(_content([2, 4]))
	check(grown.indexes == fresh.indexes and not grown.indexes.NpcAttack.has("1"), "a non-superset selection rebuilds the indexes")
	# Indexes assigned from outside are never extended in place.
	var foreign := CATALOG.new()
	foreign.indexes = {"NpcAttack": {"9": [{"ID": 1}]}}
	foreign._publish_original(_content([1]))
	check(not foreign.indexes.NpcAttack.has("9") and foreign.indexes == _indexes_of([1]), "foreign indexes are rebuilt")
	# Payload digest: computed on read, exactly the old serialisation.
	check(grown.source_model_sha256 == JSON.stringify(grown.content, "", true, true).sha256_text(), "payload digest equals the full sorted JSON digest")
	# Spawn provenance digest: admitted IDs + source archive, order-free.
	var ids := CATALOG.new()
	ids.admitted_source_identities = {"3": {}, "1": {}}
	ids._ids_sha_count = -1
	var first: String = ids.admitted_registry_ids_sha256()
	check(first == (CATALOG.SOURCE_SHA + "|" + JSON.stringify([1, 3])).sha256_text(), "admitted-ID digest is SHA-256 of source SHA and sorted IDs")
	check(ids.admitted_registry_ids_sha256() == first, "unchanged admissions keep the digest")
	ids.admitted_source_identities["2"] = {}
	ids._ids_sha_count = -1
	check(ids.admitted_registry_ids_sha256() != first, "a new admission changes the digest")
	# Policy files: one parse + SHA per path for the run.
	var policy: Dictionary = CATALOG._policy_file(CATALOG.NUMERIC_INPUT_POLICY_PATH)
	check(not policy.is_empty() and policy.sha256 == FileAccess.get_sha256(CATALOG.NUMERIC_INPUT_POLICY_PATH), "policy SHA-256 matches the file")
	check(is_same(CATALOG._policy_file(CATALOG.NUMERIC_INPUT_POLICY_PATH), policy), "the second read reuses the first parse")
	check(CATALOG._policy_file("res://data/monsters/__missing_policy__.json").is_empty(), "a missing policy reads as empty")
	# Re-keeping a selected row keeps its entry (no deep copy, same object).
	var projection := PROJECTION.new()
	var row: Dictionary = {"ID": 7.0, "Value": 1.0}
	check(projection._keep("T", row, [4]), "a row is kept")
	var kept: Dictionary = projection._selected.T["7"]
	check(projection._keep("T", row.duplicate(), [4]) and is_same(projection._selected.T["7"], kept), "the same row at the same position keeps its entry")
	check(not projection._keep("T", {"ID": 7.0, "Value": 2.0}, [4]), "a different row under the same ID still conflicts")
	for catalog: Variant in [grown, full, fresh, foreign, ids]: catalog = null
	print("NPC_CATALOG_PUBLISH_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _indexes_of(npc_ids: Array) -> Dictionary:
	var catalog := CATALOG.new()
	catalog._publish_original(_content(npc_ids))
	return catalog.indexes
