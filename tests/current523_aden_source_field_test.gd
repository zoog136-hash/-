extends SceneTree
const FIELD = preload("res://scripts/maps/current523_aden_source_field.gd")
const RAW = preload("res://scripts/maps/current523_aden_pack.gd")
var checks: int = 0
var failures: Array[String] = []

class MemoryField extends FIELD:
	var rows: Dictionary = {}
	func prepare(interpretation: Dictionary = {"attribute_rule":"own_allowlist"}) -> void:
		_configure_policy(interpretation)
		source_bounds = Rect2i(32000,32000,128,64)
		coordinates.configure([32000,32000],[128,64],policy.coordinate_mapping)
		width = 128
		height = 64
		bounds = coordinates.canvas_bounds()
		for x: int in [32000,32064]:
			var attributes := PackedByteArray()
			attributes.resize(16384)
			attributes.fill(0)
			var floor_refs := PackedByteArray()
			floor_refs.resize(32768)
			floor_refs.fill(0)
			var origin := Vector2i(x,32000)
			var member: String = "memory_"+str(x)
			_source_chunks[origin] = member
			rows[origin] = {"member":member,"sections":{"attributes":attributes,"floor":floor_refs}}
		loaded = true
	func _source_chunk(origin: Vector2i) -> Dictionary: return rows.get(origin,{})
	func attribute(cell: Vector2i, half: int, value: int) -> void:
		var source: Vector2i = cell+coordinates.origin
		var origin: Vector2i = _source_origin(source)
		var bytes: PackedByteArray = rows[origin].sections.attributes
		bytes.encode_u16(((source.y-origin.y)*128+(source.x-origin.x)*2+half)*2,value)
		rows[origin].sections.attributes = bytes
	func floor_reference(cell: Vector2i, half: int, value: int) -> void:
		var source: Vector2i = cell+coordinates.origin
		var origin: Vector2i = _source_origin(source)
		var bytes: PackedByteArray = rows[origin].sections.floor
		bytes.encode_u32(((source.y-origin.y)*128+(source.x-origin.x)*2+half)*4,value)
		rows[origin].sections.floor = bytes

class RejectReadPack extends RAW:
	func read_member(_member: String) -> Dictionary:
		problem = "Injected source integrity rejection"
		return {}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void:
	var missing = FIELD.new()
	check(not missing.configure_current523("/nonexistent/current523-source-pack"),"missing pack rejects")
	check(not missing.loaded and missing.registered_source_members().is_empty(),"failed load has no exposed source registry")
	check(not missing.walkable(Vector2.ZERO) and not missing.can_step(Vector2i.ZERO,0),"unconfigured field denies movement")
	check(missing.path(Vector2.ZERO,Vector2.ONE).is_empty(),"unconfigured path denies")
	for invalid: Dictionary in [{"allowed_raw_words":[65535]}, {"allowed_raw_words":[true]}, {"allowed_mask":1.5}, {"must_mask":1,"forbidden_mask":1}, {"allowed_mask":4,"must_mask":8}, {"coordinate_mapping":[]}, {"path_search_limit":0}]:
		check(not FIELD.new().configure_current523("/nonexistent/current523-source-pack",invalid),"invalid own policy rejects: "+str(invalid))
	var memory := MemoryField.new()
	memory.prepare()
	check(not memory.uses_original_gameplay_rules() and not memory.policy.native_m_rules_verified,"own interpretation never claims native rules")
	check(memory.source_cell_info(Vector2i(32001,32001)).raw_pair == [0,0],"two original zero words remain explicit values")
	check(memory.walkable(memory.cell_to_world(Vector2i(1,1))),"zero is explicitly mapped by chosen own allowlist")
	check(memory.can_step(Vector2i(63,20),2) and memory.can_step(Vector2i(64,20),6),"movement crosses registered raw chunk seam both directions")
	check(memory.can_step(Vector2i(10,10),3),"diagonal opens when both side cells open")
	memory.attribute(Vector2i(11,10),1,1)
	check(not memory.can_step(Vector2i(10,10),3),"one denied half in side cell prevents corner cutting")
	check(not memory.line_clear(memory.cell_to_world(Vector2i(10,10)),memory.cell_to_world(Vector2i(11,11))),"DDA uses own corner rule")
	check(not memory.walkable(memory.cell_to_world(Vector2i(11,10))),"both halfwords must pass")
	check(memory.path(memory.cell_to_world(Vector2i(10,10)),memory.cell_to_world(Vector2i(11,10))).is_empty(),"blocked click never snaps to nearest allowed cell")
	check(memory.path(memory.cell_to_world(Vector2i(11,10)),memory.cell_to_world(Vector2i(12,10))).is_empty(),"blocked starting cell never snaps")
	memory.attribute(Vector2i(20,20),0,65535)
	check(memory.source_cell_info(Vector2i(32020,32020)).status == "unknown_attribute","0xffff attribute always denies")
	memory.floor_reference(Vector2i(21,20),1,4294967295)
	check(memory.source_cell_info(Vector2i(32021,32020)).status == "floor_sentinel","either floor sentinel denies")
	check(memory.source_cell_info(Vector2i(32022,32020)).floor_pair == [0,0] and memory.walkable(memory.cell_to_world(Vector2i(22,20))),"zero floor references preserved under explicit own choice")
	memory.attribute(Vector2i(23,20),0,8196)
	check(not memory.walkable(memory.cell_to_world(Vector2i(23,20))),"unmapped high attribute bits never truncate into allowed4")
	var client := MemoryField.new()
	client.prepare({})
	check(client.policy.attribute_rule == FIELD.CLIENT_RULE and client.data.get("navigation_profile",FIELD.CLIENT_PROFILE) == FIELD.CLIENT_PROFILE,"resource-first default is the client S32 attribute rule")
	client.attribute(Vector2i(11,10),1,1)
	check(client.can_step(Vector2i(10,10),3),"client rule: one open orthogonal side permits the diagonal")
	client.attribute(Vector2i(10,11),0,1)
	check(not client.can_step(Vector2i(10,10),3),"client rule: both orthogonal sides rejected blocks the diagonal")
	client.attribute(Vector2i(23,20),0,8196)
	check(client.walkable(client.cell_to_world(Vector2i(23,20))),"client rule: bit0 clear passes regardless of other bits")
	client.attribute(Vector2i(24,20),1,65535)
	check(not client.walkable(client.cell_to_world(Vector2i(24,20))),"client rule: 0xffff has bit0 and rejects")
	client.attribute(Vector2i(25,20),0,1)
	check(not client.walkable(client.cell_to_world(Vector2i(25,20))),"client rule: bit0 set rejects")
	memory.attribute(Vector2i(24,20),0,4)
	memory.attribute(Vector2i(24,20),1,8)
	check(memory.source_cell_info(Vector2i(32024,32020)).raw_pair == [4,8] and memory.walkable(memory.cell_to_world(Vector2i(24,20))),"allowed exact words remain separate u16 values")
	check(memory.value_at(Vector2i(24,20)) == 4 and memory.value_at(Vector2i(24,20),true) == 1,"legacy API exposes raw first word and own boolean separately")
	check(not memory.is_safe(Vector2.ZERO) and memory.region_at(Vector2.ZERO).type == "neutral","raw bit48 never establishes safety or combat geography")
	check(not memory.can_step(Vector2i.ZERO,-1) and not memory.can_step(Vector2i.ZERO,8),"invalid headings deny")
	check(not memory.walkable(Vector2.INF) and not memory.line_clear(Vector2.INF,Vector2.ZERO),"nonfinite world input denies")
	check(memory.source_cell_info(Vector2i(31999,32000)).status == "outside_source_bounds","out of bounds source distinct from explicit zero")
	memory.rows.erase(Vector2i(32064,32000))
	check(not memory.can_step(Vector2i(63,20),2),"unavailable adjacent chunk denies seam")
	memory = MemoryField.new()
	memory.prepare()
	memory.attribute(Vector2i(2,1),0,1)
	var start: Vector2 = memory.cell_to_world(Vector2i(1,1))
	var goal: Vector2 = memory.cell_to_world(Vector2i(3,1))
	var route: PackedVector2Array = memory.path(start,goal)
	check(not route.is_empty() and route[-1] == goal,"bounded inherited A* finds route using own cell policy")
	var previous: Vector2 = start
	for point: Vector2 in route:
		check(memory.line_clear(previous,point),"every returned route segment passes own DDA")
		previous = point
	var masked := MemoryField.new()
	masked.prepare()
	check(masked._configure_policy({"allowed_raw_words":null,"allowed_mask":12,"must_mask":4,"forbidden_mask":8}),"explicit mask-only profile accepts")
	masked.attribute(Vector2i(1,1),0,4)
	masked.attribute(Vector2i(1,1),1,4)
	check(masked.walkable(masked.cell_to_world(Vector2i(1,1))),"must and allowed masks apply to both original u16 halves")
	masked.attribute(Vector2i(1,1),1,12)
	check(not masked.walkable(masked.cell_to_world(Vector2i(1,1))),"forbidden mask denies either half")
	var raw_root: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--aden523-pack="): raw_root = argument.trim_prefix("--aden523-pack=")
	var measured: Dictionary = _real_sources(raw_root) if not raw_root.is_empty() else {}
	print("CURRENT523_ADEN_SOURCE_FIELD_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"real_source_evidence":measured,"own_profile":FIELD.OWN_PROFILE,"native_m_rules_verified":false}))
	quit(0 if failures.is_empty() else 1)

func _real_sources(raw_root: String) -> Dictionary:
	var field = FIELD.new()
	check(field.configure_current523(raw_root,{"aden_inferred_placement_enabled":false}),"historical placement-off raw pack configures: "+field.problem)
	if not field.loaded: return {}
	check(field.registered_source_members().size() == 677 and field.source_chunk_origins().size() == 676,"all676 candidate chunks plus unplaced original retained")
	check(field.unplaced_source_members() == ["Map/Aden/800f7ff3e.s32"],"nine-digit member stays literal and unplaced")
	check(field.source_bounds == Rect2i(32256,31936,2048,2112),"bounds derive from full raw filename union")
	check(field.coordinates.origin == Vector2i(32256,31936) and field.coordinates.basis_x == Vector2(24,-12) and field.coordinates.basis_y == Vector2(24,12) and field.coordinates.translation == Vector2(0,768),"own coordinate transform explicit")
	check(field.has_meta("current523_source_field") and field.data.layout_revision == 5230001 and field.definition.source_map_id == 4 and field.definition.source_sha256 == RAW.INVENTORY_SHA256,"successful own source identity is distinct from legacy grid")
	check(field.data.regions.is_empty() and field.data.npc_spawn.is_empty() and field.data.monster_spawn.is_empty() and field.data.portal.is_empty(),"field never imports legacy geography or spawns")
	check(field.chunk_table.is_empty() and field.nav_cache.is_empty() and field.packs.is_empty(),"no old navigation grids or A3 packs loaded")
	var found_hole: bool = false
	for chunk_y: int in range(field.source_bounds.position.y,field.source_bounds.end.y,64):
		for chunk_x: int in range(field.source_bounds.position.x,field.source_bounds.end.x,64):
			var absolute := Vector2i(chunk_x,chunk_y)
			if field.get("_source_chunks").has(absolute): continue
			check(field.source_cell_info(absolute).status == "unregistered_chunk" and not field.walkable(field.coordinates.to_world(Vector2(absolute))),"missing candidate chunk remains distinct from explicit raw zero")
			found_hole = true
			break
		if found_hole: break
	check(found_hole,"full filename union contains deliberately denied gaps")
	var independent = RAW.new()
	check(independent.load_pack(raw_root),"independent reader configures")
	var consumed: int = 0
	var origins: Dictionary = field.source_chunk_origins()
	for member: String in field.registered_source_members():
		if not origins.has(member): continue
		var origin: Vector2i = origins[member]
		var raw: Dictionary = independent.read_member(member)
		check(not raw.is_empty(),"independent actual raw read: "+member)
		if raw.is_empty(): continue
		for local: Vector2i in [Vector2i.ZERO,Vector2i(31,31),Vector2i(63,63)]:
			var info: Dictionary = field.source_cell_info(origin+local)
			var index: int = local.y*128+local.x*2
			var attributes: PackedByteArray = raw.sections.attributes
			var floor_refs: PackedByteArray = raw.sections.floor
			check(info.member == member and info.raw_pair == [attributes.decode_u16(index*2),attributes.decode_u16((index+1)*2)],"unaltered real attribute pair: "+member+str(local))
			check(info.floor_pair == [floor_refs.decode_u32(index*4),floor_refs.decode_u32((index+1)*4)],"unaltered real floor pair: "+member+str(local))
		consumed += 1
	check(consumed == 676,"all candidate raw chunks consumed")
	check(field.cache_metrics().cached_chunks == 48 and field.cache_metrics().raw_reads == 676,"per-field raw LRU bounded to48 verified reads")
	var source := Vector2i(33412,32768)
	var info: Dictionary = field.source_cell_info(source)
	check(info.raw_pair == [4,4] and info.floor_pair == [300485,300486] and info.walkable,"changed523 town anchor accepted under explicit own rule")
	check(info.source_sha256 == field.source_metadata(info.member).sha256,"endpoint reports digest of actually verified raw member")
	var reads: int = field.cache_metrics().raw_reads
	field.source_cell_info(source)
	check(field.cache_metrics().raw_reads == reads,"cache hit avoids repeated hash and read")
	var zero: Dictionary = field.source_cell_info(Vector2i(32316,33595))
	check(zero.raw_pair == [0,0] and zero.floor_pair == [2031597,2031598] and zero.walkable,"explicit zero mapping uses real source bytes")
	var floor_zero: Dictionary = field.source_cell_info(Vector2i(32568,33024))
	check(floor_zero.floor_pair == [0,22944] and floor_zero.walkable,"raw zero floor preserved without invented tile identity")
	var denied: Vector2 = field.coordinates.to_world(Vector2(32256,33536))
	check(not field.walkable(denied) and field.source_cell_info(Vector2i(32256,33536)).raw_pair == [1,1],"actual unallowed word pair blocks")
	var seam_a: Vector2 = field.coordinates.to_world(Vector2(32319,33595))
	var seam_b: Vector2 = field.coordinates.to_world(Vector2(32320,33595))
	check(field.line_clear(seam_a,seam_b) and field.line_clear(seam_b,seam_a),"actual accepted raw seam traverses both directions")
	check(not field.path(seam_a,denied).size(),"actual blocked endpoint rejects without nearest replacement")
	var corner: Vector2i = Vector2i(32310,33597)-field.coordinates.origin
	check(field.value_at(corner,true) != 0 and field.value_at(corner+Vector2i.ONE,true) != 0 and not field.can_step(corner,3),"actual diagonal refuses denied side halfword")
	for absolute: Vector2i in [Vector2i(32316,33595),Vector2i(32540,33024),Vector2i(32640,32221),Vector2i(32704,33216),Vector2i(32832,32896),Vector2i(32960,32960),Vector2i(33115,33088),Vector2i(33216,33280),Vector2i(33344,33472),Vector2i(33536,32320),Vector2i(33664,32512),Vector2i(33853,32217),Vector2i(33856,33472),Vector2i(33984,33344),Vector2i(34112,33408),Vector2i(34242,33472)]:
		check(field.walkable(field.coordinates.to_world(Vector2(absolute))),"spread raw chunk allowed: "+str(absolute))
	var second = FIELD.new()
	check(second.configure_current523(raw_root,{"spawn_source":[33412,32768]}),"explicit real allowed spawn accepts")
	check(second.cache_metrics().raw_reads == 1 and second.cache_metrics().cached_chunks == 1,"separate field owns independent lazy raw reader/cache")
	check(not second.configure_current523(raw_root,{"spawn_source":[32256,33536]}) and not second.loaded and not second.has_meta("current523_source_field"),"explicit blocked source spawn fails closed without scan")
	var failed = FIELD.new()
	check(failed.configure_current523(raw_root),"read failure probe configures metadata first")
	failed.set("_raw",RejectReadPack.new())
	var failed_info: Dictionary = failed.source_cell_info(source)
	check(failed_info.status == "source_integrity_failure" and not failed_info.walkable,"raw integrity reader rejection denies original cell")
	check(not failed.walkable(failed.coordinates.to_world(Vector2(source))),"failed member never becomes explicit zero terrain")
	check(failed.cache_metrics().raw_reads == 1 and failed.cache_metrics().failed_chunks == 1,"failed chunks are not repeatedly read")
	var evidence: Dictionary = {"candidate_chunks_read":consumed,"registered_members":677,"raw_inventory_sha256":RAW.INVENTORY_SHA256,"source_bounds":[32256,31936,2048,2112],"cache_limit":48,"own_rule":"both exact u16 in [0,4,8,12,32]; both floor refs !=0xffffffff; diagonal both sides allowed","native_m_rules_verified":false}
	field.close()
	check(not field.loaded and field.cache_metrics().cached_chunks == 0 and not field.walkable(seam_a) and not field.has_meta("current523_source_field"),"close drops own raw cache and denies further movement")
	return evidence
