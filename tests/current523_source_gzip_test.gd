extends SceneTree
## Actual optional Land1 gzip/raw parity. No canonical inputs or old packs mutate.
const PACK = preload("res://scripts/maps/current523_source_pack.gd")
const FIELD = preload("res://scripts/maps/current523_source_field.gd")
var checks: int = 0
var failures: Array[String] = []
var actual: Dictionary = {}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func argument(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _initialize() -> void:
	check(FileAccess.COMPRESSION_GZIP == 3,"runtime gzip mode is the tested native gzip codec")
	var invalid := PackedByteArray()
	invalid.resize(18)
	invalid.fill(0)
	check(not PACK._gzip_header_valid(invalid,1),"invalid gzip header rejects before decoder")
	invalid[0]=31;invalid[1]=139;invalid[2]=8;invalid[3]=0;invalid.encode_u32(14,100)
	check(not PACK._gzip_header_valid(invalid,99),"original-size mismatch rejects before decoder")
	check(not PACK._gzip_header_valid(invalid,8*1024*1024+1),"oversized original rejects before decoder")
	invalid[3]=8
	check(not PACK._gzip_header_valid(invalid,100),"optional filename/header flags are outside fixed gzip storage contract")
	check(PACK._storage({"member":"Map/1/../x.s32","bytes":1,"sha256":"0".repeat(64)}).is_empty(),"unsafe original member cannot acquire a gzip storage alias")
	var root: String = argument("--gzip-root=")
	if not root.is_empty(): _actual_land1(root,argument("--gzip-sha="),argument("--raw-root="),argument("--raw-sha="))
	print("CURRENT523_SOURCE_GZIP_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"actual":actual,"native_m_rules_verified":false}))
	quit(0 if failures.is_empty() else 1)

func _actual_land1(gzip_root: String, gzip_sha: String, raw_root: String, raw_sha: String) -> void:
	var compressed = PACK.new()
	var original = PACK.new()
	check(compressed.load_pack(gzip_root,gzip_sha,"1/"),"actual compressed Land1 pack loads: "+compressed.problem)
	check(original.load_pack(raw_root,raw_sha,"1/"),"immutable raw comparison pack loads: "+original.problem)
	if not compressed.loaded or not original.loaded: return
	check(compressed.supported_s32_members() == original.supported_s32_members() and compressed.supported_s32_members().size() == 12,"both representations expose exact same12 original members")
	var raw_field = FIELD.new()
	var gzip_field = FIELD.new()
	check(raw_field.configure_catalog(raw_root,raw_sha,1),"raw field configures")
	check(gzip_field.configure_catalog(gzip_root,gzip_sha,1),"compressed field configures")
	if not raw_field.loaded or not gzip_field.loaded: return
	check(raw_field.definition.source_sha256 == gzip_field.definition.source_sha256 and raw_field.source_bounds == gzip_field.source_bounds,"physical original inventory and declared extent are storage independent")
	var cells: int = 0
	var raw_bytes: int = 0
	var stored_bytes: int = 0
	var origins: Dictionary = gzip_field.source_chunk_origins()
	for member: String in compressed.supported_s32_members():
		var metadata: Dictionary = compressed.source_metadata(member)
		check(metadata.storage_format == "gzip" and metadata.path == "originals/"+member+".gz","compressed source path is canonical: "+member)
		var left: Dictionary = original.read_member(member)
		var right: Dictionary = compressed.read_member(member)
		check(not left.is_empty() and not right.is_empty(),"both original representations verify source SHA: "+member)
		if left.is_empty() or right.is_empty(): continue
		check(left.source_sha256 == right.source_sha256 and left.source_bytes == right.source_bytes,"original source identity stays unchanged: "+member)
		for name: String in PACK.S32_FORMAT.SECTION_NAMES:
			check(left.sections[name] == right.sections[name],"actual raw section bytes match: "+member+" "+name)
		var origin: Vector2i = origins[member]
		for y: int in range(64):
			for x: int in range(64):
				var source: Vector2i = origin+Vector2i(x,y)
				var a: Dictionary = raw_field.source_cell_info(source)
				var b: Dictionary = gzip_field.source_cell_info(source)
				check(a == b,"storage does not change actual raw pairs, hashes, status or own-policy decision: "+member+" "+str(x)+","+str(y))
				cells += 1
		raw_bytes += int(metadata.bytes)
		stored_bytes += int(metadata.stored_bytes)
	actual = {"original_members":12,"all_cells_compared":cells,"raw_bytes":raw_bytes,"gzip_bytes":stored_bytes,
		"raw_manifest_sha256":raw_sha,"gzip_manifest_sha256":gzip_sha,"original_inventory_sha256":raw_field.definition.source_sha256,
		"native_m_rules_verified":false,"render_verified":false}
	check(cells == 49152,"all12 chunks and all49152 original cells preserve field decisions")
	raw_field.close()
	gzip_field.close()
