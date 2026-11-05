extends SceneTree
## Authored guard fixtures contain no M payload. Optional --contract=<private JSON>
## checks the pinned 93-row contract; --aden523-pack=<raw root> also checks actual
## endpoint cells through Current523AdenSourceField's configured own policy.
const PORTALS = preload("res://scripts/maps/current523_aden_source_portals.gd")
var checks: int = 0
var failures: Array[String] = []
var real_evidence: Dictionary = {}

class FixtureCatalog extends PORTALS:
	func prepare() -> void:
		# Authored adjacent chunk endpoints exercise both identities at a seam.
		_portals = {9: _entry(9, false, ["target_land_source_not_supplied"]),
			3: _entry(3, false, ["raw_destination_outside_declared_territory"]),
			1: _entry(1, true, []),
			4: _entry(4, false, ["no_exact_source_and_namespace_raw_record"])}
		loaded = true
	func _entry(id: int, candidate: bool, blockers: Array) -> Dictionary:
		return {"id": id, "portal": {"ID": id, "SourceLandID": 4, "SourceX": 32767, "SourceY": 32768},
			"source_position": [32767,32768], "landing_position": [32768,32768],
			"activation_candidate": candidate, "activation_eligible": false, "blockers": blockers,
			"source_support": {"member":"Map/Aden/7fff8000.s32", "sha256":"a".repeat(64)},
			"target_support": {"member":"Map/Aden/80008000.s32", "sha256":"b".repeat(64)}}

class FixtureField extends RefCounted:
	# These are authored query results, not verified originals or native rules.
	var infos: Dictionary = {}
	var queries: Array[Vector2i] = []
	func prepare() -> void:
		infos = {
			Vector2i(32767,32768): _info(Vector2i(32767,32768), "Map/Aden/7fff8000.s32", "a".repeat(64)),
			Vector2i(32768,32768): _info(Vector2i(32768,32768), "Map/Aden/80008000.s32", "b".repeat(64))}
		queries.clear()
	func _info(cell: Vector2i, member: String, digest: String) -> Dictionary:
		return {"status":"allowed", "walkable":true, "source_cell":cell,
			"member":member, "source_sha256":digest, "raw_pair":[0,0], "floor_pair":[0,1],
			"own_profile":"AUTHORED_GUARD_FIXTURE_ONLY", "native_m_rules_verified":false}
	func source_cell_info(cell: Vector2i) -> Dictionary:
		queries.append(cell)
		return infos.get(cell, {}).duplicate(true)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""

func _initialize() -> void:
	_fixture_guards()
	var path: String = _argument("--contract=")
	var raw_root: String = _argument("--aden523-pack=")
	if not path.is_empty(): _pinned_contract(path, raw_root)
	elif not raw_root.is_empty(): check(false, "--aden523-pack requires --contract")
	print("CURRENT523_ADEN_SOURCE_PORTALS_RESULT "+JSON.stringify({"checks":checks,"failures":failures,
		"fixture_only":path.is_empty(), "real_source_evidence":real_evidence, "native_m_rules_verified":false}))
	quit(0 if failures.is_empty() else 1)

func _fixture_guards() -> void:
	var unopened = PORTALS.new()
	check(unopened.portal_evidence().is_empty() and unopened.portal_context(1).is_empty(), "unloaded queries stay empty")
	check(not unopened.activation_target(1,Vector2i.ZERO,null).get("ok",true), "unloaded guard denies")
	var catalog := FixtureCatalog.new()
	catalog.prepare()
	var field := FixtureField.new()
	field.prepare()
	var start := Vector2i(32767,32768)
	var target := Vector2i(32768,32768)
	var evidence: Array = catalog.portal_evidence()
	check(evidence.size() == 4 and evidence[0].id == 1 and evidence[3].id == 9, "evidence is sorted by exact IDs")
	evidence[0].portal.SourceX = -1
	var context: Dictionary = catalog.portal_context(1)
	context.source_support.sha256 = "changed"
	var at_source: Array = catalog.portals_at(start)
	at_source[0].source_position[0] = -1
	check(catalog.portal(1).portal.SourceX == 32767 and catalog.portal(1).source_support.sha256 == "a".repeat(64) and catalog.portal(1).source_position == [32767,32768], "all public queries return independent deep copies")
	check(catalog.portals_at(start+Vector2i.LEFT).is_empty(), "no neighboring portal radius is invented")
	var success: Dictionary = catalog.activation_target(1,start,field)
	check(success.get("ok",false) and success.target_position == target, "accepted authored endpoints return exact target across chunk seam")
	check(field.queries == [start,target], "both endpoint cells are queried independently")
	check(not success.has("cost") and not success.has("fee") and not success.has("consume_item"), "guard invents no fee or item consumption")
	field.queries.clear()
	check(catalog.activation_target(1,start+Vector2i.RIGHT,field).get("reason") == "actor_not_at_declared_portal" and field.queries.is_empty(), "actor must occupy exact source before endpoint queries")
	check(catalog.activation_target(1,start,null).get("reason") == "source_field_unavailable", "missing field denies")
	for id: int in [3,4,9]:
		check(catalog.activation_target(id,start,field).get("reason") == "portal_endpoint_evidence_incomplete", "mismatch, unmatched source and unsupported Land remain blocked: "+str(id))
	check(catalog.activation_target(999,start,field).get("reason") == "portal_contract_unavailable", "unknown portal ID denies")
	for status: String in ["policy_blocked","unknown_attribute","floor_sentinel","source_integrity_failure","unregistered_chunk","outside_source_bounds","not_configured"]:
		field.prepare()
		field.infos[start].status = status
		field.infos[start].walkable = false
		check(catalog.activation_target(1,start,field).get("reason") == "source_endpoint_blocked", "actual source-field rejection status denies: "+status)
	field.prepare()
	field.infos[target].walkable = false
	check(catalog.activation_target(1,start,field).get("reason") == "target_endpoint_blocked", "target independently denies despite allowed source")
	for endpoint: Vector2i in [start,target]:
		for bad_hash: String in ["", "a", "0".repeat(64)]:
			field.prepare()
			field.infos[endpoint].source_sha256 = bad_hash
			check(not catalog.activation_target(1,start,field).get("ok",true), "missing, incomplete or wrong actual source hash denies: "+str(endpoint))
		field.prepare()
		field.infos[endpoint].member = "Map/Aden/other.s32"
		check(not catalog.activation_target(1,start,field).get("ok",true), "wrong chunk identity denies at either endpoint")
		field.prepare()
		field.infos[endpoint].source_cell = endpoint+Vector2i.ONE
		check(not catalog.activation_target(1,start,field).get("ok",true), "wrong actual cell denies at either endpoint")
	field.prepare()
	field.infos[target].raw_pair = [256,256]
	check(catalog.activation_target(1,start,field).get("ok",false), "authorized custom field policy is respected without a duplicate default allowlist")
	field.infos[target].status = "policy_blocked"
	field.infos[target].walkable = false
	check(not catalog.activation_target(1,start,field).get("ok",true), "same raw words deny when configured field policy rejects")
	for malformed: Variant in [[], [0], [0,65536], [0,-1], [0,1.5]]:
		field.prepare()
		field.infos[target].raw_pair = malformed
		check(not catalog.activation_target(1,start,field).get("ok",true), "malformed raw attribute pair denies")
	field.prepare()
	field.infos[target].floor_pair = [0,4294967295]
	check(not catalog.activation_target(1,start,field).get("ok",true), "floor sentinel denies even an inconsistent allowed field response")
	var bad_path: String = "user://aden_portals_authored_wrong_hash.json"
	var bad := FileAccess.open(bad_path,FileAccess.WRITE)
	check(bad != null, "authored wrong-hash file opens")
	if bad != null:
		bad.store_string('{"schema":1,"fixture_only":true}')
		bad.close()
		check(not catalog.load_contract(bad_path) and not catalog.loaded and catalog.portal_evidence().is_empty(), "wrong contract hash clears previously accepted registry")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))

func _pinned_contract(path: String, raw_root: String) -> void:
	var catalog = PORTALS.new()
	check(catalog.load_contract(path), "pinned private contract loads: "+catalog.problem)
	if not catalog.loaded: return
	var evidence: Array = catalog.portal_evidence()
	check(evidence.size() == 93 and evidence[0].id == 327, "all 93 native declarations remain sorted")
	var candidates: int = 0
	for entry: Dictionary in evidence:
		if entry.activation_candidate: candidates += 1
		check(entry.activation_eligible == false, "native contract never preapproves runtime activation: "+str(entry.id))
	check(candidates == 30, "30 individual raw endpoint candidates preserved")
	check(catalog.portal_context(350).activation_candidate == false and catalog.portal_context(350).blockers.has("raw_destination_outside_declared_territory"), "Portal350 raw/native destination mismatch retained")
	check(catalog.portal_context(327).blockers.has("target_land_source_not_supplied"), "other Land source unavailable remains blocked")
	check(catalog.portal_context(18071).landing_position == null and catalog.portal_context(18081).landing_position == null, "native rectangular targets have no invented exact landing")
	evidence[0].portal.SourceX = -1
	check(catalog.portal_context(327).portal.SourceX == 32938, "native evidence is immutable through public query copies")
	check(not catalog.activation_target(350,Vector2i(34117,32254),null).get("ok",true), "native mismatch denies before field lookup")
	real_evidence = {"contract_sha256":PORTALS.CONTRACT_SHA256, "native_portal_rows":93,
		"static_raw_endpoint_candidates":30, "actual_source_cells_checked":false}
	if raw_root.is_empty(): return
	# Dynamically loaded so fixture-only standalone runs need only this loader.
	var script: Script = load("res://scripts/maps/current523_aden_source_field.gd")
	check(script != null, "actual source field class available")
	if script == null: return
	var field: RefCounted = script.new()
	check(field.call("configure_current523",raw_root), "actual source field configures with default own policy")
	if not field.get("loaded"): return
	var accepted: Array[int] = []
	for entry: Dictionary in catalog.portal_evidence():
		if not entry.activation_candidate: continue
		var source := Vector2i(int(entry.source_position[0]),int(entry.source_position[1]))
		if catalog.activation_target(int(entry.id),source,field).get("ok",false): accepted.append(int(entry.id))
	check(accepted == [335,343], "actual default own policy accepts both endpoints only for335/343")
	for id: int in [335,343]:
		var entry: Dictionary = catalog.portal_context(id)
		var source := Vector2i(int(entry.source_position[0]),int(entry.source_position[1]))
		var result: Dictionary = catalog.activation_target(id,source,field)
		check(result.get("ok",false) and result.source_info.raw_pair == [0,0] and result.target_info.raw_pair == [0,0], "actual endpoint words and source hashes clear guard: "+str(id))
		check(not result.has("cost") and not result.has("fee"), "actual guarded result has no invented cost")
	real_evidence.actual_source_cells_checked = true
	real_evidence.default_own_policy_accepted_ids = accepted
	real_evidence.raw_inventory_sha256 = PORTALS.INVENTORY_SHA256
	field.call("close")
