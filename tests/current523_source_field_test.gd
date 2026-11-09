extends SceneTree
## Generic terrain checks, with no native collision or render assertion.
## --pack-root=<v3 private pack> --manifest-sha=<explicit pin> checks actual
## sources. --partial-root/--partial-sha and --unclassified-root/--unclassified-sha
## optionally retain earlier immutable snapshots as missing/scope regressions.
const FIELD = preload("res://scripts/maps/current523_source_field.gd")
const PACK = preload("res://scripts/maps/current523_source_pack.gd")
var all_maps_scope: bool = false
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func argument(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _initialize() -> void:
	var field = FIELD.new()
	check(not field.loaded and not field.walkable(Vector2.ZERO),"unconfigured generic field denies movement")
	check(not field.configure_current523("/missing/aden-pack"),"generic field cannot bypass explicit native catalog binding through Aden entry point")
	check(not field.configure_catalog("/missing/catalog","",1),"missing catalog and manifest pin deny")
	check(not field.configure_catalog("/missing/catalog","0".repeat(64),1,{"allowed_raw_words":[65535]}),"invalid own policy denies before registration")
	check(not field.loaded and field.native_land.is_empty() and field.source_asset.is_empty() and field.registered_source_members().is_empty(),"failed configure exposes no partial native identity or source registry")
	check(field.path(Vector2.ZERO,Vector2.ONE).is_empty(),"unconfigured path cannot substitute a nearest cell")
	check(not field.configure_verified_catalog(null,"0".repeat(64),1) and not field.configure_verified_catalog(RefCounted.new(),"0".repeat(64),1),"unverified catalog objects cannot become source fields")
	field.close()
	field.close()
	check(not field.has_meta("current523_generic_field") and not field.has_meta("current523_source_field"),"close is idempotent and clears source ownership")
	var root: String = argument("--pack-root=")
	var pin: String = argument("--manifest-sha=")
	if not root.is_empty(): _actual_sources(root,pin)
	else: check(pin.is_empty(),"actual source root and manifest pin must be supplied together")
	print("CURRENT523_SOURCE_FIELD_RESULT "+JSON.stringify({"checks":checks,"failures":failures,
		"actual_source_evidence":evidence,"native_m_rules_verified":false,"render_verified":false}))
	quit(0 if failures.is_empty() else 1)

func _actual_sources(root: String, pin: String) -> void:
	var catalog = PACK.new()
	check(catalog.load_catalog(root,pin),"actual generic catalog loads: "+catalog.problem)
	if not catalog.catalog_loaded: return
	check(not FIELD.new().configure_verified_catalog(catalog,"0".repeat(64),1),"verified snapshot still requires the caller's matching manifest pin")
	check(catalog.catalog_lands().size() == 1065,"all native logical Land rows remain available before field selection")
	var excluded: int = 0
	var included: int = 0
	for row: Dictionary in catalog.catalog_lands():
		if row.excluded_content.is_empty(): included += 1
		else: excluded += 1
	# Two explicit scopes exist: the pinned full-map handoff (997 ordinary, 68
	# excluded) and the user's all-maps decision (client523_map_inventory.py,
	# every Land included). Both must still classify every native Land row.
	all_maps_scope = excluded == 0 and str(catalog.catalog_lands()[0].get("policy_provenance",{}).get("source","")).begins_with("User decision 2026-11-09")
	check((included == 997 and excluded == 68) or (all_maps_scope and included == 1065),"exact explicit scope remains per logical Land")
	var definitions: Dictionary = {}
	var physical_members: Dictionary = {}
	var placed_members: Dictionary = {}
	var scopes: Array = []
	var ids: Array[int] = []
	var expected_available: int = 0
	var expected_assets: Dictionary = {}
	var unplaced: Dictionary = {}
	for record: Dictionary in catalog.catalog_lands():
		if record.policy_status != "classified" or not record.excluded_content.is_empty(): continue
		var physical: Dictionary = catalog.asset_record(str(record.declaration.AssetPath))
		if int(physical.get("ready_count",0)) <= 0: continue
		ids.append(int(record.declaration.ID))
		if not expected_assets.has(physical.asset_path):
			expected_assets[physical.asset_path] = true
			expected_available += int(physical.ready_count)
	for id: int in ids:
		if definitions.size()%25==0: print("CURRENT523_SOURCE_FIELD_PROGRESS ",definitions.size(),"/",ids.size())
		var field = FIELD.new()
		check(field.configure_verified_catalog(catalog,pin,id,{"aden_inferred_placement_enabled":false}),"historical placement-off Land configures exact physical asset: "+str(id)+" "+field.problem)
		if not field.loaded: continue
		var record: Dictionary = catalog.land_record(id)
		var asset: Dictionary = catalog.asset_record(str(record.declaration.AssetPath))
		check(field.native_land == record.declaration and field.source_asset == record.declaration.AssetPath,"logical identity is exact native declaration: "+str(id))
		check(field.definition.source_map_id == id and field.definition.source_asset_path == record.declaration.AssetPath
			and field.definition.source_sha256 == asset.source_inventory_sha256 and field.definition.source_manifest_sha256 == pin,"definition binds exact per-asset inventory and external manifest: "+str(id))
		check(field.data.navigation_profile == field.CLIENT_PROFILE and field.policy.attribute_rule == field.CLIENT_RULE and not field.uses_original_gameplay_rules(),"generic field defaults to the client S32 attribute rule: "+str(id))
		check(field.data.npc_spawn.is_empty() and field.data.monster_spawn.is_empty() and field.data.portal.is_empty()
			and field.data.regions.is_empty() and field.chunk_table.is_empty() and field.nav_cache.is_empty() and field.packs.is_empty(),"shared raw terrain copies no legacy content or navigation grids: "+str(id))
		check(field.has_meta("current523_source_field") and field.has_meta("current523_generic_field"),"successful generic field owns source metadata: "+str(id))
		check(not field.is_safe(Vector2.ZERO) and field.region_at(Vector2.ZERO).type == "neutral","unknown safety and region meanings stay neutral: "+str(id))
		definitions[id] = field.definition.duplicate(true)
		for member: String in field.registered_source_members():
			var metadata: Dictionary = field.source_metadata(member)
			if metadata.get("status") == "ready" and not metadata.has("runtime_status"): physical_members[member] = true
		for member: String in field.unplaced_source_members(): unplaced[member] = true
		var origins: Dictionary = field.source_chunk_origins()
		for member: String in origins:
			var origin: Vector2i = origins[member]
			placed_members[member] = true
			var metadata: Dictionary = field.source_metadata(member)
			var raw: PackedByteArray = FileAccess.get_file_as_bytes(root.path_join(str(metadata.path)))
			if metadata.get("storage_format","raw") == "gzip":
				check(raw.size() == int(metadata.stored_bytes) and PACK._hash(raw) == metadata.stored_sha256,"independent stored gzip identity: "+member)
				raw = raw.decompress(int(metadata.bytes),FileAccess.COMPRESSION_GZIP)
			check(raw.size() == int(metadata.bytes) and PACK._hash(raw) == metadata.sha256,"independent actual file identity: "+member)
			for local: Vector2i in [Vector2i.ZERO,Vector2i(31,31),Vector2i(63,63)]:
				var info: Dictionary = field.source_cell_info(origin+local)
				var index: int = local.y*128+local.x*2
				var offset: int = int(metadata.attribute_offset)+index*2
				check(info.member == member and info.source_sha256 == metadata.sha256
					and info.raw_pair == [raw.decode_u16(offset),raw.decode_u16(offset+2)]
					and info.floor_pair == [raw.decode_u32(index*4),raw.decode_u32((index+1)*4)],"field query preserves actual byte pairs and source SHA: "+member+str(local))
		if id == 0: check(field.cache_metrics().cached_chunks == 48,"generic raw field retains bounded independent 48-member LRU")
		if id == 4: check(field.source_chunk_origins().size() == 676 and field.unplaced_source_members() == ["Map/Aden/800f7ff3e.s32"],"generic Aden retains 676 placed sources and literal unplaced original")
		scopes.append(field.scope_metrics())
		field.close()
		check(not field.loaded and field.native_land.is_empty() and field.source_asset.is_empty() and field.scope_metrics().expected_sources == 0,"close clears logical Land, pack and cache state: "+str(id))
	check(definitions[0].map_id != definitions[12156].map_id and definitions[0].source_sha256 == definitions[12156].source_sha256,"Land0 and12156 retain separate logical maps over one physical asset")
	check(physical_members.size() == expected_available and placed_members.size()+unplaced.size() == expected_available,"every available original binds once as a placed or explicitly unplaced member")
	_policy_and_scope(root,pin,catalog)
	_missing_snapshot()
	evidence = {"manifest_sha256":pin,"native_land_rows":1065,"included_logical_lands":included,"excluded_logical_lands":excluded,
		"unique_expected_normal_sources":6570,"unique_available_originals":physical_members.size(),
		"unique_placed_originals":placed_members.size(),"unique_physical_roots_checked":expected_assets.size(),"logical_scopes_checked":scopes,
		"native_collision_rules_verified":false,"render_verified":false}

func _policy_and_scope(root: String, pin: String, catalog: RefCounted) -> void:
	var field = FIELD.new()
	check(field.configure_catalog(root,pin,1),"Land1 configures for actual own-policy regression")
	var zero := Vector2i(32658,32787)
	var blocked := Vector2i(32576,32768)
	check(field.source_cell_info(zero).raw_pair == [0,0] and field.source_cell_info(zero).walkable,"recovered12th Land1 source supplies explicit zero mapping")
	check(field.source_cell_info(blocked).raw_pair == [1,1] and not field.source_cell_info(blocked).walkable,"unlisted actual raw words remain blocked under default own policy")
	check(field.configure_catalog(root,pin,1,{"allowed_raw_words":[1]}) and field.source_cell_info(blocked).walkable
		and not field.source_cell_info(zero).walkable,"authorized alternate own allowlist applies to generic terrain without native collision claim")
	check(field.configure_catalog(root,pin,3,{"allowed_raw_words":null,"allowed_mask":12,"must_mask":4,"forbidden_mask":8})
		and field.source_cell_info(Vector2i(32658,32785)).raw_pair == [4,4] and field.source_cell_info(Vector2i(32658,32785)).walkable,"same own mask policy applies to actual nonzero Land3 attribute pair")
	check(not field.configure_catalog(root,pin,3,{"allowed_raw_words":[0],"spawn_source":[32658,32785]})
		and not field.loaded and field.native_land.is_empty() and field.registered_source_members().is_empty()
		and not field.has_meta("current523_generic_field"),"blocked explicit spawn fails closed without retaining partial field")
	if all_maps_scope:
		check(catalog.land_record(22793).declaration.AssetPath == "15/" and catalog.land_record(22803).declaration.AssetPath == "15/"
			and catalog.land_record(22803).excluded_content.is_empty() and field.configure_catalog(root,pin,22803) and field.loaded,"all-maps scope configures a formerly excluded logical Land on its shared physical root")
	else:
		check(catalog.land_record(22793).declaration.AssetPath == "15/" and catalog.land_record(22793).excluded_content.is_empty()
			and catalog.land_record(22803).declaration.AssetPath == "15/" and catalog.land_record(22803).excluded_content.has("siege"),"mixed physical root keeps ordinary and excluded logical declarations separate")
		check(not field.configure_catalog(root,pin,22803) and not field.loaded and field.native_land.is_empty()
			and field.problem.begins_with("제외"),"excluded logical Land refuses by scope before looking for its shared physical source")
	check(not field.configure_catalog(root,pin,999999) and not field.loaded,"unknown logical Land has no numeric folder fallback")
	check(not field.configure_catalog(root,"0".repeat(64),1) and not field.loaded,"incorrect manifest pin denies field replacement")
	var unknown_root: String = argument("--unclassified-root=")
	if not unknown_root.is_empty():
		check(not field.configure_catalog(unknown_root,argument("--unclassified-sha="),0)
			and not field.loaded and field.native_land.is_empty() and field.problem.begins_with("제외"),"earlier unclassified logical Land refuses by scope before source availability")
	field.close()

func _missing_snapshot() -> void:
	var root: String = argument("--partial-root=")
	if root.is_empty(): return
	var field = FIELD.new()
	check(field.configure_catalog(root,argument("--partial-sha="),1),"earlier partial Land1 snapshot still loads its verified11 chunks")
	if not field.loaded: return
	var missing := Vector2i(32658,32787)
	var point: Vector2 = field.coordinates.to_world(Vector2(missing))
	check(field.scope_metrics().expected_sources == 12 and field.scope_metrics().ready_placed_sources == 11
		and field.unavailable_sources.get("Map/1/7ffe8000.s32") == "missing_source","missing12th member remains explicit inside declared extent")
	check(field.source_bounds.has_point(missing) and field.source_cell_info(missing).status == "unregistered_chunk"
		and not field.walkable(point) and field.path(point,point).is_empty(),"missing chunk never becomes explicit zero floor or nearest landing")
	field.close()
