extends SceneTree
const LINKS = preload("res://scripts/maps/patch523_world_links.gd")
const POLICY = preload("res://scripts/monsters/patch523_spawn_policy.gd")
const ARRIVAL = preload("res://scripts/maps/patch523_portal_arrival.gd")
const EVIDENCE = preload("res://scripts/maps/patch523_portal_source_evidence.gd")
var checks: int = 0
var failures: Array[String] = []
class GeometryProbe extends RefCounted:
	# Synthetic adapter regression only. This is not original map geometry.
	var identity: Dictionary = {}
	var supplied: Variant = true
	var clear: Variant = true
	var wall: bool = false
	var projection: Vector2 = Vector2.ZERO
	var roundtrip_offset: Vector2 = Vector2.ZERO
	var requested: Vector2 = Vector2.INF
	func portal_geometry_contract() -> Dictionary: return identity.duplicate(true)
	func source_cell_supplied(_cell: Vector2i) -> Variant: return supplied
	func source_to_world(at: Vector2) -> Vector2: requested = at; return at * 2.0 + projection
	func world_to_source(at: Vector2) -> Vector2: return (at - projection) / 2.0 + roundtrip_offset
	func point_clear(_point: Vector2, _padding: float) -> Variant: return clear
	func line_clear(from: Vector2, to: Vector2) -> bool: return not wall or from == to
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("PORTAL_ARRIVAL_FAIL: ", label)
func _initialize() -> void:
	var options: Dictionary = POLICY.settings()
	var links = LINKS.new()
	check(links.load_land(options.root, 4, "Aden/", options.sha), "current definition pack loads")
	var original: String = JSON.stringify(links.shard)
	var exact: int = 0
	var regions: Array[int] = []
	for row: Dictionary in links.portal_evidence():
		var contract: Dictionary = links.portal_contract(int(row.portal.ID))
		if contract.arrival_kind == "EXACT_POINT": exact += 1
		else: regions.append(int(row.portal.ID))
		check(not contract.travel_enabled and not contract.portal_cost_known and not contract.activation_known, "declaration does not grant activation or free travel %s" % row.portal.ID)
	check(exact == 91 and regions == [18071,18081], "91 declared points and2 region arrivals")
	var contract: Dictionary = links.portal_contract(350)
	check(int(contract.declared_arrival[0]) == 34275 and int(contract.declared_arrival[1]) == 32222, "Portal350 uses declared M arrival, never packed candidate")
	contract.declared_arrival[0] = 0; contract.declaration.portal.SourceX = 0
	check(JSON.stringify(links.shard) == original and int(links.portal_contract(350).declared_arrival[0]) == 34275, "contract query cannot mutate source")
	check(ARRIVAL.inspect(links, 18071, null).code == "arrival_region_policy_required", "no arbitrary arrival in region")
	check(ARRIVAL.inspect(links, 350, RefCounted.new()).code == "source_geometry_api_required", "host field cannot be treated as M geometry")
	check(ARRIVAL.inspect(null, 350, null).code == "portal_missing" and ARRIVAL.inspect(links, -1, null).code == "portal_missing", "missing catalog and portal are held")
	var field := GeometryProbe.new()
	field.identity = {"schema":1, "source_snapshot":"patch523", "coordinate_space":ARRIVAL.SPACE,
		"definition_manifest_sha256":links.manifest_sha256, "land_id":4, "asset_path":"Aden/", "geometry_sha256":"a".repeat(64),
		"collision_scope":"EXPLICIT_LOCAL_POLICY", "traversal_policy_id":"SYNTHETIC_TEST_ONLY", "actor_foot_policy_id":"TEST_TWILIGHT_4PX"}
	var result: Dictionary = ARRIVAL.inspect(links, 350, field)
	check(result.landing_geometry_ok and not result.travel_enabled and field.requested == Vector2(34275,32222), "explicit adapter validates only declared landing without activating portal")
	check(result.world_point == Vector2(68550,64444) and result.geometry.collision_scope == "EXPLICIT_LOCAL_POLICY", "projection and own traversal policy stay labeled")
	for setting: Array in [["source_snapshot","base508"],["coordinate_space","L1J"],["definition_manifest_sha256","0".repeat(64)],["land_id",48],["asset_path","4/"],["collision_scope","REGISTERED_LEGACY_REVIEW_COLLISION"],["traversal_policy_id",""],["actor_foot_policy_id",""],["geometry_sha256","invalid"]]:
		var prior: Variant = field.identity[setting[0]]
		field.identity[setting[0]] = setting[1]
		check(not ARRIVAL.inspect(links, 350, field).landing_geometry_ok, "different geometry contract is held: " + str(setting[0]))
		field.identity[setting[0]] = prior
	field.supplied = false
	check(ARRIVAL.inspect(links, 350, field).code == "destination_chunk_missing", "missing original chunk cannot land")
	field.supplied = 1
	check(ARRIVAL.inspect(links, 350, field).code == "destination_chunk_missing", "numeric coverage flag is not boolean proof")
	field.supplied = true; field.roundtrip_offset = Vector2(1,0)
	check(ARRIVAL.inspect(links, 350, field).code == "projection_roundtrip_mismatch", "shifted roundtrip cannot land")
	field.roundtrip_offset = Vector2.ZERO; field.projection = Vector2.INF
	check(ARRIVAL.inspect(links, 350, field).code == "invalid_projection", "nonfinite projection cannot land")
	field.projection = Vector2.ZERO; field.clear = false
	check(ARRIVAL.inspect(links, 350, field).code == "destination_blocked", "blocked destination cannot land")
	field.clear = 1
	check(ARRIVAL.inspect(links, 350, field).code == "destination_blocked", "numeric clearance flag is not boolean proof")
	field.clear = true; field.wall = true
	check(ARRIVAL.inspect(links, 350, field).code == "destination_footprint_blocked", "footprint crossing a wall cannot land")
	check(JSON.stringify(links.shard) == original, "all checks preserve exact definitions")
	var evidence = EVIDENCE.new()
	check(evidence.load_archive(EVIDENCE.configured_path(), links), "verified50-record handoff loads")
	var catalogs: Dictionary = {4: links}
	for id: Variant in evidence.by_portal:
		var source: int = int(evidence.by_portal[id].source_land_id)
		if not catalogs.has(source):
			var catalog = LINKS.new()
			var spec: Dictionary = links.manifest.lands[str(source)]
			check(catalog.load_land(options.root, source, str(spec.asset_path), options.sha), "handoff source Land loads %d" % source)
			catalogs[source] = catalog
		var source_contract: Dictionary = catalogs[source].portal_contract(int(id))
		check(not source_contract.is_empty() and source_contract.source_namespace.land_id == source and source_contract.target_namespace.land_id == 4 and source_contract.arrival_kind == "EXACT_POINT" and not source_contract.travel_enabled, "each50 source/target declaration contract stays separate %s" % id)
	print("PATCH523_PORTAL_ARRIVAL_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"synthetic_geometry_only":true}))
	quit(0 if failures.is_empty() else 1)
